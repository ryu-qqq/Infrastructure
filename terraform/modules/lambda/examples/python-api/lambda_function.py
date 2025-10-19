"""
Python Lambda Function Example
This is a simple API handler demonstrating Lambda best practices.
"""

import json
import logging
import os

# Configure logging
logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level))


def lambda_handler(event, context):
    """
    Main Lambda handler function for API requests.

    Args:
        event: API Gateway event object
        context: Lambda context object

    Returns:
        dict: API Gateway response object
    """
    logger.info(f"Processing request: {event.get('requestContext', {}).get('requestId', 'unknown')}")

    # Extract request information
    http_method = event.get('httpMethod', 'GET')
    path = event.get('path', '/')
    query_params = event.get('queryStringParameters', {})
    body = event.get('body')

    logger.debug(f"Method: {http_method}, Path: {path}")

    try:
        # Parse body if present
        if body:
            try:
                body = json.loads(body)
            except json.JSONDecodeError:
                return create_response(400, {'error': 'Invalid JSON in request body'})

        # Route to appropriate handler
        if path == '/health':
            return handle_health_check()
        elif path == '/api/v1/users' and http_method == 'GET':
            return handle_get_users(query_params)
        elif path == '/api/v1/users' and http_method == 'POST':
            return handle_create_user(body)
        else:
            return create_response(404, {'error': f'Route not found: {http_method} {path}'})

    except Exception as e:
        logger.error(f"Unhandled exception: {str(e)}", exc_info=True)
        return create_response(500, {'error': 'Internal server error'})


def handle_health_check():
    """Health check endpoint."""
    return create_response(200, {
        'status': 'healthy',
        'environment': os.environ.get('ENVIRONMENT', 'unknown'),
        'version': os.environ.get('API_VERSION', 'unknown')
    })


def handle_get_users(query_params):
    """
    Get users endpoint.

    Args:
        query_params: Query string parameters

    Returns:
        dict: API response
    """
    # Example: In production, this would query a database
    try:
        limit = int(query_params.get('limit', 10))
        offset = int(query_params.get('offset', 0))
    except (ValueError, TypeError):
        return create_response(400, {'error': 'Invalid limit or offset. Must be an integer.'})

    logger.info(f"Fetching users: limit={limit}, offset={offset}")

    # Mock user data
    users = [
        {'id': i, 'name': f'User {i}', 'email': f'user{i}@example.com'}
        for i in range(offset, offset + limit)
    ]

    return create_response(200, {
        'users': users,
        'total': len(users),
        'limit': limit,
        'offset': offset
    })


def handle_create_user(body):
    """
    Create user endpoint.

    Args:
        body: Request body

    Returns:
        dict: API response
    """
    if not body:
        return create_response(400, {'error': 'Request body is required'})

    # Validate required fields
    required_fields = ['name', 'email']
    missing_fields = [field for field in required_fields if field not in body]

    if missing_fields:
        return create_response(400, {
            'error': f'Missing required fields: {", ".join(missing_fields)}'
        })

    # Example: In production, this would create a user in database
    logger.info(f"Creating user: {body.get('name')}")

    user = {
        'id': 12345,  # Mock ID
        'name': body['name'],
        'email': body['email'],
        'created_at': '2024-01-01T00:00:00Z'
    }

    return create_response(201, {'user': user})


def create_response(status_code, body, headers=None):
    """
    Create API Gateway response object.

    Args:
        status_code: HTTP status code
        body: Response body (will be JSON encoded)
        headers: Optional custom headers

    Returns:
        dict: API Gateway response object
    """
    default_headers = {
        'Content-Type': 'application/json',
        'X-API-Version': os.environ.get('API_VERSION', 'unknown')
    }

    if headers:
        default_headers.update(headers)

    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body)
    }
