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
        'message': message,
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
    로그 메시지를 파싱하여 구조화된 필드를 추출합니다.
    JSON 형식인 경우 파싱을 시도합니다.
    """
    parsed = {}

    # JSON 로그 파싱 시도
    try:
        if message.strip().startswith('{'):
            json_data = json.loads(message)

            # === 기본 필드 ===
            level = json_data.get('level') or json_data.get('log_level') or json_data.get('severity')
            if level:
                parsed['log_level'] = str(level).upper()

            logger_name = json_data.get('logger') or json_data.get('logger_name') or json_data.get('caller')
            if logger_name:
                parsed['logger'] = logger_name

            thread = json_data.get('thread') or json_data.get('thread_name')
            if thread:
                parsed['thread'] = thread

            if 'message' in json_data and isinstance(json_data['message'], str):
                parsed['parsed_message'] = json_data['message']
            elif 'msg' in json_data:
                parsed['parsed_message'] = json_data['msg']

            # === 에러 관련 필드 ===
            stack_trace = json_data.get('stack_trace') or json_data.get('stacktrace') or json_data.get('exception')
            if stack_trace:
                parsed['stack_trace'] = stack_trace
                exception_class = extract_exception_class(stack_trace)
                if exception_class:
                    parsed['exception_class'] = exception_class

            error_msg = json_data.get('error_message') or json_data.get('error')
            if error_msg and isinstance(error_msg, str):
                parsed['error_message'] = error_msg

            # === HTTP 관련 필드 ===
            http_method = json_data.get('http_method') or json_data.get('method') or json_data.get('httpMethod')
            if http_method:
                parsed['http_method'] = http_method

            http_path = json_data.get('http_path') or json_data.get('path') or json_data.get('uri') or json_data.get('url')
            if http_path:
                parsed['http_path'] = http_path

            status_code = json_data.get('status_code') or json_data.get('statusCode') or json_data.get('status') or json_data.get('http_status')
            if status_code:
                parsed['status_code'] = int(status_code) if str(status_code).isdigit() else status_code

            duration = json_data.get('duration') or json_data.get('duration_ms') or json_data.get('response_time') or json_data.get('elapsed')
            if duration:
                parsed['duration_ms'] = duration

            client_ip = json_data.get('client_ip') or json_data.get('clientIp') or json_data.get('remote_addr') or json_data.get('ip')
            if client_ip:
                parsed['client_ip'] = client_ip

            # === 분산 추적 필드 ===
            trace_id = json_data.get('trace_id') or json_data.get('traceId') or json_data.get('x-amzn-trace-id')
            if trace_id:
                parsed['trace_id'] = trace_id

            span_id = json_data.get('span_id') or json_data.get('spanId')
            if span_id:
                parsed['span_id'] = span_id

            request_id = json_data.get('request_id') or json_data.get('requestId') or json_data.get('correlationId')
            if request_id:
                parsed['request_id'] = request_id

            # === 비즈니스 컨텍스트 ===
            user_id = json_data.get('user_id') or json_data.get('userId')
            if user_id:
                parsed['user_id'] = user_id

            action = json_data.get('action') or json_data.get('operation')
            if action:
                parsed['action'] = action

            app_name = json_data.get('APP_NAME') or json_data.get('application') or json_data.get('service')
            if app_name:
                parsed['app_name'] = app_name

            env = json_data.get('APP_ENV') or json_data.get('environment') or json_data.get('env')
            if env:
                parsed['environment'] = env

    except json.JSONDecodeError:
        pass

    return parsed


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
