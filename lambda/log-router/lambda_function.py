"""
Log Router Lambda
CloudWatch Logs → Kinesis Data Streams → OpenSearch (Bulk API)

이 Lambda는 Kinesis Data Streams에서 CloudWatch Logs 데이터를 받아서
OpenSearch Bulk API로 개별 문서를 직접 전송합니다.
"""

import base64
import gzip
import json
import logging
import os
import re
from datetime import datetime
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 환경 변수
OPENSEARCH_ENDPOINT = os.environ.get('OPENSEARCH_ENDPOINT', '')
OPENSEARCH_REGION = os.environ.get('AWS_REGION', 'ap-northeast-2')
INDEX_PREFIX = os.environ.get('INDEX_PREFIX', 'logs')


def handler(event, context):
    """
    Kinesis Data Streams에서 레코드를 받아서 OpenSearch로 전송합니다.

    Args:
        event: Kinesis 이벤트 (Records 배열 포함)
        context: Lambda 컨텍스트

    Returns:
        처리 결과 요약
    """
    documents = []
    failed_records = []

    for record in event.get('Records', []):
        try:
            # Kinesis 데이터 디코딩
            kinesis_data = record['kinesis']['data']
            payload = base64.b64decode(kinesis_data)

            # CloudWatch Logs 데이터는 gzip으로 압축되어 있음
            try:
                decompressed = gzip.decompress(payload)
                log_data = json.loads(decompressed)
            except gzip.BadGzipFile:
                log_data = json.loads(payload)

            # CONTROL_MESSAGE 건너뛰기
            if log_data.get('messageType') == 'CONTROL_MESSAGE':
                continue

            # 서비스명 및 인덱스 결정
            log_group = log_data.get('logGroup', 'unknown')
            service_name = extract_service_name(log_group)
            index_date = datetime.utcnow().strftime('%Y-%m-%d')
            index_name = f"{INDEX_PREFIX}-{service_name}-{index_date}"

            # 각 로그 이벤트를 개별 문서로 변환
            for log_event in log_data.get('logEvents', []):
                doc = transform_log_event(log_event, log_data)
                documents.append({
                    'index': index_name,
                    'document': doc
                })

        except Exception as e:
            logger.error(f"Error processing record: {e}")
            failed_records.append({
                'recordId': record.get('eventID', 'unknown'),
                'error': str(e)
            })

    # OpenSearch Bulk API로 전송
    if documents:
        success_count, error_count = bulk_index_to_opensearch(documents)
        logger.info(f"Indexed {success_count} documents, {error_count} errors")
    else:
        success_count, error_count = 0, 0

    result = {
        'processedRecords': len(event.get('Records', [])),
        'documentsIndexed': success_count,
        'documentErrors': error_count,
        'failedRecords': len(failed_records)
    }

    logger.info(f"Processing complete: {result}")
    return result


def transform_log_event(log_event: dict, log_data: dict) -> dict:
    """
    개별 로그 이벤트를 OpenSearch 문서 형식으로 변환합니다.

    Args:
        log_event: CloudWatch 로그 이벤트
        log_data: CloudWatch Logs 메타데이터

    Returns:
        OpenSearch 문서
    """
    # 타임스탬프 변환 (밀리초 → ISO 8601)
    timestamp_ms = log_event.get('timestamp', 0)
    timestamp = datetime.utcfromtimestamp(timestamp_ms / 1000).isoformat() + 'Z'

    # 메시지 파싱 시도
    message = log_event.get('message', '')
    parsed_fields = parse_log_message(message)

    # 기본 문서 구조
    doc = {
        '@timestamp': timestamp,
        'log_group': log_data.get('logGroup', 'unknown'),
        'log_stream': log_data.get('logStream', 'unknown'),
        'service': extract_service_name(log_data.get('logGroup', '')),
        'aws_account': log_data.get('owner', 'unknown'),
        'raw_message': message,  # 원본 메시지는 raw_message로 저장
        'event_id': log_event.get('id', ''),
        'level': extract_log_level(message),
    }

    # 파싱된 필드 추가
    if parsed_fields:
        doc.update(parsed_fields)

    return doc


def extract_service_name(log_group: str) -> str:
    """
    로그 그룹 이름에서 서비스 이름을 추출합니다.

    예: /aws/ecs/atlantis-prod/application → atlantis
        /aws/ecs/gateway-prod/application → gateway
        /aws/lambda/my-function → my-function
        /aws/ecs/crawlinghub-web-api-prod/application → crawlinghub
    """
    parts = log_group.strip('/').split('/')

    if len(parts) >= 3:
        # /aws/ecs/service-name/... 또는 /aws/lambda/function-name
        if parts[1] in ['ecs', 'lambda']:
            service_part = parts[2]
            # 서비스명에서 환경 접미사 제거 (예: atlantis-prod → atlantis)
            service_name = re.sub(r'-(prod|staging|dev).*$', '', service_part)
            # 복합 서비스명 처리 (예: crawlinghub-web-api → crawlinghub)
            if '-' in service_name:
                service_name = service_name.split('-')[0]
            return service_name

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
    로그 메시지를 파싱하여 모든 JSON 필드를 최상위로 평탄화합니다.
    JSON 형식인 경우 전체 필드를 추출하고, 추가 정규화를 수행합니다.
    """
    parsed = {}

    # JSON 로그 파싱 시도
    try:
        if message.strip().startswith('{'):
            json_data = json.loads(message)

            # === 모든 JSON 필드를 최상위로 평탄화 ===
            parsed = flatten_json(json_data)

            # === 필드 정규화 (일관된 필드명으로 변환) ===
            # 로그 레벨 정규화
            level = parsed.get('level') or parsed.get('log_level') or parsed.get('severity')
            if level:
                parsed['log_level'] = str(level).upper()

            # 로거 정규화
            logger_name = parsed.get('logger') or parsed.get('logger_name') or parsed.get('caller')
            if logger_name:
                parsed['logger'] = logger_name

            # 스레드 정규화
            thread = parsed.get('thread') or parsed.get('thread_name')
            if thread:
                parsed['thread'] = thread

            # 메시지 정규화 (원본 JSON의 message 필드)
            if 'message' in parsed and isinstance(parsed['message'], str):
                parsed['parsed_message'] = parsed['message']
                del parsed['message']  # raw_message에 원본이 있으므로 중복 제거
            elif 'msg' in parsed:
                parsed['parsed_message'] = parsed['msg']

            # 스택 트레이스 정규화
            stack_trace = parsed.get('stack_trace') or parsed.get('stacktrace') or parsed.get('exception')
            if stack_trace:
                parsed['stack_trace'] = stack_trace
                exception_class = extract_exception_class(str(stack_trace))
                if exception_class:
                    parsed['exception_class'] = exception_class

            # HTTP 관련 필드 정규화
            http_method = parsed.get('http_method') or parsed.get('method') or parsed.get('httpMethod')
            if http_method:
                parsed['http_method'] = http_method

            http_path = parsed.get('http_path') or parsed.get('path') or parsed.get('uri') or parsed.get('url')
            if http_path:
                parsed['http_path'] = http_path

            status_code = parsed.get('status_code') or parsed.get('statusCode') or parsed.get('status') or parsed.get('http_status')
            if status_code:
                parsed['status_code'] = int(status_code) if str(status_code).isdigit() else status_code

            duration = parsed.get('duration') or parsed.get('duration_ms') or parsed.get('response_time') or parsed.get('elapsed')
            if duration:
                parsed['duration_ms'] = duration

            client_ip = parsed.get('client_ip') or parsed.get('clientIp') or parsed.get('remote_addr') or parsed.get('ip')
            if client_ip:
                parsed['client_ip'] = client_ip

            # 분산 추적 필드 정규화
            trace_id = parsed.get('trace_id') or parsed.get('traceId') or parsed.get('x-amzn-trace-id')
            if trace_id:
                parsed['trace_id'] = trace_id

            span_id = parsed.get('span_id') or parsed.get('spanId')
            if span_id:
                parsed['span_id'] = span_id

            request_id = parsed.get('request_id') or parsed.get('requestId') or parsed.get('correlationId')
            if request_id:
                parsed['request_id'] = request_id

            # 비즈니스 컨텍스트 정규화
            user_id = parsed.get('user_id') or parsed.get('userId')
            if user_id:
                parsed['user_id'] = user_id

            action = parsed.get('action') or parsed.get('operation')
            if action:
                parsed['action'] = action

            app_name = parsed.get('APP_NAME') or parsed.get('application') or parsed.get('service') or parsed.get('SERVICE_NAME')
            if app_name:
                parsed['app_name'] = app_name

            env = parsed.get('APP_ENV') or parsed.get('environment') or parsed.get('env') or parsed.get('ENVIRONMENT')
            if env:
                parsed['environment'] = env

    except json.JSONDecodeError:
        pass

    return parsed


def flatten_json(obj: dict, parent_key: str = '', separator: str = '_') -> dict:
    """
    중첩된 JSON 객체를 평탄화합니다.

    Args:
        obj: 평탄화할 JSON 객체
        parent_key: 부모 키 (재귀 호출용)
        separator: 키 구분자

    Returns:
        평탄화된 딕셔너리

    예시:
        {'a': {'b': 1, 'c': 2}} → {'a_b': 1, 'a_c': 2}
        {'items': [1, 2, 3]} → {'items': [1, 2, 3]}  # 배열은 그대로 유지
    """
    items = {}

    for key, value in obj.items():
        new_key = f"{parent_key}{separator}{key}" if parent_key else key

        if isinstance(value, dict):
            # 중첩된 객체는 재귀적으로 평탄화
            items.update(flatten_json(value, new_key, separator))
        elif isinstance(value, list):
            # 리스트는 그대로 유지 (OpenSearch에서 배열 지원)
            items[new_key] = value
        else:
            # 기본 값은 그대로 저장
            items[new_key] = value

    return items


def extract_exception_class(stack_trace: str) -> str:
    """
    스택 트레이스에서 Exception 클래스명을 추출합니다.
    """
    if not stack_trace:
        return None

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
            return full_class.split('.')[-1]

    return None


def bulk_index_to_opensearch(documents: list) -> tuple:
    """
    OpenSearch Bulk API로 문서를 전송합니다.

    Args:
        documents: [{'index': 'index-name', 'document': {...}}, ...]

    Returns:
        (success_count, error_count)
    """
    if not documents or not OPENSEARCH_ENDPOINT:
        logger.warning("No documents to index or OPENSEARCH_ENDPOINT not set")
        return 0, 0

    # Bulk API 형식으로 변환
    # 각 문서는 action + document 두 줄로 구성
    bulk_body_lines = []
    for doc_item in documents:
        index_name = doc_item['index']
        document = doc_item['document']

        # Action line
        action = {"index": {"_index": index_name}}
        bulk_body_lines.append(json.dumps(action))
        # Document line
        bulk_body_lines.append(json.dumps(document))

    # NDJSON 형식 (각 줄 끝에 newline, 마지막에도 newline)
    bulk_body = '\n'.join(bulk_body_lines) + '\n'

    # OpenSearch Bulk API 호출
    url = f"https://{OPENSEARCH_ENDPOINT}/_bulk"
    headers = {
        'Content-Type': 'application/x-ndjson'
    }

    try:
        # AWS SigV4 서명이 필요한 경우 boto3 사용
        # 여기서는 VPC 내부 또는 IAM 없이 접근 가능한 경우를 가정
        # 실제 환경에서는 requests-aws4auth 또는 boto3 사용 권장
        from botocore.auth import SigV4Auth
        from botocore.awsrequest import AWSRequest
        import botocore.session

        session = botocore.session.get_session()
        credentials = session.get_credentials()

        request = AWSRequest(method='POST', url=url, data=bulk_body, headers=headers)
        SigV4Auth(credentials, 'es', OPENSEARCH_REGION).add_auth(request)

        req = Request(url, data=bulk_body.encode('utf-8'), headers=dict(request.headers), method='POST')
        response = urlopen(req, timeout=30)
        response_body = json.loads(response.read().decode('utf-8'))

        # 결과 분석
        success_count = 0
        error_count = 0

        if response_body.get('errors', False):
            for item in response_body.get('items', []):
                index_result = item.get('index', {})
                if index_result.get('status', 0) >= 400:
                    error_count += 1
                    logger.error(f"Index error: {index_result}")
                else:
                    success_count += 1
        else:
            success_count = len(documents)

        return success_count, error_count

    except (HTTPError, URLError) as e:
        logger.error(f"OpenSearch bulk request failed: {e}")
        return 0, len(documents)
    except Exception as e:
        logger.error(f"Unexpected error during bulk indexing: {e}")
        return 0, len(documents)
