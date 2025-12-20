"""
Alert Enrichment Lambda Function

Receives alerts from SNS (Grafana/CloudWatch), enriches them with context information,
and sends formatted messages to Slack.

Context sources:
- CloudWatch Logs: Recent error logs
- AMP (Prometheus): Error rate by route, error codes
- ECS: Recent deployment info
- X-Ray: Trace samples
- DynamoDB: Runbook URLs
"""

import json
import os
import logging
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone
from typing import Any

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL', '')
AMP_ENDPOINT = os.environ.get('AMP_ENDPOINT', '')
AWS_REGION = os.environ.get('AWS_REGION', 'ap-northeast-2')
RUNBOOK_TABLE_NAME = os.environ.get('RUNBOOK_TABLE_NAME', 'connectly-alert-runbooks')
GRAFANA_URL = os.environ.get('GRAFANA_URL', '')
CLOUDWATCH_BASE_URL = os.environ.get('CLOUDWATCH_BASE_URL', '')

# Service to ECS cluster mapping
SERVICE_CLUSTER_MAP = {
    'gateway': 'gateway-cluster-prod',
    'authhub': 'authhub-cluster-prod',
    'commerce': 'setof-commerce-cluster-prod',
    'setof-commerce': 'setof-commerce-cluster-prod',
    'crawlinghub': 'crawlinghub-cluster-prod',
    'fileflow': 'fileflow-cluster-prod',
    'atlantis': 'atlantis-prod',
    'n8n': 'n8n-prod',
}

# Service to log group mapping (actual CloudWatch Log Groups)
SERVICE_LOG_GROUP_MAP = {
    # Gateway
    'gateway': '/aws/ecs/gateway-prod/application',

    # AuthHub
    'authhub': '/aws/ecs/authhub-web-api-prod/application',

    # Commerce (Setof)
    'commerce': '/aws/ecs/setof-commerce-web-api-prod/application',
    'setof-commerce': '/aws/ecs/setof-commerce-web-api-prod/application',

    # CrawlingHub (multiple components)
    'crawlinghub': '/aws/ecs/crawlinghub-web-api-prod/application',
    'crawlinghub-worker': '/aws/ecs/crawlinghub-crawl-worker-prod/application',
    'crawlinghub-scheduler': '/aws/ecs/crawlinghub-scheduler-prod/application',

    # FileFlow (multiple components)
    'fileflow': '/aws/ecs/fileflow-web-api-prod/application',
    'fileflow-worker': '/aws/ecs/fileflow-download-worker/prod',
    'fileflow-scheduler': '/aws/ecs/fileflow-scheduler/prod',

    # Atlantis
    'atlantis': '/aws/ecs/atlantis-prod/application',

    # N8N
    'n8n': '/aws/ecs/n8n-prod',
}

# AWS clients (initialized lazily)
_logs_client = None
_ecs_client = None
_xray_client = None
_dynamodb_client = None
_amp_client = None


def get_logs_client():
    global _logs_client
    if _logs_client is None:
        _logs_client = boto3.client('logs', region_name=AWS_REGION)
    return _logs_client


def get_ecs_client():
    global _ecs_client
    if _ecs_client is None:
        _ecs_client = boto3.client('ecs', region_name=AWS_REGION)
    return _ecs_client


def get_xray_client():
    global _xray_client
    if _xray_client is None:
        _xray_client = boto3.client('xray', region_name=AWS_REGION)
    return _xray_client


def get_dynamodb_client():
    global _dynamodb_client
    if _dynamodb_client is None:
        _dynamodb_client = boto3.client('dynamodb', region_name=AWS_REGION)
    return _dynamodb_client


def get_amp_client():
    global _amp_client
    if _amp_client is None:
        _amp_client = boto3.client('amp', region_name=AWS_REGION)
    return _amp_client


def lambda_handler(event: dict, context: Any) -> dict:
    """Main Lambda handler."""
    logger.info(f"Received event: {json.dumps(event)}")

    try:
        # Parse SNS message
        alert_data = parse_sns_event(event)
        if not alert_data:
            logger.warning("No valid alert data found in event")
            return {'statusCode': 200, 'body': 'No alert data'}

        # Extract alert metadata (now pre-parsed by parse_sns_event)
        alert_name = alert_data.get('alertname', 'Unknown Alert')
        severity = alert_data.get('severity', 'warning').lower()
        status = alert_data.get('status', 'firing')

        # Get service from parsed data or try extraction
        service = alert_data.get('service', '')
        if not service:
            service = extract_service_from_alert(alert_data)

        alert_count = alert_data.get('alert_count', 1)
        logger.info(f"Processing alert: {alert_name}, service: {service}, severity: {severity}, count: {alert_count}")

        # Collect enrichment context
        context_data = collect_context(alert_data, service)

        # Build and send Slack message
        slack_message = build_slack_message(alert_data, context_data, severity, status)
        send_to_slack(slack_message)

        # Store alert history (optional)
        store_alert_history(alert_data, context_data)

        return {'statusCode': 200, 'body': 'Alert processed successfully'}

    except Exception as e:
        logger.error(f"Error processing alert: {str(e)}", exc_info=True)
        # Still try to send a basic alert to Slack
        try:
            send_basic_error_notification(event, str(e))
        except Exception:
            pass
        return {'statusCode': 500, 'body': f'Error: {str(e)}'}


def parse_sns_event(event: dict) -> dict | None:
    """Parse SNS event to extract alert data.

    Handles multiple alert formats:
    1. Grafana Alerting
    2. CloudWatch Alarms
    3. OpenSearch Alerting (new)

    Grafana format:
    {
        "receiver": "sns-warning",
        "status": "firing",
        "alerts": [
            {
                "status": "firing",
                "labels": {"alertname": "...", "service": "...", "severity": "..."},
                "annotations": {"summary": "...", "description": "..."},
                "startsAt": "...",
                "endsAt": "..."
            }
        ],
        "groupLabels": {...},
        "commonLabels": {...},
        "commonAnnotations": {...},
        "externalURL": "..."
    }

    OpenSearch Alerting format (plain text or JSON):
    Subject: "Alerting-Notification Action"
    Message: "Monitor: <name>\nTrigger: <trigger>\nSeverity: <severity>..."
    or JSON: {"monitor_name": "...", "trigger_name": "...", "severity": "...", ...}
    """
    try:
        raw_data = None
        sns_subject = None
        raw_message = None

        # Handle SNS message
        if 'Records' in event:
            for record in event['Records']:
                if record.get('EventSource') == 'aws:sns':
                    raw_message = record['Sns']['Message']
                    sns_subject = record['Sns'].get('Subject', '')
                    # Try to parse as JSON
                    try:
                        raw_data = json.loads(raw_message)
                    except json.JSONDecodeError:
                        raw_data = None  # Will handle as plain text
                    break

        # Handle direct invocation (for testing)
        if raw_data is None and raw_message is None:
            raw_data = event

        # Check for OpenSearch Alerting format
        # OpenSearch sends Subject: "Alerting-Notification Action" or similar
        if sns_subject and 'Alerting' in sns_subject:
            return parse_opensearch_alert(raw_message, raw_data, sns_subject)

        # If we got raw_message but no raw_data, it's plain text - check if OpenSearch
        if raw_message and raw_data is None:
            # Check if message looks like OpenSearch format
            if 'Monitor:' in raw_message or 'monitor_name' in raw_message.lower():
                return parse_opensearch_alert(raw_message, None, sns_subject or '')
            # Return as simple message
            return {'message': raw_message, 'alertname': 'Unknown Alert', 'severity': 'warning'}

        # Check if this is Grafana alert format (has 'alerts' array)
        if raw_data and 'alerts' in raw_data and isinstance(raw_data['alerts'], list) and len(raw_data['alerts']) > 0:
            # Extract first alert and merge with top-level data
            first_alert = raw_data['alerts'][0]
            labels = first_alert.get('labels', {})
            annotations = first_alert.get('annotations', {})

            return {
                # Top-level Grafana fields
                'receiver': raw_data.get('receiver', ''),
                'status': first_alert.get('status', raw_data.get('status', 'firing')),
                'externalURL': raw_data.get('externalURL', ''),
                'groupLabels': raw_data.get('groupLabels', {}),
                'commonLabels': raw_data.get('commonLabels', {}),
                'commonAnnotations': raw_data.get('commonAnnotations', {}),

                # Extracted from first alert's labels
                'alertname': labels.get('alertname', 'Unknown Alert'),
                'severity': labels.get('severity', 'warning'),
                'service': labels.get('service', labels.get('job', labels.get('app', ''))),
                'instance': labels.get('instance', ''),

                # All labels and annotations for reference
                'labels': labels,
                'annotations': annotations,

                # Timing
                'startsAt': first_alert.get('startsAt', ''),
                'endsAt': first_alert.get('endsAt', ''),

                # All alerts for multi-alert handling
                'all_alerts': raw_data['alerts'],
                'alert_count': len(raw_data['alerts']),
            }

        # Handle CloudWatch Alarm format or simple format
        if raw_data and ('alertname' in raw_data or 'AlarmName' in raw_data):
            return {
                'alertname': raw_data.get('alertname', raw_data.get('AlarmName', 'Unknown Alert')),
                'severity': raw_data.get('severity', raw_data.get('NewStateValue', 'warning')).lower(),
                'status': 'firing' if raw_data.get('NewStateValue') == 'ALARM' else raw_data.get('status', 'firing'),
                'labels': raw_data.get('labels', {}),
                'annotations': raw_data.get('annotations', {'description': raw_data.get('NewStateReason', '')}),
                'service': raw_data.get('service', ''),
            }

        # Check if raw_data is OpenSearch JSON format
        if raw_data and ('monitor_name' in raw_data or 'monitor' in raw_data):
            return parse_opensearch_alert(None, raw_data, sns_subject or '')

        return None
    except Exception as e:
        logger.error(f"Error parsing SNS event: {str(e)}")
        return None


def parse_opensearch_alert(message: str | None, json_data: dict | None, subject: str) -> dict:
    """Parse OpenSearch Alerting format.

    OpenSearch Alerting can send either:
    1. Plain text format:
       Monitor: Error Log Alert
       Trigger: Error threshold exceeded
       Severity: critical
       Period start: 2025-12-20T11:00:00Z
       Period end: 2025-12-20T11:05:00Z
       Results:
       - Total: 15 errors

    2. JSON format (if configured in message template):
       {
           "monitor_name": "Error Log Alert",
           "trigger_name": "Error threshold exceeded",
           "severity": "critical",
           "service": "atlantis",
           ...
       }
    """
    import re

    result = {
        'alertname': 'OpenSearch Alert',
        'severity': 'warning',
        'status': 'firing',
        'service': '',
        'labels': {},
        'annotations': {},
        'source': 'opensearch',
    }

    # Try JSON format first
    if json_data:
        result['alertname'] = json_data.get('monitor_name', json_data.get('monitor', json_data.get('alertname', 'OpenSearch Alert')))
        result['severity'] = json_data.get('severity', json_data.get('trigger_severity', 'warning')).lower()
        result['service'] = json_data.get('service', json_data.get('log_group', ''))
        result['annotations']['description'] = json_data.get('trigger_name', json_data.get('description', ''))
        result['annotations']['summary'] = json_data.get('summary', json_data.get('message', ''))

        # Extract additional fields
        if 'results' in json_data:
            result['annotations']['results'] = json_data['results']
        if 'period_start' in json_data:
            result['startsAt'] = json_data['period_start']
        if 'period_end' in json_data:
            result['endsAt'] = json_data['period_end']

        # Try to extract service from log_group if not directly provided
        if not result['service'] and 'log_group' in json_data:
            result['service'] = extract_service_from_log_group(json_data['log_group'])

        return result

    # Parse plain text format
    if message:
        # === Korean message patterns (수동 생성 Monitor) ===
        # Pattern: "🔥 Exception 발생 알림" or "🚨 에러 로그 발생" etc.
        korean_patterns = {
            'Exception 발생': ('Exception Alert', 'critical'),
            'Exception이 발생': ('Exception Alert', 'critical'),
            'Error Log Alert': ('Error Log Alert', 'warning'),
            '에러 로그 발생': ('Error Log Alert', 'warning'),
            '에러 로그 알림': ('Error Log Alert', 'warning'),
            'Service Error Rate': ('Service Error Rate Alert', 'warning'),
            '서비스 에러율': ('Service Error Rate Alert', 'warning'),
            '에러율 높음': ('Service Error Rate Alert', 'warning'),
            'Error threshold': ('Error Log Alert', 'warning'),
            'Exception detected': ('Exception Alert', 'critical'),
        }

        for pattern, (alert_name, severity) in korean_patterns.items():
            if pattern in message:
                result['alertname'] = alert_name
                result['severity'] = severity
                break

        # Extract count from Korean message (e.g., "최근 5분간 15건의 Exception")
        count_match = re.search(r'(\d+)\s*건', message)
        if count_match:
            result['annotations']['count'] = count_match.group(1)

        # Determine severity from emoji
        if '🔥' in message or '🚨' in message:
            result['severity'] = 'critical'
        elif '⚠️' in message:
            result['severity'] = 'warning'
        elif 'ℹ️' in message:
            result['severity'] = 'info'

        # === English message patterns ===
        # Extract Monitor name
        monitor_match = re.search(r'Monitor:\s*(.+?)(?:\n|$)', message)
        if monitor_match:
            result['alertname'] = monitor_match.group(1).strip()

        # Extract Trigger name
        trigger_match = re.search(r'Trigger:\s*(.+?)(?:\n|$)', message)
        if trigger_match:
            result['annotations']['description'] = trigger_match.group(1).strip()

        # Extract Severity (English)
        severity_match = re.search(r'Severity:\s*(\w+)', message, re.IGNORECASE)
        if severity_match:
            result['severity'] = severity_match.group(1).lower()

        # Extract period
        period_start_match = re.search(r'Period start:\s*(.+?)(?:\n|$)', message)
        if period_start_match:
            result['startsAt'] = period_start_match.group(1).strip()

        period_end_match = re.search(r'Period end:\s*(.+?)(?:\n|$)', message)
        if period_end_match:
            result['endsAt'] = period_end_match.group(1).strip()

        # Try to extract service from message
        # Look for patterns like "service: xxx" or "log_group: /aws/ecs/xxx-prod/..."
        service_match = re.search(r'[Ss]ervice[:\s]+(\S+)', message)
        if service_match:
            result['service'] = service_match.group(1).strip()
        else:
            log_group_match = re.search(r'log_group["\s:]+([^\s"]+)', message)
            if log_group_match:
                result['service'] = extract_service_from_log_group(log_group_match.group(1))

        # Extract results section
        results_match = re.search(r'Results?:\s*\n?([\s\S]+?)(?:\n\n|$)', message)
        if results_match:
            result['annotations']['results'] = results_match.group(1).strip()

        # Store full message for reference
        result['annotations']['raw_message'] = message[:1000]
        result['annotations']['description'] = message[:200]

        # Try to extract service from alert name if still not found
        if not result['service']:
            result['service'] = extract_service_from_alertname(result['alertname'])

        # For OpenSearch log alerts, default service to 'ecs-logs' if still unknown
        if not result['service'] and ('Exception' in message or 'Error' in message or 'error' in message):
            result['service'] = 'ecs-logs'

    return result


def extract_service_from_log_group(log_group: str) -> str:
    """Extract service name from CloudWatch log group path.

    Examples:
    /aws/ecs/atlantis-prod/application → atlantis
    /aws/ecs/gateway-prod/application → gateway
    /aws/ecs/crawlinghub-web-api-prod/application → crawlinghub
    """
    if not log_group:
        return ''

    parts = log_group.strip('/').split('/')
    if len(parts) >= 3 and parts[0] == 'aws' and parts[1] == 'ecs':
        service_part = parts[2]
        # Remove common suffixes
        for suffix in ['-prod', '-staging', '-dev', '-web-api', '-worker', '-scheduler', '-application']:
            service_part = service_part.replace(suffix, '')
        # Map to known services
        for known_service in SERVICE_CLUSTER_MAP.keys():
            if known_service in service_part.lower():
                return known_service
        return service_part

    return ''


def extract_service_from_alertname(alert_name: str) -> str:
    """Extract service name from alert name if possible.

    Examples:
    Gateway Error Rate Alert → gateway
    Atlantis Exception Alert → atlantis
    CrawlingHub Service Error → crawlinghub
    """
    if not alert_name:
        return ''

    alert_lower = alert_name.lower()
    for known_service in SERVICE_CLUSTER_MAP.keys():
        if known_service in alert_lower:
            return known_service

    return ''


def extract_service_from_alert(alert_data: dict) -> str:
    """Extract service name from alert data."""
    # Try various fields that might contain service info
    labels = alert_data.get('labels', {})
    annotations = alert_data.get('annotations', {})

    # Check common label fields
    for field in ['service', 'job', 'app', 'application']:
        if field in labels:
            service = labels[field]
            # Clean up service name
            for known_service in SERVICE_CLUSTER_MAP.keys():
                if known_service in service.lower():
                    return known_service
            return service

    # Try to extract from alert name
    alert_name = alert_data.get('alertname', '')
    for known_service in SERVICE_CLUSTER_MAP.keys():
        if known_service in alert_name.lower():
            return known_service

    return 'unknown'


def collect_context(alert_data: dict, service: str) -> dict:
    """Collect enrichment context from various sources."""
    context = {
        'error_logs': [],
        'error_routes': [],
        'error_codes': {},
        'recent_deployments': [],
        'trace_samples': [],
        'runbook_url': None,
        'related_alarms': [],
    }

    # Get alert name for runbook lookup
    alert_name = alert_data.get('alertname', alert_data.get('ruleName', ''))

    # Collect from each source (with error handling)
    try:
        context['error_logs'] = get_recent_error_logs(service)
    except Exception as e:
        logger.warning(f"Failed to get error logs: {str(e)}")

    try:
        context['error_routes'] = get_error_routes_from_amp(service)
    except Exception as e:
        logger.warning(f"Failed to get error routes from AMP: {str(e)}")

    try:
        context['error_codes'] = get_error_codes_from_amp(service)
    except Exception as e:
        logger.warning(f"Failed to get error codes from AMP: {str(e)}")

    try:
        context['recent_deployments'] = get_recent_deployments(service)
    except Exception as e:
        logger.warning(f"Failed to get recent deployments: {str(e)}")

    try:
        context['trace_samples'] = get_trace_samples(service)
    except Exception as e:
        logger.warning(f"Failed to get trace samples: {str(e)}")

    try:
        context['runbook_url'] = get_runbook_url(alert_name, service)
    except Exception as e:
        logger.warning(f"Failed to get runbook URL: {str(e)}")

    return context


def get_recent_error_logs(service: str, limit: int = 5) -> list[dict]:
    """Get recent error logs from CloudWatch Logs."""
    log_group = SERVICE_LOG_GROUP_MAP.get(service)
    if not log_group:
        return []

    client = get_logs_client()
    end_time = int(datetime.now(timezone.utc).timestamp() * 1000)
    start_time = end_time - (5 * 60 * 1000)  # Last 5 minutes

    try:
        response = client.filter_log_events(
            logGroupName=log_group,
            startTime=start_time,
            endTime=end_time,
            filterPattern='?ERROR ?Exception ?error ?exception',
            limit=limit
        )

        logs = []
        for event in response.get('events', []):
            message = event.get('message', '')
            # Truncate long messages
            if len(message) > 200:
                message = message[:197] + '...'
            logs.append({
                'timestamp': event.get('timestamp'),
                'message': message
            })
        return logs
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            logger.info(f"Log group {log_group} not found")
            return []
        raise


def get_error_routes_from_amp(service: str) -> list[dict]:
    """Get error-concentrated routes from AMP (Prometheus)."""
    if not AMP_ENDPOINT:
        return []

    # This is a simplified example - actual implementation would use
    # the AMP Query API with PromQL
    # Query: topk(3, sum by (routeId) (rate(http_server_requests_seconds_count{status=~"5.."}[5m])))

    # For now, return placeholder
    # TODO: Implement actual AMP query using requests library with SigV4 signing
    return []


def get_error_codes_from_amp(service: str) -> dict:
    """Get error code distribution from AMP."""
    if not AMP_ENDPOINT:
        return {}

    # Query: sum by (status) (rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
    # TODO: Implement actual AMP query
    return {}


def get_recent_deployments(service: str, hours: int = 24) -> list[dict]:
    """Get recent ECS deployments."""
    cluster = SERVICE_CLUSTER_MAP.get(service)
    if not cluster:
        return []

    client = get_ecs_client()
    deployments = []

    try:
        # List services in cluster
        services_response = client.list_services(
            cluster=cluster,
            maxResults=10
        )

        for service_arn in services_response.get('serviceArns', []):
            # Describe service to get deployment info
            desc_response = client.describe_services(
                cluster=cluster,
                services=[service_arn]
            )

            for svc in desc_response.get('services', []):
                for deployment in svc.get('deployments', []):
                    created_at = deployment.get('createdAt')
                    if created_at:
                        # Check if deployment is within the time window
                        if isinstance(created_at, datetime):
                            deployment_time = created_at
                        else:
                            deployment_time = datetime.fromisoformat(str(created_at).replace('Z', '+00:00'))

                        cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
                        if deployment_time > cutoff:
                            deployments.append({
                                'service': svc.get('serviceName'),
                                'status': deployment.get('status'),
                                'running_count': deployment.get('runningCount'),
                                'desired_count': deployment.get('desiredCount'),
                                'created_at': deployment_time.isoformat(),
                                'task_definition': deployment.get('taskDefinition', '').split('/')[-1]
                            })

        return deployments[:5]  # Return max 5 deployments
    except ClientError as e:
        logger.warning(f"Failed to get ECS deployments: {str(e)}")
        return []


def get_trace_samples(service: str, limit: int = 3) -> list[dict]:
    """Get sample traces from X-Ray for failed requests."""
    client = get_xray_client()
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(minutes=15)

    try:
        # Get trace summaries for error traces
        response = client.get_trace_summaries(
            StartTime=start_time,
            EndTime=end_time,
            FilterExpression=f'service(id(name: "{service}")) AND fault = true',
            Sampling=True
        )

        traces = []
        for summary in response.get('TraceSummaries', [])[:limit]:
            traces.append({
                'trace_id': summary.get('Id'),
                'duration': summary.get('Duration'),
                'response_time': summary.get('ResponseTime'),
                'has_fault': summary.get('HasFault'),
                'has_error': summary.get('HasError'),
            })

        return traces
    except ClientError as e:
        logger.warning(f"Failed to get X-Ray traces: {str(e)}")
        return []


def get_runbook_url(alert_name: str, service: str) -> str | None:
    """Get runbook URL from DynamoDB."""
    client = get_dynamodb_client()

    try:
        response = client.get_item(
            TableName=RUNBOOK_TABLE_NAME,
            Key={
                'alert_name': {'S': alert_name},
                'service': {'S': service}
            }
        )

        item = response.get('Item')
        if item and 'runbook_url' in item:
            return item['runbook_url']['S']

        # Try with 'default' service if specific service not found
        response = client.get_item(
            TableName=RUNBOOK_TABLE_NAME,
            Key={
                'alert_name': {'S': alert_name},
                'service': {'S': 'default'}
            }
        )

        item = response.get('Item')
        if item and 'runbook_url' in item:
            return item['runbook_url']['S']

        return None
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            logger.info(f"Runbook table {RUNBOOK_TABLE_NAME} not found")
            return None
        raise


def store_alert_history(alert_data: dict, context_data: dict) -> None:
    """Store alert in history table for analysis."""
    # Optional: implement if needed
    pass


def build_slack_message(alert_data: dict, context: dict, severity: str, status: str) -> dict:
    """Build Slack Block Kit message."""
    alert_name = alert_data.get('alertname', alert_data.get('ruleName', 'Unknown Alert'))
    service = extract_service_from_alert(alert_data)
    labels = alert_data.get('labels', {})
    annotations = alert_data.get('annotations', {})

    # Determine emoji and color based on severity
    severity_config = {
        'critical': {'emoji': '🚨', 'color': '#dc3545'},
        'warning': {'emoji': '⚠️', 'color': '#ffc107'},
        'info': {'emoji': 'ℹ️', 'color': '#17a2b8'},
    }
    config = severity_config.get(severity, severity_config['warning'])

    # Status indicator
    status_text = 'FIRING' if status == 'firing' else 'RESOLVED'
    status_emoji = '🔥' if status == 'firing' else '✅'

    blocks = [
        # Header
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"{config['emoji']} [{severity.upper()}] {alert_name}",
                "emoji": True
            }
        },
        # Status and Service
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*상태:*\n{status_emoji} {status_text}"},
                {"type": "mrkdwn", "text": f"*서비스:*\n{service}"},
                {"type": "mrkdwn", "text": f"*심각도:*\n{severity.upper()}"},
                {"type": "mrkdwn", "text": f"*발생 시간:*\n{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')} UTC"}
            ]
        },
        {"type": "divider"}
    ]

    # Alert description if available
    description = annotations.get('description', annotations.get('summary', ''))
    if description:
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*📋 설명*\n{description[:500]}"}
        })

    # Error logs section
    if context.get('error_logs'):
        log_text = "*🔍 최근 에러 로그*\n"
        for log in context['error_logs'][:3]:
            log_text += f"```{log['message']}```\n"
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": log_text[:2000]}
        })

    # Recent deployments section
    if context.get('recent_deployments'):
        deploy_text = "*📦 최근 배포*\n"
        for deploy in context['recent_deployments'][:3]:
            deploy_text += f"• `{deploy['task_definition']}` - {deploy['status']} ({deploy['created_at'][:16]})\n"
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": deploy_text}
        })

    # Trace samples section
    if context.get('trace_samples'):
        trace_text = "*🔗 실패 트레이스 샘플*\n"
        for trace in context['trace_samples'][:3]:
            trace_text += f"• `{trace['trace_id']}` - {trace.get('duration', 'N/A')}s\n"
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": trace_text}
        })

    blocks.append({"type": "divider"})

    # Action buttons
    buttons = []

    if GRAFANA_URL:
        buttons.append({
            "type": "button",
            "text": {"type": "plain_text", "text": "📊 대시보드", "emoji": True},
            "url": f"{GRAFANA_URL}/d/{service}-overview",
            "action_id": "dashboard"
        })

    if CLOUDWATCH_BASE_URL:
        log_group = SERVICE_LOG_GROUP_MAP.get(service, '')
        buttons.append({
            "type": "button",
            "text": {"type": "plain_text", "text": "📋 로그", "emoji": True},
            "url": f"{CLOUDWATCH_BASE_URL}/cloudwatch/home?region={AWS_REGION}#logsV2:log-groups/log-group/{log_group.replace('/', '$252F')}",
            "action_id": "logs"
        })

    if context.get('runbook_url'):
        buttons.append({
            "type": "button",
            "text": {"type": "plain_text", "text": "📖 Runbook", "emoji": True},
            "url": context['runbook_url'],
            "style": "primary",
            "action_id": "runbook"
        })

    if buttons:
        blocks.append({
            "type": "actions",
            "elements": buttons
        })

    return {
        "attachments": [
            {
                "color": config['color'],
                "blocks": blocks
            }
        ]
    }


def send_to_slack(message: dict) -> None:
    """Send message to Slack webhook."""
    if not SLACK_WEBHOOK_URL:
        logger.warning("SLACK_WEBHOOK_URL not configured, skipping Slack notification")
        return

    data = json.dumps(message).encode('utf-8')
    req = urllib.request.Request(
        SLACK_WEBHOOK_URL,
        data=data,
        headers={'Content-Type': 'application/json'}
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            logger.info(f"Slack notification sent successfully: {response.status}")
    except urllib.error.HTTPError as e:
        logger.error(f"Failed to send Slack notification: {e.code} - {e.read().decode()}")
        raise
    except urllib.error.URLError as e:
        logger.error(f"Failed to connect to Slack: {str(e)}")
        raise


def send_basic_error_notification(event: dict, error: str) -> None:
    """Send a basic error notification when enrichment fails."""
    if not SLACK_WEBHOOK_URL:
        return

    message = {
        "text": f"⚠️ Alert Enrichment Error\n\nFailed to process alert:\n```{error}```\n\nOriginal event:\n```{json.dumps(event)[:500]}```"
    }
    send_to_slack(message)
