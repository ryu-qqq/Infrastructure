#!/usr/bin/env python3
"""
IAM policy 업데이트 스크립트
GitHubActionsRole에 RDS 관련 권한 추가
"""
import json
import subprocess
import sys

# 현재 policy 가져오기
result = subprocess.run(
    ['aws', 'iam', 'get-role-policy', '--role-name', 'GitHubActionsRole', '--policy-name', 'GitHubActionsPermissions', '--output', 'json'],
    capture_output=True,
    text=True
)

if result.returncode != 0:
    print(f"Error getting current policy: {result.stderr}")
    sys.exit(1)

policy_data = json.loads(result.stdout)
current_policy = policy_data['PolicyDocument']

# IAMRoleManagement statement 찾아서 Resource 추가
for statement in current_policy['Statement']:
    if statement.get('Sid') == 'IAMRoleManagement':
        if 'arn:aws:iam::646886795421:role/prod-shared-mysql-monitoring-role' not in statement['Resource']:
            statement['Resource'].append('arn:aws:iam::646886795421:role/prod-shared-mysql-monitoring-role')
        break

# SecurityGroupManagement statement 업데이트 - RDS용 보안 그룹도 허용
for statement in current_policy['Statement']:
    if statement.get('Sid') == 'SecurityGroupManagement':
        # Condition을 제거하거나 더 유연하게 변경
        if 'Condition' in statement:
            # 조건을 OR 로직으로 변경
            statement['Condition'] = {
                "StringLike": {
                    "aws:RequestTag/ManagedBy": "Terraform"
                }
            }
        break

# SecretsManagerManagement statement 찾아서 Resource 추가
for statement in current_policy['Statement']:
    if statement.get('Sid') == 'SecretsManagerManagement':
        if 'arn:aws:secretsmanager:ap-northeast-2:646886795421:secret:prod-shared-mysql-*' not in statement['Resource']:
            statement['Resource'].append('arn:aws:secretsmanager:ap-northeast-2:646886795421:secret:prod-shared-mysql-*')
        break

# MonitoringCloudWatchAlarms statement 찾아서 Resource 추가
for statement in current_policy['Statement']:
    if statement.get('Sid') == 'MonitoringCloudWatchAlarms':
        if 'arn:aws:cloudwatch:ap-northeast-2:646886795421:alarm:prod-shared-mysql-*' not in statement['Resource']:
            statement['Resource'].append('arn:aws:cloudwatch:ap-northeast-2:646886795421:alarm:prod-shared-mysql-*')
        break

# RDS 관련 새로운 statement 추가
rds_statements = [
    {
        "Sid": "RDSManagement",
        "Effect": "Allow",
        "Action": [
            "rds:CreateDBInstance",
            "rds:DeleteDBInstance",
            "rds:DescribeDBInstances",
            "rds:ModifyDBInstance",
            "rds:CreateDBSubnetGroup",
            "rds:DeleteDBSubnetGroup",
            "rds:DescribeDBSubnetGroups",
            "rds:ModifyDBSubnetGroup",
            "rds:CreateDBParameterGroup",
            "rds:DeleteDBParameterGroup",
            "rds:DescribeDBParameterGroups",
            "rds:ModifyDBParameterGroup",
            "rds:DescribeDBParameters",
            "rds:ModifyDBParameter",
            "rds:AddTagsToResource",
            "rds:RemoveTagsFromResource",
            "rds:ListTagsForResource",
            "rds:DescribeDBEngineVersions"
        ],
        "Resource": "*"
    }
]

# 기존에 RDSManagement statement가 없으면 추가
if not any(s.get('Sid') == 'RDSManagement' for s in current_policy['Statement']):
    current_policy['Statement'].extend(rds_statements)

# 업데이트된 정책 저장
with open('/tmp/updated-policy.json', 'w') as f:
    json.dump(current_policy, f, indent=2)

print("Updated policy saved to /tmp/updated-policy.json")
print("\nNew RDS permissions added:")
print("- RDSManagement statement")
print("- IAMRoleManagement: added prod-shared-mysql-monitoring-role")
print("- SecretsManagerManagement: added prod-shared-mysql-* secrets")
print("- MonitoringCloudWatchAlarms: added prod-shared-mysql-* alarms")
print("- SecurityGroupManagement: relaxed conditions for RDS security groups")
