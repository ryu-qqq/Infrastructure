# Security Scan Report Template

**Scan Date**: YYYY-MM-DD
**Scanned By**: [Name/Team]
**Scan Tool**: tfsec v[version]
**Configuration**: `.tfsec/config.yml`
**Terraform Version**: [version]

---

## Executive Summary

**Overall Status**: ✅ PASS / ⚠️ WARNINGS / ❌ FAIL

**Total Issues Found**: [number]
- 🚨 **Critical**: [count]
- ❌ **High**: [count]
- ⚠️ **Medium**: [count]
- ℹ️ **Low**: [count]

**Risk Level**: CRITICAL / HIGH / MEDIUM / LOW

**Action Required**: YES / NO

---

## Scan Coverage

### Scanned Directories
- `terraform/atlantis/`
- `terraform/logging/`
- `terraform/monitoring/`
- `terraform/modules/`

### Files Scanned
- **Total Terraform Files**: [count]
- **Total Resources**: [count]
- **Lines of Code**: [count]

### Scan Configuration
- **Minimum Severity**: MEDIUM
- **Excluded Checks**: [list or "None"]
- **Custom Rules**: [list or "None"]

---

## Critical Issues (🚨)

_If no critical issues, write "None"_

### Issue #1: [Rule ID] - [Description]

**Severity**: CRITICAL
**Rule**: `[aws-xxx-rule-name]`
**Resource**: `[resource_type.resource_name]`
**File**: `[file_path]:[line_number]`

**Description**:
[Detailed explanation of the security issue]

**Impact**:
[What could happen if this issue is exploited]

**Remediation**:
```hcl
# Example fix
resource "aws_s3_bucket" "example" {
  # Add required security configuration
}
```

**Priority**: P0 (Immediate)
**Assigned To**: [Name]
**Status**: 🔴 Open / 🟡 In Progress / 🟢 Resolved

---

## High Issues (❌)

_If no high issues, write "None"_

### Issue #2: [Rule ID] - [Description]

**Severity**: HIGH
**Rule**: `[aws-xxx-rule-name]`
**Resource**: `[resource_type.resource_name]`
**File**: `[file_path]:[line_number]`

**Description**:
[Detailed explanation]

**Impact**:
[Security impact]

**Remediation**:
[Code fix or configuration change]

**Priority**: P1 (Within 24 hours)
**Assigned To**: [Name]
**Status**: 🔴 Open / 🟡 In Progress / 🟢 Resolved

---

## Medium Issues (⚠️)

_If no medium issues, write "None"_

### Issue #3: [Rule ID] - [Description]

**Severity**: MEDIUM
**Rule**: `[aws-xxx-rule-name]`
**Resource**: `[resource_type.resource_name]`
**File**: `[file_path]:[line_number]`

**Description**:
[Explanation]

**Remediation**:
[Fix]

**Priority**: P2 (Within 1 week)
**Assigned To**: [Name]
**Status**: 🔴 Open / 🟡 In Progress / 🟢 Resolved

---

## Low Issues (ℹ️)

_Optional: List low severity issues for awareness_

[Brief list or "Not included in this report"]

---

## False Positives / Accepted Risks

### Excluded Issues

| Rule ID | Resource | Justification | Approved By | Date |
|---------|----------|---------------|-------------|------|
| `aws-xxx-yyy` | `resource.name` | [Reason for exclusion] | [Name] | YYYY-MM-DD |

**Note**: All exclusions must be documented and approved.

---

## Trend Analysis

### Historical Comparison

| Scan Date | Critical | High | Medium | Low | Total |
|-----------|----------|------|--------|-----|-------|
| YYYY-MM-DD | X | X | X | X | X |
| YYYY-MM-DD | X | X | X | X | X |
| YYYY-MM-DD | X | X | X | X | X |

**Trend**: 📈 Increasing / 📉 Decreasing / ➡️ Stable

**Analysis**:
[Brief trend analysis and insights]

---

## Compliance Status

### Security Standards Alignment

- [x] AWS Security Best Practices
- [x] CIS Benchmarks
- [x] Internal Governance Standards (docs/governance/)
- [ ] SOC 2 Requirements
- [ ] ISO 27001 Controls

### Governance Alignment

| Standard | Status | Notes |
|----------|--------|-------|
| **Encryption** (KMS required) | ✅ / ⚠️ / ❌ | [Notes] |
| **Tagging** (7 required tags) | ✅ / ⚠️ / ❌ | [Notes] |
| **Naming Conventions** | ✅ / ⚠️ / ❌ | [Notes] |
| **Public Access Controls** | ✅ / ⚠️ / ❌ | [Notes] |

---

## Remediation Plan

### Immediate Actions (P0 - Critical)

1. **[Issue Description]**
   - Assigned: [Name]
   - Due: [Date]
   - Status: 🔴 Not Started

### Short-term Actions (P1 - High)

1. **[Issue Description]**
   - Assigned: [Name]
   - Due: [Date]
   - Status: 🟡 In Progress

### Medium-term Actions (P2 - Medium)

1. **[Issue Description]**
   - Assigned: [Name]
   - Due: [Date]
   - Status: 🟢 Completed

---

## Recommendations

### Process Improvements

1. **[Recommendation]**
   - Impact: HIGH / MEDIUM / LOW
   - Effort: HIGH / MEDIUM / LOW
   - Priority: [Ranking]

### Tool Configuration

1. **[Configuration Change]**
   - File: `.tfsec/config.yml`
   - Change: [Description]
   - Reason: [Justification]

### Training Needs

1. **[Training Topic]**
   - Audience: [Team/Role]
   - Format: Workshop / Documentation / Hands-on
   - Timeline: [Date]

---

## Next Steps

### Action Items

- [ ] **Review all Critical and High issues** - Due: [Date]
- [ ] **Assign issues to team members** - Due: [Date]
- [ ] **Update `.tfsec/config.yml` if needed** - Due: [Date]
- [ ] **Schedule remediation work** - Due: [Date]
- [ ] **Re-scan after fixes** - Due: [Date]
- [ ] **Update governance documentation** - Due: [Date]

### Follow-up Scan

**Scheduled Date**: YYYY-MM-DD
**Expected Status**: [All Critical/High resolved]

---

## Attachments

### Detailed Scan Output

- **JSON Report**: `tfsec-results.json`
- **HTML Report**: `tfsec-results.html` (if generated)
- **SARIF Report**: `tfsec-results.sarif` (for IDE integration)

### Related Documentation

- [Infrastructure Governance](./infrastructure_governance.md)
- [Tagging Standards](./TAGGING_STANDARDS.md)
- [Naming Conventions](./NAMING_CONVENTION.md)
- [Security Baseline](./.tfsec/config.yml)

---

## Sign-off

**Reported By**: [Name] - [Date]
**Reviewed By**: [Name] - [Date]
**Approved By**: [Name] - [Date]

**Comments**:
[Any additional notes or context]

---

## Appendix

### tfsec Command Used

```bash
tfsec terraform/ \
  --config-file .tfsec/config.yml \
  --format json \
  --out tfsec-results.json \
  --minimum-severity MEDIUM
```

### Configuration Summary

```yaml
minimum_severity: MEDIUM
fail_on_severity: MEDIUM
soft_fail: false
include:
  - terraform/atlantis/**
  - terraform/logging/**
  - terraform/monitoring/**
  - terraform/modules/**
```

### Useful Links

- **tfsec Documentation**: https://aquasecurity.github.io/tfsec/
- **AWS Security Best Practices**: https://docs.aws.amazon.com/security/
- **CIS Benchmarks**: https://www.cisecurity.org/benchmark/amazon_web_services
- **Terraform Security**: https://www.terraform.io/docs/cloud/sentinel/index.html
