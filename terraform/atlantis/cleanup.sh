#!/bin/bash
set -e

echo "Cleaning up existing resources..."

# Delete IAM Roles
echo "Deleting IAM roles..."
aws iam delete-role-policy --role-name atlantis-ecs-task-execution-prod --policy-name atlantis-ecs-task-execution-kms 2>/dev/null || true
aws iam detach-role-policy --role-name atlantis-ecs-task-execution-prod --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true
aws iam delete-role --role-name atlantis-ecs-task-execution-prod 2>/dev/null || true

aws iam delete-role-policy --role-name atlantis-ecs-task-prod --policy-name atlantis-terraform-operations 2>/dev/null || true
aws iam delete-role-policy --role-name atlantis-ecs-task-prod --policy-name atlantis-cloudwatch-logs 2>/dev/null || true
aws iam delete-role --role-name atlantis-ecs-task-prod 2>/dev/null || true

# Delete CloudWatch Log Group
echo "Deleting CloudWatch log group..."
aws logs delete-log-group --log-group-name /ecs/atlantis-prod 2>/dev/null || true

# Delete ECS Cluster (if it exists)
echo "Checking ECS cluster..."
if aws ecs describe-clusters --clusters atlantis-prod --region ap-northeast-2 --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
  echo "Deleting ECS cluster..."
  aws ecs delete-cluster --cluster atlantis-prod --region ap-northeast-2 2>/dev/null || true
fi

echo "Cleanup completed!"
