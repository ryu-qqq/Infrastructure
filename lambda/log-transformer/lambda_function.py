"""
Log Transformer Lambda
CloudWatch Logs → Kinesis Firehose → OpenSearch

이 Lambda는 Firehose에서 호출되어 CloudWatch Logs 데이터를
OpenSearch에 적합한 형식으로 변환합니다.
"""

import base64
import gzip
import json
import logging
import re
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Firehose에서 전달받은 레코드를 변환합니다.

    Firehose → OpenSearch 연동 규칙:
    1. 반환되는 recordId는 입력 recordId와 정확히 일치해야 함
    2. 각 레코드는 단일 JSON 문서여야 함
    3. 여러 로그 이벤트가 있으면 하나로 병합

    Args:
        event: Firehose 이벤트 (records 배열 포함)
        context: Lambda 컨텍스트

    Returns:
        변환된 레코드 배열 (입력과 동일한 recordId 사용)
    """
    output = []

    for record in event.get('records', []):
        try:
            # Base64 디코딩 및 Gzip 압축 해제
            payload = base64.b64decode(record['data'])

            # CloudWatch Logs 데이터는 gzip으로 압축되어 있음
            try:
                decompressed = gzip.decompress(payload)
                log_data = json.loads(decompressed)
            except gzip.BadGzipFile:
                # Gzip이 아닌 경우 직접 파싱
                log_data = json.loads(payload)

            # 변환된 레코드 생성
            transformed_records = transform_log_events(log_data)

            if transformed_records:
                # Firehose → OpenSearch: 하나의 레코드 = 하나의 문서
                # 여러 로그 이벤트가 있으면 첫 번째 이벤트만 사용하고 나머지는 메타데이터로 포함
                if len(transformed_records) == 1:
                    output_doc = transformed_records[0]
                else:
                    # 다중 이벤트: 첫 번째 이벤트를 기본으로, 나머지는 additional_events로
                    first = transformed_records[0]
                    output_doc = first.copy()
                    output_doc['event_count'] = len(transformed_records)
                    # 나머지 이벤트의 메시지만 추출해서 배열로 저장
                    output_doc['additional_messages'] = [
                        r.get('message', '') for r in transformed_records[1:]
                    ]

                output_data = json.dumps(output_doc) + '\n'

                output.append({
                    'recordId': record['recordId'],
                    'result': 'Ok',
                    'data': base64.b64encode(output_data.encode('utf-8')).decode('utf-8')
                })
            else:
                # 변환할 데이터가 없는 경우
                output.append({
                    'recordId': record['recordId'],
                    'result': 'Dropped',
                    'data': record['data']
                })

        except Exception as e:
            logger.error(f"Error processing record: {e}")
            output.append({
                'recordId': record['recordId'],
                'result': 'ProcessingFailed',
                'data': record['data']
            })

    logger.info(f"Processed {len(output)} records")
    return {'records': output}


def transform_log_events(log_data: dict) -> list:
    """
    CloudWatch Logs 데이터를 OpenSearch 문서 형식으로 변환합니다.

    Args:
        log_data: CloudWatch Logs 데이터

    Returns:
        OpenSearch 문서 배열
    """
    transformed = []

    # CloudWatch Logs 메타데이터 추출
    log_group = log_data.get('logGroup', 'unknown')
    log_stream = log_data.get('logStream', 'unknown')
    owner = log_data.get('owner', 'unknown')
    message_type = log_data.get('messageType', 'DATA_MESSAGE')

    # CONTROL_MESSAGE는 건너뛰기
    if message_type == 'CONTROL_MESSAGE':
        return []

    # 로그 그룹에서 서비스 이름 추출
    service_name = extract_service_name(log_group)

    for event in log_data.get('logEvents', []):
        try:
            # 타임스탬프 변환 (밀리초 → ISO 8601)
            timestamp_ms = event.get('timestamp', 0)
            timestamp = datetime.utcfromtimestamp(timestamp_ms / 1000).isoformat() + 'Z'

            # 메시지 파싱 시도
            message = event.get('message', '')
            parsed_message = parse_log_message(message)

            # OpenSearch 문서 생성
            doc = {
                '@timestamp': timestamp,
                'log_group': log_group,
                'log_stream': log_stream,
                'service': service_name,
                'aws_account': owner,
                'message': message,
                'event_id': event.get('id', ''),
            }

            # 파싱된 필드 추가
            if parsed_message:
                doc.update(parsed_message)

            # 로그 레벨 추출
            doc['level'] = extract_log_level(message)

            transformed.append(doc)

        except Exception as e:
            logger.warning(f"Error transforming event: {e}")
            continue

    return transformed


def extract_service_name(log_group: str) -> str:
    """
    로그 그룹 이름에서 서비스 이름을 추출합니다.

    예: /aws/ecs/atlantis/application → atlantis
        /aws/lambda/my-function → my-function
    """
    parts = log_group.strip('/').split('/')

    if len(parts) >= 3:
        # /aws/ecs/service-name/... 또는 /aws/lambda/function-name
        if parts[1] in ['ecs', 'lambda']:
            return parts[2]

    # 기본값: 마지막 부분
    return parts[-1] if parts else 'unknown'


def extract_log_level(message: str) -> str:
    """
    로그 메시지에서 로그 레벨을 추출합니다.
    """
    message_upper = message.upper()

    if 'ERROR' in message_upper or 'FATAL' in message_upper:
        return 'ERROR'
    elif 'WARN' in message_upper:
        return 'WARN'
    elif 'DEBUG' in message_upper:
        return 'DEBUG'
    elif 'TRACE' in message_upper:
        return 'TRACE'
    else:
        return 'INFO'


def parse_log_message(message: str) -> dict:
    """
    로그 메시지를 파싱하여 구조화된 필드를 추출합니다.
    JSON 형식인 경우 파싱을 시도합니다.
    """
    parsed = {}

    # JSON 로그 파싱 시도
    try:
        if message.strip().startswith('{'):
            json_data = json.loads(message)

            # === 기본 필드 ===
            # 로그 레벨 (다양한 키 이름 지원)
            level = json_data.get('level') or json_data.get('log_level') or json_data.get('severity')
            if level:
                parsed['log_level'] = str(level).upper()

            # 로거/코드 위치
            logger_name = json_data.get('logger') or json_data.get('logger_name') or json_data.get('caller')
            if logger_name:
                parsed['logger'] = logger_name

            # 스레드
            thread = json_data.get('thread') or json_data.get('thread_name')
            if thread:
                parsed['thread'] = thread

            # 실제 메시지
            if 'message' in json_data and isinstance(json_data['message'], str):
                parsed['parsed_message'] = json_data['message']
            elif 'msg' in json_data:
                parsed['parsed_message'] = json_data['msg']

            # === 에러 관련 필드 ===
            # 스택 트레이스
            stack_trace = json_data.get('stack_trace') or json_data.get('stacktrace') or json_data.get('exception')
            if stack_trace:
                parsed['stack_trace'] = stack_trace
                # 스택 트레이스에서 Exception 클래스 추출
                exception_class = extract_exception_class(stack_trace)
                if exception_class:
                    parsed['exception_class'] = exception_class

            # 에러 메시지 (message와 별도로 있는 경우)
            error_msg = json_data.get('error_message') or json_data.get('error')
            if error_msg and isinstance(error_msg, str):
                parsed['error_message'] = error_msg

            # === HTTP 관련 필드 ===
            # HTTP 메서드
            http_method = json_data.get('http_method') or json_data.get('method') or json_data.get('httpMethod')
            if http_method:
                parsed['http_method'] = http_method

            # HTTP 경로
            http_path = json_data.get('http_path') or json_data.get('path') or json_data.get('uri') or json_data.get('url')
            if http_path:
                parsed['http_path'] = http_path

            # HTTP 상태 코드
            status_code = json_data.get('status_code') or json_data.get('statusCode') or json_data.get('status') or json_data.get('http_status')
            if status_code:
                parsed['status_code'] = int(status_code) if str(status_code).isdigit() else status_code

            # 응답 시간
            duration = json_data.get('duration') or json_data.get('duration_ms') or json_data.get('response_time') or json_data.get('elapsed')
            if duration:
                parsed['duration_ms'] = duration

            # 클라이언트 IP
            client_ip = json_data.get('client_ip') or json_data.get('clientIp') or json_data.get('remote_addr') or json_data.get('ip')
            if client_ip:
                parsed['client_ip'] = client_ip

            # === 분산 추적 필드 ===
            # Trace ID
            trace_id = json_data.get('trace_id') or json_data.get('traceId') or json_data.get('x-amzn-trace-id')
            if trace_id:
                parsed['trace_id'] = trace_id

            # Span ID
            span_id = json_data.get('span_id') or json_data.get('spanId')
            if span_id:
                parsed['span_id'] = span_id

            # Request ID
            request_id = json_data.get('request_id') or json_data.get('requestId') or json_data.get('correlationId')
            if request_id:
                parsed['request_id'] = request_id

            # === 비즈니스 컨텍스트 ===
            # 사용자 ID
            user_id = json_data.get('user_id') or json_data.get('userId')
            if user_id:
                parsed['user_id'] = user_id

            # 액션/작업
            action = json_data.get('action') or json_data.get('operation')
            if action:
                parsed['action'] = action

            # 서비스명 (로그 자체에 있는 경우)
            app_name = json_data.get('APP_NAME') or json_data.get('application') or json_data.get('service')
            if app_name:
                parsed['app_name'] = app_name

            # 환경
            env = json_data.get('APP_ENV') or json_data.get('environment') or json_data.get('env')
            if env:
                parsed['environment'] = env

    except json.JSONDecodeError:
        pass

    return parsed


def extract_exception_class(stack_trace: str) -> str:
    """
    스택 트레이스에서 Exception 클래스명을 추출합니다.

    예: "java.lang.NullPointerException: message" → "NullPointerException"
        "s.a.a.s.s.m.KmsAccessDeniedException: User..." → "KmsAccessDeniedException"
    """
    if not stack_trace:
        return None

    # 패턴 1: 전체 클래스명 (java.lang.NullPointerException)
    # 패턴 2: 축약된 클래스명 (s.a.a.s.KmsAccessDeniedException)
    patterns = [
        r'([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*Exception)',
        r'([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*Error)',
        r'([A-Z][a-zA-Z0-9]*Exception)',
        r'([A-Z][a-zA-Z0-9]*Error)',
    ]

    for pattern in patterns:
        match = re.search(pattern, stack_trace)
        if match:
            full_class = match.group(1)
            # 마지막 클래스명만 추출 (예: java.lang.NullPointerException → NullPointerException)
            return full_class.split('.')[-1]

    return None
