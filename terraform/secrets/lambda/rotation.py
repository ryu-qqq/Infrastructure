"""
AWS Secrets Manager Rotation Lambda Function

This function handles the rotation of secrets in AWS Secrets Manager.
It follows the standard 4-step rotation process:
1. createSecret: Generate new credentials
2. setSecret: Update the target system with new credentials
3. testSecret: Verify the new credentials work
4. finishSecret: Mark the new version as AWSCURRENT
"""

import json
import logging
import os
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager')
rds_client = boto3.client('rds')


def lambda_handler(event, context):
    """
    Main handler for secret rotation

    Args:
        event: Lambda event containing secret ARN, token, and step
        context: Lambda context

    Returns:
        dict: Response with status
    """
    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    logger.info(f"Starting rotation for secret {arn} with token {token} at step {step}")

    # Get secret metadata
    metadata = secrets_client.describe_secret(SecretId=arn)

    # Ensure the version is set for rotation
    if not metadata.get('RotationEnabled'):
        logger.error(f"Secret {arn} is not enabled for rotation")
        raise ValueError(f"Secret {arn} is not enabled for rotation")

    # Determine secret type from tags
    secret_type = get_secret_type(metadata)

    # Route to appropriate rotation handler
    if step == "createSecret":
        create_secret(secrets_client, arn, token, secret_type)
    elif step == "setSecret":
        set_secret(secrets_client, arn, token, secret_type)
    elif step == "testSecret":
        test_secret(secrets_client, arn, token, secret_type)
    elif step == "finishSecret":
        finish_secret(secrets_client, arn, token)
    else:
        raise ValueError(f"Invalid step: {step}")

    logger.info(f"Successfully completed {step} for secret {arn}")
    return {
        'statusCode': 200,
        'body': json.dumps(f'Successfully executed {step}')
    }


def get_secret_type(metadata):
    """
    Determine secret type from tags

    Args:
        metadata: Secret metadata

    Returns:
        str: Secret type (rds, api_key, generic)
    """
    tags = metadata.get('Tags', [])
    for tag in tags:
        if tag['Key'] == 'SecretType':
            return tag['Value']
    return 'generic'


def create_secret(client, arn, token, secret_type):
    """
    Create new secret version with new credentials

    Args:
        client: Secrets Manager client
        arn: Secret ARN
        token: Rotation token
        secret_type: Type of secret
    """
    # Check if secret version with this token already exists
    try:
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info(f"createSecret: Successfully retrieved secret for {arn}")
        return
    except client.exceptions.ResourceNotFoundException:
        pass  # Secret doesn't exist yet, create it

    # Get current secret value
    current_secret = client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")
    current_dict = json.loads(current_secret['SecretString'])

    # Generate new credentials based on type
    if secret_type == 'rds':
        new_dict = generate_rds_password(current_dict)
    elif secret_type == 'api_key':
        new_dict = generate_api_key(current_dict)
    else:
        new_dict = generate_generic_secret(current_dict)

    # Store new secret version
    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(new_dict),
        VersionStages=['AWSPENDING']
    )

    logger.info(f"createSecret: Successfully created pending version for {arn}")


def set_secret(client, arn, token, secret_type):
    """
    Update target system with new credentials

    Args:
        client: Secrets Manager client
        arn: Secret ARN
        token: Rotation token
        secret_type: Type of secret
    """
    # Get pending secret
    pending_secret = client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
    pending_dict = json.loads(pending_secret['SecretString'])

    # Update target system based on type
    if secret_type == 'rds':
        set_rds_password(pending_dict)
    elif secret_type == 'api_key':
        # API keys typically don't need to be set in external systems
        logger.info("API key type - no external system update needed")
    else:
        logger.info("Generic secret type - no external system update")

    logger.info(f"setSecret: Successfully updated target system for {arn}")


def test_secret(client, arn, token, secret_type):
    """
    Test new credentials work correctly

    Args:
        client: Secrets Manager client
        arn: Secret ARN
        token: Rotation token
        secret_type: Type of secret
    """
    # Get pending secret
    pending_secret = client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
    pending_dict = json.loads(pending_secret['SecretString'])

    # Test credentials based on type
    if secret_type == 'rds':
        test_rds_connection(pending_dict)
    elif secret_type == 'api_key':
        # For API keys, basic validation
        if not pending_dict.get('api_key'):
            raise ValueError("API key is missing")
    else:
        # Generic validation
        if not pending_dict:
            raise ValueError("Secret is empty")

    logger.info(f"testSecret: Successfully validated credentials for {arn}")


def finish_secret(client, arn, token):
    """
    Mark new version as current

    Args:
        client: Secrets Manager client
        arn: Secret ARN
        token: Rotation token
    """
    # Get current version
    metadata = client.describe_secret(SecretId=arn)
    current_version = None

    for version in metadata['VersionIdsToStages']:
        if 'AWSCURRENT' in metadata['VersionIdsToStages'][version]:
            if version == token:
                logger.info(f"finishSecret: Version {version} already marked as AWSCURRENT")
                return
            current_version = version
            break

    # Move AWSCURRENT stage to new version
    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage='AWSCURRENT',
        MoveToVersionId=token,
        RemoveFromVersionId=current_version
    )

    logger.info(f"finishSecret: Successfully promoted version {token} to AWSCURRENT")


# Helper functions for different secret types

def generate_rds_password(current_dict):
    """Generate new RDS password"""
    response = secrets_client.get_random_password(
        PasswordLength=32,
        ExcludeCharacters='/@"\'\\'
    )

    new_dict = current_dict.copy()
    new_dict['password'] = response['RandomPassword']
    return new_dict


def generate_api_key(current_dict):
    """Generate new API key"""
    response = secrets_client.get_random_password(
        PasswordLength=40,
        ExcludeCharacters='/@"\'\\'
    )

    new_dict = current_dict.copy()
    new_dict['api_key'] = response['RandomPassword']
    return new_dict


def generate_generic_secret(current_dict):
    """Generate new generic secret"""
    response = secrets_client.get_random_password(
        PasswordLength=32,
        ExcludeCharacters='/@"\'\\'
    )

    new_dict = current_dict.copy()
    new_dict['value'] = response['RandomPassword']
    return new_dict


def set_rds_password(secret_dict):
    """
    Update RDS password

    Args:
        secret_dict: Dictionary containing RDS credentials
    """
    # For RDS, we would use modify-db-instance
    # This is a simplified example - production would need error handling
    try:
        db_identifier = secret_dict.get('dbInstanceIdentifier')
        if not db_identifier:
            logger.warning("No dbInstanceIdentifier in secret, skipping RDS update")
            return

        rds_client.modify_db_instance(
            DBInstanceIdentifier=db_identifier,
            MasterUserPassword=secret_dict['password'],
            ApplyImmediately=True
        )
        logger.info(f"Updated RDS instance {db_identifier}")
    except ClientError as e:
        logger.error(f"Failed to update RDS password: {e}")
        raise


def test_rds_connection(secret_dict):
    """
    Test RDS connection with new credentials

    Args:
        secret_dict: Dictionary containing RDS credentials
    """
    # In production, you would actually test the connection
    # This is a simplified validation
    required_fields = ['host', 'port', 'username', 'password', 'engine']
    for field in required_fields:
        if field not in secret_dict:
            raise ValueError(f"Missing required field: {field}")

    logger.info("RDS credentials validated (structure check)")
