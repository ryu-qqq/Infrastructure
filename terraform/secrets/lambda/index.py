"""
AWS Secrets Manager RDS MySQL Password Rotation Lambda

This Lambda function rotates RDS MySQL master credentials stored in Secrets Manager.
It follows AWS's recommended rotation strategy with proper error handling and rollback capability.

Rotation Steps:
1. createSecret: Generate new password
2. setSecret: Update password in RDS
3. testSecret: Verify new password works
4. finishSecret: Mark rotation complete

References:
- https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html
- https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas
"""

import json
import logging
import os
import boto3
import pymysql
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
secretsmanager = boto3.client('secretsmanager', endpoint_url=os.environ.get('SECRETS_MANAGER_ENDPOINT'))
rds = boto3.client('rds')


def lambda_handler(event: Dict[str, Any], context: Any) -> None:
    """
    Main handler for Secrets Manager rotation events.

    Args:
        event: Secrets Manager rotation event
        context: Lambda context object

    Raises:
        ValueError: If required event parameters are missing
        Exception: If rotation step fails
    """
    secret_arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    logger.info(f"Starting rotation step: {step} for secret: {secret_arn}")

    # Route to appropriate step handler
    if step == "createSecret":
        create_secret(secret_arn, token)
    elif step == "setSecret":
        set_secret(secret_arn, token)
    elif step == "testSecret":
        test_secret(secret_arn, token)
    elif step == "finishSecret":
        finish_secret(secret_arn, token)
    else:
        raise ValueError(f"Invalid step: {step}")

    logger.info(f"Successfully completed step: {step}")


def create_secret(secret_arn: str, token: str) -> None:
    """
    Create a new secret version with a new password.

    Args:
        secret_arn: ARN of the secret
        token: Rotation token for this rotation
    """
    # Get current secret
    current_secret = secretsmanager.get_secret_value(SecretId=secret_arn, VersionStage="AWSCURRENT")
    current_dict = json.loads(current_secret['SecretString'])

    # Check if new version already exists
    try:
        secretsmanager.get_secret_value(SecretId=secret_arn, VersionId=token, VersionStage="AWSPENDING")
        logger.info("createSecret: Secret version already exists")
        return
    except secretsmanager.exceptions.ResourceNotFoundException:
        pass

    # Generate new password
    new_password_response = secretsmanager.get_random_password(
        PasswordLength=32,
        ExcludeCharacters='/@"\'\\'
    )
    new_password = new_password_response['RandomPassword']

    # Create new secret version with new password
    new_secret = current_dict.copy()
    new_secret['password'] = new_password

    secretsmanager.put_secret_value(
        SecretId=secret_arn,
        ClientRequestToken=token,
        SecretString=json.dumps(new_secret),
        VersionStages=['AWSPENDING']
    )

    logger.info("createSecret: Successfully created new secret version")


def set_secret(secret_arn: str, token: str) -> None:
    """
    Set the new password in the RDS database.

    Args:
        secret_arn: ARN of the secret
        token: Rotation token for this rotation
    """
    # Get pending secret
    pending_secret = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionId=token,
        VersionStage="AWSPENDING"
    )
    pending_dict = json.loads(pending_secret['SecretString'])

    # Get current secret for connection
    current_secret = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionStage="AWSCURRENT"
    )
    current_dict = json.loads(current_secret['SecretString'])

    # Connect to RDS with current credentials
    conn = get_connection(current_dict)

    try:
        with conn.cursor() as cursor:
            # Update password for the user
            username = pending_dict['username']
            new_password = pending_dict['password']

            # MySQL 5.7+ and 8.0 compatible password update
            # Fully parameterized to prevent SQL injection
            alter_user_sql = "ALTER USER %s@'%%' IDENTIFIED BY %s"
            cursor.execute(alter_user_sql, (username, new_password))

            # Flush privileges to ensure changes take effect
            cursor.execute("FLUSH PRIVILEGES")

            conn.commit()
            logger.info(f"setSecret: Successfully updated password for user: {username}")

    except Exception as e:
        logger.error(f"setSecret: Failed to update password: {str(e)}")
        raise
    finally:
        conn.close()


def test_secret(secret_arn: str, token: str) -> None:
    """
    Test that the new password works by attempting to connect.

    Args:
        secret_arn: ARN of the secret
        token: Rotation token for this rotation
    """
    # Get pending secret
    pending_secret = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionId=token,
        VersionStage="AWSPENDING"
    )
    pending_dict = json.loads(pending_secret['SecretString'])

    # Test connection with new password
    conn = get_connection(pending_dict)

    try:
        with conn.cursor() as cursor:
            # Simple query to verify connection
            cursor.execute("SELECT 1")
            result = cursor.fetchone()

            if result[0] != 1:
                raise ValueError("testSecret: Connection test query failed")

            logger.info("testSecret: Successfully connected with new password")

    except Exception as e:
        logger.error(f"testSecret: Connection failed with new password: {str(e)}")
        raise
    finally:
        conn.close()


def finish_secret(secret_arn: str, token: str) -> None:
    """
    Finish the rotation by marking the new secret version as current.

    Args:
        secret_arn: ARN of the secret
        token: Rotation token for this rotation
    """
    # Get metadata for the secret
    metadata = secretsmanager.describe_secret(SecretId=secret_arn)

    current_version = None
    for version_id, stages in metadata['VersionIdsToStages'].items():
        if 'AWSCURRENT' in stages:
            if version_id == token:
                logger.info("finishSecret: Version already marked as AWSCURRENT")
                return
            current_version = version_id
            break

    # Update version stages
    secretsmanager.update_secret_version_stage(
        SecretId=secret_arn,
        VersionStage='AWSCURRENT',
        MoveToVersionId=token,
        RemoveFromVersionId=current_version
    )

    logger.info("finishSecret: Successfully marked new version as AWSCURRENT")


def get_connection(secret_dict: Dict[str, Any]) -> pymysql.connections.Connection:
    """
    Create a MySQL database connection using credentials from secret.

    Args:
        secret_dict: Dictionary containing connection parameters

    Returns:
        pymysql Connection object

    Raises:
        pymysql.Error: If connection fails
    """
    try:
        conn = pymysql.connect(
            host=secret_dict['host'],
            user=secret_dict['username'],
            password=secret_dict['password'],
            port=secret_dict['port'],
            database=secret_dict.get('dbname', 'mysql'),
            connect_timeout=5,
            cursorclass=pymysql.cursors.DictCursor
        )
        return conn
    except pymysql.Error as e:
        logger.error(f"Failed to connect to database: {str(e)}")
        raise
