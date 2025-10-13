# CloudTrail Operations Guide

Operations guide for CloudTrail central logging infrastructure including daily procedures, incident response, and troubleshooting.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Security Alert Response](#security-alert-response)
3. [Log Analysis](#log-analysis)
4. [Troubleshooting](#troubleshooting)
5. [Maintenance](#maintenance)

## Daily Operations

### Health Checks

Run these checks daily or integrate into monitoring dashboard:

```bash
# Check CloudTrail status
aws cloudtrail get-trail-status --name central-cloudtrail

# Expected Output:
# - IsLogging: true
# - LatestDeliveryTime: recent timestamp (< 15 minutes)
# - LatestNotificationTime: recent timestamp

# Check S3 bucket for recent logs
aws s3 ls s3://cloudtrail-logs-<ACCOUNT_ID>/cloudtrail/AWSLogs/<ACCOUNT_ID>/CloudTrail/<AWS_REGION>/$(date +%Y/%m/%d)/ | tail -5

# Check CloudWatch Logs delivery
aws logs describe-log-streams \
  --log-group-name /aws/cloudtrail/central-cloudtrail \
  --max-items 5 \
  --order-by LastEventTime \
  --descending
```

### Security Alert Review

1. **Check SNS Email**: Review security alerts from cloudtrail-security-alerts topic
2. **Priority Classification**:
   - 🚨 **Critical**: Root account usage, IAM policy changes
   - ⚠️ **High**: Unauthorized API calls, security group changes
   - 💡 **Medium**: Console login failures (< 5 attempts)

3. **Investigation Steps**: See [Security Alert Response](#security-alert-response)

## Security Alert Response

### Root Account Usage Alert

**Alert**: `🚨 ROOT ACCOUNT USAGE DETECTED`

**Immediate Actions**:
1. Verify if the root account usage was authorized
2. Check the event details in the alert email
3. Run Athena query to get full context:

```sql
SELECT
  eventtime,
  eventname,
  sourceipaddress,
  useragent,
  requestparameters,
  responseelements
FROM cloudtrail_logs
WHERE useridentity.type = 'Root'
  AND date >= date_format(current_date - interval '30' day, '%Y/%m/%d')  -- Last 30 days
ORDER BY eventtime DESC
LIMIT 100;
```

**Response Protocol**:
- **If Unauthorized**:
  1. Immediately rotate root account credentials
  2. Enable MFA if not already enabled
  3. Review all actions taken by root account
  4. Escalate to security team
  5. Document incident

- **If Authorized**:
  1. Document justification for root account usage
  2. Verify MFA was used
  3. Review if the action could have been performed with IAM role

### Unauthorized API Calls Alert

**Alert**: `⚠️ UNAUTHORIZED API CALL`

**Investigation**:
1. Identify the IAM principal (user/role) from alert
2. Query for patterns of unauthorized attempts:

```sql
SELECT
  useridentity.arn,
  eventname,
  sourceipaddress,
  errorcode,
  count(*) as attempt_count
FROM cloudtrail_logs
WHERE errorcode IN ('UnauthorizedOperation', 'AccessDenied')
  AND date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
GROUP BY useridentity.arn, eventname, sourceipaddress, errorcode
ORDER BY attempt_count DESC;
```

**Response Protocol**:
- **Single Attempt**: Likely legitimate permission issue, notify user/team
- **Multiple Attempts (>10)**:
  1. Check if credentials might be compromised
  2. Rotate credentials if suspicious
  3. Review IAM policies for least privilege
  4. Consider temporary credential suspension

### IAM Policy Changes Alert

**Alert**: `🔐 IAM POLICY CHANGE`

**Verification**:
1. Review the IAM policy change details
2. Query for full context:

```sql
SELECT
  useridentity.arn,
  eventtime,
  eventname,
  requestparameters,
  responseelements
FROM cloudtrail_logs
WHERE eventsource = 'iam.amazonaws.com'
  AND eventname IN (
    'PutUserPolicy', 'PutGroupPolicy', 'PutRolePolicy',
    'CreatePolicy', 'DeletePolicy', 'CreatePolicyVersion',
    'AttachUserPolicy', 'AttachGroupPolicy', 'AttachRolePolicy',
    'DetachUserPolicy', 'DetachGroupPolicy', 'DetachRolePolicy'
  )
  AND date >= date_format(current_date - interval '1' day, '%Y/%m/%d')
ORDER BY eventtime DESC;
```

**Response Protocol**:
1. Verify change request was approved via Jira/ticket
2. Review policy document for overly permissive actions
3. Check for privilege escalation patterns
4. If suspicious:
   - Revert policy change immediately
   - Rotate credentials of the principal who made the change
   - Escalate to security team

### Console Login Failures Alert

**Alert**: `🔒 CONSOLE LOGIN FAILURE`

**Investigation**:
```sql
SELECT
  useridentity.principalid,
  eventtime,
  sourceipaddress,
  useragent,
  count(*) as failure_count
FROM cloudtrail_logs
WHERE eventname = 'ConsoleLogin'
  AND errorcode = 'Failed authentication'
  AND date >= date_format(current_date - interval '1' day, '%Y/%m/%d')
GROUP BY useridentity.principalid, sourceipaddress, useragent
ORDER BY failure_count DESC;
```

**Response Protocol**:
- **< 3 failures**: Likely password typo, no action needed
- **3-10 failures**: Notify user, recommend password reset
- **> 10 failures**:
  1. Potential brute force attack
  2. Temporarily disable user account
  3. Force password reset
  4. Enable MFA if not already enabled
  5. Consider IP-based access restrictions

### Security Group Changes Alert

**Alert**: `🛡️ SECURITY GROUP CHANGE`

**Verification**:
1. Review security group rules that were added/modified
2. Query for details:

```sql
SELECT
  useridentity.arn,
  eventtime,
  eventname,
  requestparameters
FROM cloudtrail_logs
WHERE eventsource = 'ec2.amazonaws.com'
  AND eventname IN (
    'AuthorizeSecurityGroupIngress',
    'AuthorizeSecurityGroupEgress',
    'RevokeSecurityGroupIngress',
    'RevokeSecurityGroupEgress',
    'CreateSecurityGroup',
    'DeleteSecurityGroup'
  )
  AND date >= date_format(current_date - interval '1' day, '%Y/%m/%d')
ORDER BY eventtime DESC;
```

**Red Flags**:
- Opening port 22 (SSH) or 3389 (RDP) to 0.0.0.0/0
- Allowing all traffic (0.0.0.0/0 on all ports)
- Changes from unknown IP addresses

**Response Protocol**:
1. Verify change request via Jira/ticket
2. If opening to 0.0.0.0/0:
   - Confirm business justification
   - Recommend restricting to specific IP ranges
   - Document exception if required
3. If unauthorized:
   - Immediately revert security group rules
   - Rotate credentials
   - Escalate to security team

## Log Analysis

### Common Analysis Scenarios

#### Find All Actions by Specific User
```sql
SELECT
  eventtime,
  eventname,
  sourceipaddress,
  requestparameters
FROM cloudtrail_logs
WHERE useridentity.arn = 'arn:aws:iam::<ACCOUNT_ID>:user/USERNAME'
  AND date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
ORDER BY eventtime DESC;
```

#### Find Who Created/Deleted a Resource
```sql
-- Example: Find who created/deleted an EC2 instance
SELECT
  useridentity.arn,
  eventtime,
  eventname,
  requestparameters,
  responseelements
FROM cloudtrail_logs
WHERE eventname IN ('RunInstances', 'TerminateInstances')
  AND date >= date_format(current_date - interval '30' day, '%Y/%m/%d')
ORDER BY eventtime DESC;
```

#### Track Configuration Changes
```sql
-- Find who modified infrastructure (EC2, RDS, S3, etc.)
SELECT
  eventsource,
  eventname,
  useridentity.arn,
  eventtime,
  count(*) as change_count
FROM cloudtrail_logs
WHERE readonly = 'false'  -- Write operations only
  AND date >= date_format(current_date - interval '7' day, '%Y/%m/%d')
GROUP BY eventsource, eventname, useridentity.arn, eventtime
ORDER BY change_count DESC;
```

#### Detect Data Exfiltration Attempts
```sql
-- Large S3 downloads or suspicious access patterns
SELECT
  useridentity.arn,
  eventtime,
  eventname,
  element_at(resources, 2).ARN as s3_object_arn,
  sourceipaddress
FROM cloudtrail_logs
WHERE eventsource = 's3.amazonaws.com'
  AND eventname = 'GetObject'
  AND date >= date_format(current_date - interval '1' day, '%Y/%m/%d')
ORDER BY eventtime DESC
LIMIT 1000;
```

## Troubleshooting

### CloudTrail Not Logging

**Symptoms**: No recent logs in S3 or CloudWatch Logs

**Diagnosis**:
```bash
# Check trail status
aws cloudtrail get-trail-status --name central-cloudtrail

# Check trail configuration
aws cloudtrail describe-trails --trail-name-list central-cloudtrail
```

**Common Causes**:
1. **Trail Stopped**: `IsLogging: false`
   - **Fix**: Start the trail
   ```bash
   aws cloudtrail start-logging --name central-cloudtrail
   ```

2. **S3 Bucket Permission Issue**: Check `LatestDeliveryError`
   - **Fix**: Verify S3 bucket policy allows CloudTrail to write
   ```bash
   aws s3api get-bucket-policy --bucket cloudtrail-logs-<ACCOUNT_ID>
   ```

3. **KMS Key Permission Issue**: Check `LatestNotificationError`
   - **Fix**: Verify KMS key policy allows CloudTrail to use the key
   ```bash
   aws kms get-key-policy --key-id alias/cloudtrail-logs --policy-name default
   ```

### Athena Query Fails

**Symptoms**: `HIVE_PARTITION_SCHEMA_MISMATCH` or no results

**Diagnosis**:
```sql
-- Test basic query
SELECT * FROM cloudtrail_logs LIMIT 1;

-- Check partitions
SHOW PARTITIONS cloudtrail_logs;
```

**Fix**:
```sql
-- Repair table to discover partitions
MSCK REPAIR TABLE cloudtrail_logs;

-- If still failing, drop and recreate table (Terraform will recreate)
DROP TABLE cloudtrail_logs;
```

### Security Alerts Not Received

**Symptoms**: No email alerts despite security events

**Diagnosis**:
```bash
# Check SNS subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:<AWS_REGION>:<ACCOUNT_ID>:cloudtrail-security-alerts

# Expected: Subscription with status "Confirmed"

# Check EventBridge rules
aws events list-rules --name-prefix cloudtrail-

# Expected: All rules with State "ENABLED"
```

**Fix**:
1. **Subscription Not Confirmed**:
   - Resend confirmation email
   ```bash
   aws sns subscribe \
     --topic-arn arn:aws:sns:<AWS_REGION>:<ACCOUNT_ID>:cloudtrail-security-alerts \
     --protocol email \
     --notification-endpoint your-email@example.com
   ```

2. **EventBridge Rule Disabled**:
   ```bash
   aws events enable-rule --name cloudtrail-root-account-usage
   ```

3. **Test Alert Delivery**:
   ```bash
   aws sns publish \
     --topic-arn arn:aws:sns:<AWS_REGION>:<ACCOUNT_ID>:cloudtrail-security-alerts \
     --subject "Test Alert" \
     --message "This is a test alert from CloudTrail monitoring"
   ```

## Maintenance

### Monthly Tasks

#### Review and Update Named Queries
1. Review existing Athena named queries
2. Add queries for new security patterns
3. Archive unused queries

#### Cost Optimization Review
```bash
# Check S3 storage usage
aws s3 ls s3://cloudtrail-logs-<ACCOUNT_ID> --recursive --human-readable --summarize | grep "Total Size"

# Review Athena query costs
# Navigate to AWS Billing → Cost Explorer → Athena

# Consider adjusting lifecycle policies if costs are high
```

#### Security Alert Tuning
1. Review false positive rate
2. Adjust EventBridge rule patterns if needed
3. Update SNS subscription list

### Quarterly Tasks

#### Compliance Audit
1. Verify all required logs are being captured
2. Review log retention policies
3. Test log restoration from Glacier
4. Generate compliance report

```sql
-- Sample compliance query: Verify CloudTrail has been logging continuously
SELECT
  date,
  count(DISTINCT eventid) as event_count
FROM cloudtrail_logs
WHERE date >= date_format(current_date - interval '90' day, '%Y/%m/%d')
GROUP BY date
ORDER BY date DESC;
```

#### Disaster Recovery Test
1. Test log restoration from S3
2. Verify Athena queries work on historical data
3. Test alert mechanism end-to-end
4. Document any issues and remediation steps

### Annual Tasks

#### Security Review
1. Review all IAM policies related to CloudTrail
2. Audit KMS key policies
3. Review S3 bucket policies
4. Update security alert patterns based on threat landscape

#### Cost-Benefit Analysis
1. Calculate annual CloudTrail costs
2. Review value provided by log analysis
3. Optimize configuration based on usage patterns

## Emergency Procedures

### Suspected Credential Compromise

1. **Immediate Actions**:
   ```bash
   # Disable compromised IAM user/role
   aws iam put-user-policy \
     --user-name COMPROMISED_USER \
     --policy-name DenyAll \
     --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'
   ```

2. **Investigation**:
   ```sql
   -- Find all actions by compromised principal
   SELECT *
   FROM cloudtrail_logs
   WHERE useridentity.arn LIKE '%COMPROMISED_USER%'
     AND date >= date_format(current_date - interval '30' day, '%Y/%m/%d')
   ORDER BY eventtime DESC;
   ```

3. **Remediation**:
   - Rotate all credentials
   - Review and revert unauthorized changes
   - Enable MFA enforcement
   - Document incident

### Log Delivery Failure

1. **Check CloudTrail Status**:
   ```bash
   aws cloudtrail get-trail-status --name central-cloudtrail
   ```

2. **Enable Logging If Stopped**:
   ```bash
   aws cloudtrail start-logging --name central-cloudtrail
   ```

3. **Escalate** if issue persists > 1 hour

## Runbooks

### Runbook: Investigate Unauthorized Access

**Trigger**: AccessDenied or UnauthorizedOperation errors

**Steps**:
1. Identify the principal from alert
2. Run Athena query to find all unauthorized attempts
3. Check if credentials might be compromised
4. Notify principal/team if legitimate permission issue
5. Rotate credentials if suspicious
6. Document findings

**SLA**: Investigate within 1 hour, resolve within 4 hours

### Runbook: Root Account Usage

**Trigger**: Root account activity detected

**Steps**:
1. Verify authorization
2. If unauthorized, immediately rotate credentials
3. Review all root account actions
4. Document incident
5. Escalate to security team

**SLA**: Respond within 15 minutes

### Runbook: Bulk Data Download

**Trigger**: Large number of S3 GetObject calls

**Steps**:
1. Identify source IP and principal
2. Verify if download is authorized
3. Check for data exfiltration patterns
4. If suspicious, block source IP and rotate credentials
5. Document incident

**SLA**: Investigate within 30 minutes

## Related Documentation

- [CloudTrail Module README](../terraform/cloudtrail/README.md)
- [Infrastructure Governance](./infrastructure_governance.md)
- [KMS Strategy Guide](./kms-strategy.md)

## Related Issues

- **Epic**: [IN-98 - EPIC 2: 공통 플랫폼 인프라](https://ryuqqq.atlassian.net/browse/IN-98)
- **Task**: [IN-113 - TASK 2-5: CloudTrail 중앙 수집](https://ryuqqq.atlassian.net/browse/IN-113)
