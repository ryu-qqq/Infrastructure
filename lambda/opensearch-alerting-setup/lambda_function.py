"""
OpenSearch Alerting Setup Lambda
Creates notification channels and monitors for log-based alerting.
Uses AWS Sigv4 authentication for secure OpenSearch access.
"""

import json
import os
import logging
from typing import Any
from datetime import datetime
import hashlib
import hmac
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
import ssl

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
OPENSEARCH_ENDPOINT = os.environ.get('OPENSEARCH_ENDPOINT', '')
SNS_TOPIC_CRITICAL = os.environ.get('SNS_TOPIC_CRITICAL', '')
SNS_TOPIC_WARNING = os.environ.get('SNS_TOPIC_WARNING', '')
SNS_TOPIC_INFO = os.environ.get('SNS_TOPIC_INFO', '')
SNS_ROLE_ARN = os.environ.get('SNS_ROLE_ARN', '')
AWS_REGION_NAME = os.environ.get('AWS_REGION_NAME', 'ap-northeast-2')

# Index pattern for ECS logs (actual index is logs-YYYY-MM-DD)
LOG_INDEX_PATTERN = "logs-*"


def sign(key: bytes, msg: str) -> bytes:
    """Create HMAC-SHA256 signature."""
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()


def get_signature_key(key: str, date_stamp: str, region: str, service: str) -> bytes:
    """Derive signing key for AWS Sigv4."""
    k_date = sign(('AWS4' + key).encode('utf-8'), date_stamp)
    k_region = sign(k_date, region)
    k_service = sign(k_region, service)
    k_signing = sign(k_service, 'aws4_request')
    return k_signing


def create_sigv4_headers(method: str, url: str, body: str | None, region: str) -> dict:
    """Create AWS Sigv4 signed headers for OpenSearch request."""
    # Get credentials from Lambda environment
    access_key = os.environ.get('AWS_ACCESS_KEY_ID', '')
    secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY', '')
    session_token = os.environ.get('AWS_SESSION_TOKEN', '')

    service = 'es'
    parsed_url = urlparse(url)
    host = parsed_url.netloc
    canonical_uri = parsed_url.path or '/'
    canonical_querystring = parsed_url.query or ''

    t = datetime.utcnow()
    amz_date = t.strftime('%Y%m%dT%H%M%SZ')
    date_stamp = t.strftime('%Y%m%d')

    # Create payload hash
    payload = body if body else ''
    payload_hash = hashlib.sha256(payload.encode('utf-8')).hexdigest()

    # Create canonical headers
    canonical_headers = f'host:{host}\nx-amz-date:{amz_date}\n'
    signed_headers = 'host;x-amz-date'

    if session_token:
        canonical_headers = f'host:{host}\nx-amz-date:{amz_date}\nx-amz-security-token:{session_token}\n'
        signed_headers = 'host;x-amz-date;x-amz-security-token'

    # Create canonical request
    canonical_request = '\n'.join([
        method,
        canonical_uri,
        canonical_querystring,
        canonical_headers,
        signed_headers,
        payload_hash
    ])

    # Create string to sign
    algorithm = 'AWS4-HMAC-SHA256'
    credential_scope = f'{date_stamp}/{region}/{service}/aws4_request'
    string_to_sign = '\n'.join([
        algorithm,
        amz_date,
        credential_scope,
        hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()
    ])

    # Create signature
    signing_key = get_signature_key(secret_key, date_stamp, region, service)
    signature = hmac.new(signing_key, string_to_sign.encode('utf-8'), hashlib.sha256).hexdigest()

    # Create authorization header
    authorization_header = (
        f'{algorithm} Credential={access_key}/{credential_scope}, '
        f'SignedHeaders={signed_headers}, Signature={signature}'
    )

    headers = {
        'Content-Type': 'application/json',
        'X-Amz-Date': amz_date,
        'Authorization': authorization_header,
    }

    if session_token:
        headers['X-Amz-Security-Token'] = session_token

    return headers


def make_opensearch_request(method: str, path: str, body: dict | None = None) -> dict:
    """Make AWS Sigv4 authenticated request to OpenSearch."""
    url = f"{OPENSEARCH_ENDPOINT}{path}"

    body_str = json.dumps(body) if body else None

    headers = create_sigv4_headers(method, url, body_str, AWS_REGION_NAME)

    data = body_str.encode('utf-8') if body_str else None

    # Create SSL context
    ctx = ssl.create_default_context()

    request = Request(url, data=data, headers=headers, method=method)

    try:
        with urlopen(request, context=ctx, timeout=30) as response:
            return json.loads(response.read().decode('utf-8'))
    except HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        logger.error(f"HTTP Error {e.code}: {error_body}")
        raise
    except URLError as e:
        logger.error(f"URL Error: {e.reason}")
        raise


def create_sns_channel(name: str, topic_arn: str, role_arn: str) -> str:
    """Create SNS notification channel in OpenSearch using Notifications plugin (2.x)."""
    # OpenSearch 2.x uses Notifications plugin with different API
    channel_body = {
        "config_id": name.lower().replace(" ", "-").replace("(", "").replace(")", ""),
        "config": {
            "name": name,
            "description": f"SNS notification channel for {name}",
            "config_type": "sns",
            "is_enabled": True,
            "sns": {
                "topic_arn": topic_arn,
                "role_arn": role_arn
            }
        }
    }

    try:
        # Check if channel already exists
        try:
            existing = make_opensearch_request('GET', '/_plugins/_notifications/configs')
            for config in existing.get('config_list', []):
                if config.get('config', {}).get('name') == name:
                    config_id = config.get('config_id', '')
                    logger.info(f"Channel '{name}' already exists with ID: {config_id}")
                    return config_id
        except HTTPError as e:
            if e.code != 404:
                raise
            logger.info("No existing channels found, will create new one")

        # Create new channel
        result = make_opensearch_request('POST', '/_plugins/_notifications/configs', channel_body)
        config_id = result.get('config_id', '')
        logger.info(f"Created channel '{name}' with ID: {config_id}")
        return config_id
    except Exception as e:
        logger.error(f"Failed to create channel '{name}': {e}")
        raise


def create_sns_destination(name: str, topic_arn: str, role_arn: str) -> str:
    """Create SNS notification destination - wrapper for compatibility."""
    return create_sns_channel(name, topic_arn, role_arn)


def initialize_alerting_indices() -> bool:
    """Initialize alerting indices by accessing the alerting API."""
    try:
        # Try to access monitors endpoint - this will initialize indices
        make_opensearch_request('GET', '/_plugins/_alerting/monitors/_search', {
            "size": 0,
            "query": {"match_all": {}}
        })
        logger.info("Alerting indices already initialized")
        return True
    except HTTPError as e:
        if e.code == 404:
            # Try to create a dummy search to initialize
            try:
                # Create the index manually
                make_opensearch_request('PUT', '/.opendistro-alerting-config', {
                    "settings": {
                        "index": {
                            "number_of_shards": 1,
                            "number_of_replicas": 1,
                            "hidden": True
                        }
                    }
                })
                logger.info("Created alerting config index")
                return True
            except HTTPError as create_err:
                if create_err.code == 400:
                    # Index might already exist
                    return True
                logger.error(f"Failed to create alerting index: {create_err}")
                return False
        else:
            logger.error(f"Failed to initialize alerting indices: {e}")
            return False
    except Exception as e:
        logger.error(f"Error initializing alerting indices: {e}")
        return False


def create_error_log_monitor(destination_id: str, severity: str = 'warning') -> str:
    """Create monitor for ERROR level logs."""
    monitor_name = f"ECS Error Log Monitor ({severity})"

    # JSON message template for better parsing by alert-enrichment Lambda
    message_template = json.dumps({
        "monitor_name": "{{ctx.monitor.name}}",
        "trigger_name": "{{ctx.trigger.name}}",
        "severity": severity,
        "status": "firing",
        "service": "ecs-logs",
        "period_start": "{{ctx.periodStart}}",
        "period_end": "{{ctx.periodEnd}}",
        "error_count": "{{ctx.results.0.hits.total.value}}",
        "index": LOG_INDEX_PATTERN,
        "query": "level:ERROR OR message:ERROR",
        "description": f"Error Log Monitor: {{{{ctx.results.0.hits.total.value}}}} errors in last 5 minutes",
        "dashboard_url": f"{OPENSEARCH_ENDPOINT}/_dashboards"
    }, indent=2)

    monitor_body = {
        "name": monitor_name,
        "type": "monitor",
        "monitor_type": "query_level_monitor",
        "enabled": True,
        "schedule": {
            "period": {
                "interval": 5,
                "unit": "MINUTES"
            }
        },
        "inputs": [{
            "search": {
                "indices": [LOG_INDEX_PATTERN],
                "query": {
                    "size": 0,
                    "query": {
                        "bool": {
                            "must": [
                                {
                                    "bool": {
                                        "should": [
                                            {"match": {"level": "ERROR"}},
                                            {"match": {"level": "error"}},
                                            {"match": {"log_level": "ERROR"}},
                                            {"match_phrase": {"message": "ERROR"}}
                                        ],
                                        "minimum_should_match": 1
                                    }
                                }
                            ],
                            "filter": [
                                {
                                    "range": {
                                        "@timestamp": {
                                            "gte": "now-5m",
                                            "lte": "now"
                                        }
                                    }
                                }
                            ]
                        }
                    },
                    "aggs": {
                        "error_count": {
                            "value_count": {
                                "field": "_id"
                            }
                        }
                    }
                }
            }
        }],
        "triggers": [{
            "name": "Error threshold exceeded",
            "severity": "2" if severity == 'warning' else "1",
            "condition": {
                "script": {
                    "source": "ctx.results[0].hits.total.value > 10",
                    "lang": "painless"
                }
            },
            "actions": [{
                "name": f"Send to SNS ({severity})",
                "destination_id": destination_id,
                "message_template": {
                    "source": message_template
                },
                "throttle_enabled": True,
                "throttle": {
                    "value": 10,
                    "unit": "MINUTES"
                }
            }]
        }]
    }

    try:
        # Check if monitor already exists (use match_phrase for exact matching)
        search_result = make_opensearch_request('GET', '/_plugins/_alerting/monitors/_search', {
            "query": {
                "match_phrase": {
                    "name": monitor_name
                }
            }
        })

        hits = search_result.get('hits', {}).get('hits', [])
        # Verify exact name match
        existing_id = None
        for hit in hits:
            if hit.get('_source', {}).get('name') == monitor_name:
                existing_id = hit['_id']
                break

        if existing_id:
            logger.info(f"Monitor '{monitor_name}' already exists with ID: {existing_id}")
            # Update existing monitor
            make_opensearch_request('PUT', f'/_plugins/_alerting/monitors/{existing_id}', monitor_body)
            logger.info(f"Updated monitor '{monitor_name}'")
            return existing_id

        # Create new monitor
        result = make_opensearch_request('POST', '/_plugins/_alerting/monitors', monitor_body)
        monitor_id = result.get('_id', '')
        logger.info(f"Created monitor '{monitor_name}' with ID: {monitor_id}")
        return monitor_id
    except Exception as e:
        logger.error(f"Failed to create monitor '{monitor_name}': {e}")
        raise


def create_exception_monitor(destination_id: str) -> str:
    """Create monitor for Exception patterns in logs."""
    monitor_name = "ECS Exception Pattern Monitor"

    # JSON message template for better parsing by alert-enrichment Lambda
    message_template = json.dumps({
        "monitor_name": "{{ctx.monitor.name}}",
        "trigger_name": "{{ctx.trigger.name}}",
        "severity": "critical",
        "status": "firing",
        "service": "ecs-logs",
        "period_start": "{{ctx.periodStart}}",
        "period_end": "{{ctx.periodEnd}}",
        "exception_count": "{{ctx.results.0.hits.total.value}}",
        "index": LOG_INDEX_PATTERN,
        "query": "Exception, Traceback, Fatal, OutOfMemoryError, StackOverflowError",
        "description": "Critical Exception detected: {{ctx.results.0.hits.total.value}} exceptions in last 1 minute",
        "dashboard_url": f"{OPENSEARCH_ENDPOINT}/_dashboards"
    }, indent=2)

    monitor_body = {
        "name": monitor_name,
        "type": "monitor",
        "monitor_type": "query_level_monitor",
        "enabled": True,
        "schedule": {
            "period": {
                "interval": 1,
                "unit": "MINUTES"
            }
        },
        "inputs": [{
            "search": {
                "indices": [LOG_INDEX_PATTERN],
                "query": {
                    "size": 5,
                    "query": {
                        "bool": {
                            "must": [
                                {
                                    "bool": {
                                        "should": [
                                            {"match_phrase": {"message": "Exception"}},
                                            {"match_phrase": {"message": "Traceback"}},
                                            {"match_phrase": {"message": "Fatal"}},
                                            {"match_phrase": {"message": "FATAL"}},
                                            {"match_phrase": {"message": "OutOfMemoryError"}},
                                            {"match_phrase": {"message": "StackOverflowError"}}
                                        ],
                                        "minimum_should_match": 1
                                    }
                                }
                            ],
                            "filter": [
                                {
                                    "range": {
                                        "@timestamp": {
                                            "gte": "now-1m",
                                            "lte": "now"
                                        }
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        }],
        "triggers": [{
            "name": "Critical exception detected",
            "severity": "1",
            "condition": {
                "script": {
                    "source": "ctx.results[0].hits.total.value > 0",
                    "lang": "painless"
                }
            },
            "actions": [{
                "name": "Send to SNS (critical)",
                "destination_id": destination_id,
                "message_template": {
                    "source": message_template
                },
                "throttle_enabled": True,
                "throttle": {
                    "value": 5,
                    "unit": "MINUTES"
                }
            }]
        }]
    }

    try:
        # Check if monitor already exists (use match_phrase for exact matching)
        search_result = make_opensearch_request('GET', '/_plugins/_alerting/monitors/_search', {
            "query": {
                "match_phrase": {
                    "name": monitor_name
                }
            }
        })

        hits = search_result.get('hits', {}).get('hits', [])
        # Verify exact name match
        existing_id = None
        for hit in hits:
            if hit.get('_source', {}).get('name') == monitor_name:
                existing_id = hit['_id']
                break

        if existing_id:
            logger.info(f"Monitor '{monitor_name}' already exists with ID: {existing_id}")
            make_opensearch_request('PUT', f'/_plugins/_alerting/monitors/{existing_id}', monitor_body)
            logger.info(f"Updated monitor '{monitor_name}'")
            return existing_id

        result = make_opensearch_request('POST', '/_plugins/_alerting/monitors', monitor_body)
        monitor_id = result.get('_id', '')
        logger.info(f"Created monitor '{monitor_name}' with ID: {monitor_id}")
        return monitor_id
    except Exception as e:
        logger.error(f"Failed to create monitor '{monitor_name}': {e}")
        raise


def create_service_error_rate_monitor(destination_id: str, service_name: str) -> str:
    """Create monitor for high error rate per service."""
    monitor_name = f"Service Error Rate Monitor - {service_name}"

    # JSON message template for better parsing by alert-enrichment Lambda
    message_template = json.dumps({
        "monitor_name": "{{ctx.monitor.name}}",
        "trigger_name": "{{ctx.trigger.name}}",
        "severity": "warning",
        "status": "firing",
        "service": service_name,
        "period_start": "{{ctx.periodStart}}",
        "period_end": "{{ctx.periodEnd}}",
        "error_count": "{{ctx.results.0.hits.total.value}}",
        "index": LOG_INDEX_PATTERN,
        "description": f"High error rate in {service_name}: {{{{ctx.results.0.hits.total.value}}}} errors in last 5 minutes",
        "dashboard_url": f"{OPENSEARCH_ENDPOINT}/_dashboards"
    }, indent=2)

    monitor_body = {
        "name": monitor_name,
        "type": "monitor",
        "monitor_type": "query_level_monitor",
        "enabled": True,
        "schedule": {
            "period": {
                "interval": 5,
                "unit": "MINUTES"
            }
        },
        "inputs": [{
            "search": {
                "indices": [LOG_INDEX_PATTERN],
                "query": {
                    "size": 0,
                    "query": {
                        "bool": {
                            "must": [
                                {"match": {"service": service_name}},
                                {
                                    "bool": {
                                        "should": [
                                            {"match": {"level": "ERROR"}},
                                            {"match": {"level": "error"}}
                                        ],
                                        "minimum_should_match": 1
                                    }
                                }
                            ],
                            "filter": [
                                {
                                    "range": {
                                        "@timestamp": {
                                            "gte": "now-5m",
                                            "lte": "now"
                                        }
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        }],
        "triggers": [{
            "name": f"{service_name} error rate high",
            "severity": "2",
            "condition": {
                "script": {
                    "source": "ctx.results[0].hits.total.value > 5",
                    "lang": "painless"
                }
            },
            "actions": [{
                "name": "Send to SNS (warning)",
                "destination_id": destination_id,
                "message_template": {
                    "source": message_template
                },
                "throttle_enabled": True,
                "throttle": {
                    "value": 15,
                    "unit": "MINUTES"
                }
            }]
        }]
    }

    try:
        # Check if monitor already exists (use match_phrase for exact matching)
        search_result = make_opensearch_request('GET', '/_plugins/_alerting/monitors/_search', {
            "query": {
                "match_phrase": {
                    "name": monitor_name
                }
            }
        })

        hits = search_result.get('hits', {}).get('hits', [])
        # Verify exact name match
        existing_id = None
        for hit in hits:
            if hit.get('_source', {}).get('name') == monitor_name:
                existing_id = hit['_id']
                break

        if existing_id:
            make_opensearch_request('PUT', f'/_plugins/_alerting/monitors/{existing_id}', monitor_body)
            logger.info(f"Updated monitor '{monitor_name}'")
            return existing_id

        result = make_opensearch_request('POST', '/_plugins/_alerting/monitors', monitor_body)
        monitor_id = result.get('_id', '')
        logger.info(f"Created monitor '{monitor_name}' with ID: {monitor_id}")
        return monitor_id
    except Exception as e:
        logger.error(f"Failed to create monitor '{monitor_name}': {e}")
        raise


def setup_all_alerting() -> dict:
    """Set up all notification channels and monitors."""
    results = {
        'destinations': {},
        'monitors': {},
        'errors': [],
        'initialized': False
    }

    # Initialize alerting indices first
    try:
        results['initialized'] = initialize_alerting_indices()
    except Exception as e:
        results['errors'].append(f"Failed to initialize alerting indices: {e}")

    # Create SNS destinations
    try:
        critical_dest = create_sns_destination('SNS-Critical', SNS_TOPIC_CRITICAL, SNS_ROLE_ARN)
        results['destinations']['critical'] = critical_dest
    except Exception as e:
        results['errors'].append(f"Failed to create critical destination: {e}")
        critical_dest = None

    try:
        warning_dest = create_sns_destination('SNS-Warning', SNS_TOPIC_WARNING, SNS_ROLE_ARN)
        results['destinations']['warning'] = warning_dest
    except Exception as e:
        results['errors'].append(f"Failed to create warning destination: {e}")
        warning_dest = None

    try:
        info_dest = create_sns_destination('SNS-Info', SNS_TOPIC_INFO, SNS_ROLE_ARN)
        results['destinations']['info'] = info_dest
    except Exception as e:
        results['errors'].append(f"Failed to create info destination: {e}")
        info_dest = None

    # Create monitors
    if warning_dest:
        try:
            results['monitors']['error_log'] = create_error_log_monitor(warning_dest, 'warning')
        except Exception as e:
            results['errors'].append(f"Failed to create error log monitor: {e}")

    if critical_dest:
        try:
            results['monitors']['exception'] = create_exception_monitor(critical_dest)
        except Exception as e:
            results['errors'].append(f"Failed to create exception monitor: {e}")

    # Create per-service monitors for key services
    services = ['gateway', 'authhub', 'commerce', 'crawlinghub', 'fileflow']
    if warning_dest:
        for service in services:
            try:
                results['monitors'][f'service_{service}'] = create_service_error_rate_monitor(warning_dest, service)
            except Exception as e:
                results['errors'].append(f"Failed to create monitor for {service}: {e}")

    return results


def list_monitors() -> dict:
    """List all existing monitors."""
    try:
        result = make_opensearch_request('GET', '/_plugins/_alerting/monitors/_search', {
            "size": 100,
            "query": {"match_all": {}}
        })
        monitors = []
        for hit in result.get('hits', {}).get('hits', []):
            # Handle both possible structures:
            # 1. _source.monitor.name (wrapped)
            # 2. _source.name (direct)
            source = hit.get('_source', {})
            monitor_data = source.get('monitor', source)  # Use monitor if exists, otherwise use source directly
            monitors.append({
                'id': hit.get('_id'),
                'name': monitor_data.get('name'),
                'enabled': monitor_data.get('enabled'),
                'type': monitor_data.get('monitor_type') or monitor_data.get('type'),
                'schedule': monitor_data.get('schedule')
            })
        return {'monitors': monitors, 'total': result.get('hits', {}).get('total', {}).get('value', 0)}
    except Exception as e:
        logger.error(f"Failed to list monitors: {e}")
        return {'error': str(e)}


def list_destinations() -> dict:
    """List all existing destinations (legacy alerting API)."""
    try:
        result = make_opensearch_request('GET', '/_plugins/_alerting/destinations')
        return {'destinations': result.get('destinations', [])}
    except Exception as e:
        return {'error': str(e)}


def list_notification_channels() -> dict:
    """List all notification channels (OpenSearch 2.x Notifications plugin)."""
    try:
        result = make_opensearch_request('GET', '/_plugins/_notifications/configs')
        channels = []
        for config in result.get('config_list', []):
            channels.append({
                'config_id': config.get('config_id'),
                'name': config.get('config', {}).get('name'),
                'type': config.get('config', {}).get('config_type'),
                'is_enabled': config.get('config', {}).get('is_enabled'),
                'sns_topic': config.get('config', {}).get('sns', {}).get('topic_arn', '')
            })
        return {'channels': channels, 'total': len(channels)}
    except Exception as e:
        logger.error(f"Failed to list notification channels: {e}")
        return {'error': str(e)}


def delete_monitor(monitor_id: str) -> dict:
    """Delete a specific monitor by ID."""
    try:
        result = make_opensearch_request('DELETE', f'/_plugins/_alerting/monitors/{monitor_id}')
        logger.info(f"Deleted monitor {monitor_id}")
        return {'deleted': monitor_id, 'result': result}
    except Exception as e:
        logger.error(f"Failed to delete monitor {monitor_id}: {e}")
        return {'error': str(e), 'monitor_id': monitor_id}


def delete_all_monitors() -> dict:
    """Delete all existing monitors."""
    results = {
        'deleted': [],
        'errors': []
    }

    try:
        # First, list all monitors
        monitors = list_monitors()
        if 'error' in monitors:
            return monitors

        for monitor in monitors.get('monitors', []):
            monitor_id = monitor.get('id')
            monitor_name = monitor.get('name', 'Unknown')
            if monitor_id:
                try:
                    make_opensearch_request('DELETE', f'/_plugins/_alerting/monitors/{monitor_id}')
                    results['deleted'].append({'id': monitor_id, 'name': monitor_name})
                    logger.info(f"Deleted monitor: {monitor_name} ({monitor_id})")
                except Exception as e:
                    results['errors'].append({'id': monitor_id, 'name': monitor_name, 'error': str(e)})
                    logger.error(f"Failed to delete monitor {monitor_name}: {e}")

        return results
    except Exception as e:
        return {'error': str(e)}


def clean_and_setup() -> dict:
    """Delete all existing monitors and create fresh ones with JSON templates."""
    results = {
        'cleanup': {},
        'setup': {},
        'errors': []
    }

    # Step 1: Delete all existing monitors
    logger.info("Step 1: Deleting all existing monitors...")
    cleanup_result = delete_all_monitors()
    results['cleanup'] = cleanup_result

    if 'error' in cleanup_result:
        results['errors'].append(f"Cleanup failed: {cleanup_result['error']}")
        return results

    logger.info(f"Deleted {len(cleanup_result.get('deleted', []))} monitors")

    # Step 2: Create fresh monitors with JSON templates
    logger.info("Step 2: Creating fresh monitors with JSON templates...")
    setup_result = setup_all_alerting()
    results['setup'] = setup_result

    if setup_result.get('errors'):
        results['errors'].extend(setup_result['errors'])

    return results


def debug_list_monitors() -> dict:
    """Debug function to return raw monitor search response."""
    try:
        result = make_opensearch_request('GET', '/_plugins/_alerting/monitors/_search', {
            "size": 100,
            "query": {"match_all": {}}
        })
        return {'raw_response': result}
    except Exception as e:
        logger.error(f"Failed to debug list monitors: {e}")
        return {'error': str(e)}


def check_alerts_history() -> dict:
    """Check recent alerts history."""
    try:
        result = make_opensearch_request('GET', '/.opendistro-alerting-alerts/_search', {
            "size": 20,
            "sort": [{"start_time": {"order": "desc"}}],
            "query": {"match_all": {}}
        })
        alerts = []
        for hit in result.get('hits', {}).get('hits', []):
            source = hit.get('_source', {})
            alerts.append({
                'id': hit.get('_id'),
                'monitor_name': source.get('monitor_name'),
                'trigger_name': source.get('trigger_name'),
                'state': source.get('state'),
                'start_time': source.get('start_time'),
                'last_notification_time': source.get('last_notification_time'),
                'error_message': source.get('error_message')
            })
        return {'alerts': alerts, 'total': result.get('hits', {}).get('total', {}).get('value', 0)}
    except HTTPError as e:
        if e.code == 404:
            return {'alerts': [], 'message': 'No alerts index yet - no alerts have been triggered'}
        return {'error': str(e)}
    except Exception as e:
        return {'error': str(e)}


def test_error_query() -> dict:
    """Test the error log query to see if there are matching logs."""
    try:
        result = make_opensearch_request('GET', f'/{LOG_INDEX_PATTERN}/_search', {
            "size": 0,
            "query": {
                "bool": {
                    "must": [
                        {
                            "bool": {
                                "should": [
                                    {"match": {"level": "ERROR"}},
                                    {"match": {"level": "error"}},
                                    {"match": {"log_level": "ERROR"}},
                                    {"match_phrase": {"message": "ERROR"}}
                                ],
                                "minimum_should_match": 1
                            }
                        }
                    ],
                    "filter": [
                        {
                            "range": {
                                "@timestamp": {
                                    "gte": "now-1h",
                                    "lte": "now"
                                }
                            }
                        }
                    ]
                }
            }
        })
        return {
            'error_count_last_1h': result.get('hits', {}).get('total', {}).get('value', 0),
            'index_pattern': LOG_INDEX_PATTERN
        }
    except HTTPError as e:
        if e.code == 404:
            return {'error': 'Index not found', 'index_pattern': LOG_INDEX_PATTERN}
        return {'error': str(e)}
    except Exception as e:
        return {'error': str(e)}


def list_indices() -> dict:
    """List all indices in OpenSearch."""
    try:
        result = make_opensearch_request('GET', '/_cat/indices?format=json')
        indices = []
        for idx in result:
            if not idx.get('index', '').startswith('.'):  # Skip system indices
                indices.append({
                    'index': idx.get('index'),
                    'docs_count': idx.get('docs.count'),
                    'store_size': idx.get('store.size'),
                    'health': idx.get('health')
                })
        return {'indices': indices, 'total': len(indices)}
    except Exception as e:
        return {'error': str(e)}


def sample_logs() -> dict:
    """Get sample logs to understand the log structure."""
    try:
        result = make_opensearch_request('GET', f'/{LOG_INDEX_PATTERN}/_search', {
            "size": 5,
            "sort": [{"@timestamp": {"order": "desc"}}],
            "query": {"match_all": {}}
        })
        samples = []
        for hit in result.get('hits', {}).get('hits', []):
            source = hit.get('_source', {})
            # Get all field names
            samples.append({
                'fields': list(source.keys()),
                'level': source.get('level'),
                'log_level': source.get('log_level'),
                'severity': source.get('severity'),
                'message_preview': str(source.get('message', ''))[:200] if source.get('message') else None,
                'log_preview': str(source.get('log', ''))[:200] if source.get('log') else None
            })
        return {
            'samples': samples,
            'total_in_index': result.get('hits', {}).get('total', {}).get('value', 0),
            'index_pattern': LOG_INDEX_PATTERN
        }
    except HTTPError as e:
        return {'error': f"HTTP Error {e.code}", 'index_pattern': LOG_INDEX_PATTERN}
    except Exception as e:
        return {'error': str(e)}


def execute_monitor(monitor_id: str) -> dict:
    """Execute a monitor manually and return results."""
    try:
        result = make_opensearch_request('POST', f'/_plugins/_alerting/monitors/{monitor_id}/_execute', {
            "dryrun": True
        })

        # Parse execution results
        execution = result.get('monitor_run_result', result)
        trigger_results = execution.get('trigger_results', {})
        input_results = execution.get('input_results', {})

        parsed = {
            'monitor_id': monitor_id,
            'monitor_name': execution.get('monitor_name'),
            'period_start': execution.get('period_start'),
            'period_end': execution.get('period_end'),
            'error': execution.get('error'),
            'triggers': {},
            'query_results': {}
        }

        # Parse trigger results
        for trigger_id, trigger_result in trigger_results.items():
            parsed['triggers'][trigger_id] = {
                'name': trigger_result.get('name'),
                'triggered': trigger_result.get('triggered'),
                'error': trigger_result.get('error'),
                'action_results': trigger_result.get('action_results', {})
            }

        # Parse input/query results
        if 'results' in input_results:
            for idx, result_data in enumerate(input_results['results']):
                if 'hits' in result_data:
                    parsed['query_results'][f'input_{idx}'] = {
                        'total_hits': result_data['hits'].get('total', {}).get('value', 0),
                        'sample_hits': len(result_data['hits'].get('hits', []))
                    }

        return parsed
    except HTTPError as e:
        error_body = e.read().decode('utf-8') if hasattr(e, 'read') else str(e)
        return {'error': f"HTTP Error {e.code}", 'details': error_body, 'monitor_id': monitor_id}
    except Exception as e:
        return {'error': str(e), 'monitor_id': monitor_id}


def handler(event: dict, context: Any) -> dict:
    """Lambda handler for OpenSearch alerting setup."""
    logger.info(f"Received event: {json.dumps(event)}")

    action = event.get('action', 'setup_all')

    if action == 'setup_all':
        result = setup_all_alerting()
    elif action == 'list_monitors':
        result = list_monitors()
    elif action == 'debug_list_monitors':
        result = debug_list_monitors()
    elif action == 'list_destinations':
        result = list_destinations()
    elif action == 'list_channels':
        result = list_notification_channels()
    elif action == 'check_alerts':
        result = check_alerts_history()
    elif action == 'test_query':
        result = test_error_query()
    elif action == 'execute_monitor':
        monitor_id = event.get('monitor_id')
        if not monitor_id:
            result = {'error': 'monitor_id is required'}
        else:
            result = execute_monitor(monitor_id)
    elif action == 'list_indices':
        result = list_indices()
    elif action == 'sample_logs':
        result = sample_logs()
    elif action == 'delete_monitor':
        monitor_id = event.get('monitor_id')
        if not monitor_id:
            result = {'error': 'monitor_id is required'}
        else:
            result = delete_monitor(monitor_id)
    elif action == 'delete_all_monitors':
        result = delete_all_monitors()
    elif action == 'clean_and_setup':
        result = clean_and_setup()
    else:
        result = {'error': f"Unknown action: {action}"}

    logger.info(f"Result: {json.dumps(result, default=str)}")

    return {
        'statusCode': 200 if 'error' not in result else 500,
        'body': json.dumps(result, default=str)
    }
