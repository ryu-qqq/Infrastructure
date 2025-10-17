# Infrastructure Checks Workflow Usage Guide

This guide explains how to integrate the centralized Infrastructure Checks workflow into service repositories.

## Overview

The `infra-checks.yml` reusable workflow provides automated security, policy, and cost validation for Terraform infrastructure code. It integrates:

- **tfsec**: Security vulnerability scanning
- **checkov**: Policy compliance validation (CIS, PCI-DSS, HIPAA, ISO 27001)
- **OPA/Conftest**: Custom policy enforcement
- **Infracost**: Cost estimation and budget validation

## Prerequisites

### Required Tools

The workflow automatically installs all required tools, but your Terraform code must be properly structured:

1. Valid Terraform configuration files (`.tf`)
2. Terraform version 1.6.0 compatible code
3. (Optional) AWS credentials for cloud provider validation

### Required Secrets

Configure these secrets in your repository:

| Secret | Required | Description |
|--------|----------|-------------|
| `INFRACOST_API_KEY` | For cost checks | Get from [Infracost](https://www.infracost.io/) |
| `AWS_ROLE_ARN` | For AWS resources | IAM Role ARN for OIDC authentication |
| `GITHUB_TOKEN` | Automatic | Provided by GitHub Actions |

## Basic Usage

### Minimal Configuration

Create `.github/workflows/terraform-validation.yml` in your service repository:

```yaml
name: Terraform Validation

on:
  pull_request:
    branches:
      - main
    paths:
      - 'terraform/**'
      - 'infrastructure/**'

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  infrastructure-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

This runs all checks with default settings:
- ✅ tfsec security scan
- ✅ checkov policy validation
- ✅ Conftest OPA policies
- ✅ Infracost cost estimation
- ⚠️ Non-blocking (reports issues but doesn't fail workflow)

### Custom Configuration

Customize behavior with input parameters:

```yaml
jobs:
  infrastructure-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      # Terraform directory path
      terraform_directory: 'infrastructure/terraform'

      # Enable/disable specific checks
      run_tfsec: true
      run_checkov: true
      run_conftest: true
      run_infracost: true

      # Cost thresholds
      cost_threshold_warning: 10   # Warn at 10% increase
      cost_threshold_block: 30     # Block at 30% increase

      # Workflow failure conditions
      fail_on_security_issues: false    # Don't fail on security issues
      fail_on_policy_violations: false  # Don't fail on policy violations

    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

## Configuration Options

### Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `terraform_directory` | string | `terraform` | Directory containing Terraform code |
| `run_tfsec` | boolean | `true` | Enable tfsec security scanning |
| `run_checkov` | boolean | `true` | Enable checkov policy checks |
| `run_conftest` | boolean | `true` | Enable OPA/Conftest validation |
| `run_infracost` | boolean | `true` | Enable cost estimation |
| `cost_threshold_warning` | number | `10` | Cost increase % for warning |
| `cost_threshold_block` | number | `30` | Cost increase % for blocking |
| `fail_on_security_issues` | boolean | `false` | Fail workflow on security issues |
| `fail_on_policy_violations` | boolean | `false` | Fail workflow on policy violations |

### Workflow Behavior

#### Non-Blocking Mode (Default)
```yaml
fail_on_security_issues: false
fail_on_policy_violations: false
```

- ✅ All checks run to completion
- 📊 Results reported in PR comments
- ⚠️ Issues highlighted but don't block merge
- 💡 Best for initial adoption and development environments

#### Blocking Mode (Strict)
```yaml
fail_on_security_issues: true
fail_on_policy_violations: true
```

- ❌ Workflow fails on critical/high security issues
- ❌ Workflow fails on policy violations
- 🛑 PR cannot be merged until issues resolved
- 🔒 Best for production environments

## Usage Examples

### Example 1: Development Environment

Permissive settings for rapid iteration:

```yaml
jobs:
  dev-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/dev'
      cost_threshold_warning: 25
      cost_threshold_block: 50
      fail_on_security_issues: false
      fail_on_policy_violations: false
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_DEV_ROLE_ARN }}
```

### Example 2: Production Environment

Strict settings for production safety:

```yaml
jobs:
  prod-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/prod'
      cost_threshold_warning: 5
      cost_threshold_block: 15
      fail_on_security_issues: true
      fail_on_policy_violations: true
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_PROD_ROLE_ARN }}
```

### Example 3: Security-Only Checks

Skip cost analysis, focus on security:

```yaml
jobs:
  security-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      run_tfsec: true
      run_checkov: true
      run_conftest: true
      run_infracost: false  # Skip cost analysis
      fail_on_security_issues: true
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### Example 4: Cost Analysis Only

Focus on cost management:

```yaml
jobs:
  cost-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      run_tfsec: false
      run_checkov: false
      run_conftest: false
      run_infracost: true
      cost_threshold_warning: 10
      cost_threshold_block: 20
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### Example 5: Multi-Environment Pipeline

Different checks for each environment:

```yaml
name: Multi-Environment Validation

on:
  pull_request:
    branches: [main, develop]

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  dev-checks:
    if: github.base_ref == 'develop'
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/dev'
      fail_on_security_issues: false
      fail_on_policy_violations: false
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_DEV_ROLE_ARN }}

  prod-checks:
    if: github.base_ref == 'main'
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/prod'
      cost_threshold_block: 10
      fail_on_security_issues: true
      fail_on_policy_violations: true
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_PROD_ROLE_ARN }}
```

## Understanding Results

### PR Comment Format

The workflow posts a comprehensive report as a PR comment:

```markdown
## 🛡️ Infrastructure Security & Compliance Report

<details><summary>🔒 Security Scan (tfsec)</summary>
✅ No security issues found!
</details>

<details><summary>📋 Policy Compliance (checkov)</summary>
✅ Passed: 45
❌ Failed: 2
⚠️ Action Required: Policy violations must be resolved.
</details>

<details><summary>⚖️ OPA Policy Validation (conftest)</summary>
✅ All OPA policies passed!
</details>

<details><summary>💰 Cost Impact (Infracost)</summary>
💰 Current: $125.50
📊 Previous: $100.00
📈 Increase: +$25.50 (+25.5%)
✅ Within acceptable thresholds
</details>
```

### Result Interpretation

#### Security Scan (tfsec)

- **🚨 Critical**: Immediate security risk, must fix
- **❌ High**: Serious security issue, should fix
- **⚠️ Medium**: Moderate risk, review needed
- **ℹ️ Low**: Minor issue, non-blocking

#### Policy Compliance (checkov)

- **✅ Passed**: Checks passed successfully
- **❌ Failed**: Policy violations detected
- **⊘ Skipped**: Checks not applicable or skipped

#### OPA Policies (Conftest)

- **✅ Passed**: All custom policies satisfied
- **❌ Failed**: Policy violations found

#### Cost Impact (Infracost)

- **✅ OK**: Within acceptable thresholds
- **⚠️ WARNING**: Approaching cost limit
- **🚫 BLOCKED**: Exceeds cost threshold

## Troubleshooting

### Common Issues

#### 1. Workflow Not Found

**Error**: `Unable to resolve action ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main`

**Solution**: Ensure the workflow file exists in the Infrastructure repository and the reference is correct.

#### 2. Infracost Failed

**Error**: `Infracost analysis failed`

**Possible causes**:
- Missing `INFRACOST_API_KEY` secret
- Deletion-only changes (no cost impact)
- Configuration-only changes

**Solution**: Check if changes include billable resources. Cost estimation is skipped for non-billable changes.

#### 3. AWS Authentication Failed

**Error**: `Failed to configure AWS credentials`

**Possible causes**:
- Missing `AWS_ROLE_ARN` secret
- Incorrect IAM role configuration
- OIDC trust relationship not configured

**Solution**:
1. Verify IAM role exists
2. Check OIDC trust policy includes your repository
3. Ensure role has necessary permissions

#### 4. Policy Validation Failed

**Error**: `Conftest policy validation failed`

**Possible causes**:
- Terraform code violates custom policies
- Policy files not available
- Conftest configuration missing

**Solution**:
1. Review policy violations in workflow logs
2. Ensure `conftest.toml` exists in repository
3. Check policy files in `policies/` directory

#### 5. Terraform Init Failed

**Error**: `Terraform initialization failed`

**Possible causes**:
- Invalid Terraform configuration
- Missing provider configuration
- Backend configuration issues

**Solution**:
1. Test Terraform init locally
2. Review Terraform version compatibility
3. Check provider requirements

### Debug Mode

Enable detailed logging for troubleshooting:

**Step-level debug logs**:

To enable step-level debug logs, you must set the following secret in the repository that contains the workflow: `ACTIONS_STEP_DEBUG` to `true`.

1. Go to repository **Settings** → **Secrets and variables** → **Actions**.
2. Create a new repository secret named `ACTIONS_STEP_DEBUG` with the value `true`.
3. Re-run the workflow to see the debug logs.

**Runner diagnostic logs**:

Set the `ACTIONS_RUNNER_DEBUG` repository secret to `true`:
1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Create new repository secret: `ACTIONS_RUNNER_DEBUG` = `true`
3. Re-run the workflow

**Note**: Both debug modes must be enabled via repository secrets, not environment variables in the workflow file. This is because the `env` context from the calling workflow is not passed down to reusable workflows.

## Best Practices

### 1. Start Non-Blocking

Begin with non-blocking mode to understand baseline issues:

```yaml
fail_on_security_issues: false
fail_on_policy_violations: false
```

### 2. Gradual Strictness

Increase strictness over time:

1. **Week 1**: Run all checks, non-blocking
2. **Week 2**: Fix existing issues
3. **Week 3**: Enable `fail_on_security_issues`
4. **Week 4**: Enable `fail_on_policy_violations`

### 3. Environment-Specific Settings

Use stricter settings for production:

- **Development**: Permissive (fast feedback)
- **Staging**: Moderate (catch issues early)
- **Production**: Strict (enforce compliance)

### 4. Cost Monitoring

Set realistic cost thresholds:

- **Warning threshold**: 10% (review required)
- **Block threshold**: 30% (approval needed)

Adjust based on your organization's budget policies.

### 5. Policy Customization

Create custom OPA policies in service repositories:

```bash
service-repo/
├── policies/
│   ├── naming/
│   │   └── naming.rego
│   ├── tagging/
│   │   └── tags.rego
│   └── security/
│       └── security_groups.rego
└── conftest.toml
```

### 6. Version Pinning (Recommended)

**Always pin to specific versions for production environments:**

```yaml
# ✅ RECOMMENDED: Pin to specific version for stability and predictable builds
uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@v1.0.0

# ✅ ALTERNATIVE: Pin to specific commit SHA for maximum stability
uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@a1b2c3d

# ⚠️ NOT RECOMMENDED FOR PRODUCTION: Using @main can pull breaking changes
# Only use @main for development/testing environments where you want latest features
uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
```

**Why version pinning matters:**
- **Predictable Builds**: Same workflow version across all runs, no surprise failures
- **Breaking Change Protection**: Avoid automatic updates that break your pipelines
- **Change Control**: Review and test updates before adopting them
- **Rollback Capability**: Easy to revert to previous version if issues arise

**Update Strategy:**
1. Monitor releases in Infrastructure repository
2. Test new versions in development environment first
3. Update version reference after validation
4. Document version updates in your changelog

## Integration with Other Workflows

### Combine with Terraform Apply

For applying changes after validation, use a separate workflow triggered on `push` to `main`:

**Validation Workflow** (`.github/workflows/terraform-validation.yml`):
```yaml
name: Terraform Validation

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  validate:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

**Apply Workflow** (`.github/workflows/terraform-apply.yml`):
```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

permissions:
  contents: read
  id-token: write

jobs:
  terraform-apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Apply
        working-directory: terraform
        run: |
          terraform init
          terraform apply -auto-approve
```

### Parallel Execution with Other Checks

```yaml
jobs:
  infrastructure-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        run: npm test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: npm run lint
```

## Support and Contributing

### Getting Help

- **Documentation**: Check [Infrastructure Governance](../governance/infrastructure_governance.md)
- **Issues**: Open an issue in the Infrastructure repository
- **Policy Guides**: See [Checkov Policy Guide](../governance/CHECKOV_POLICY_GUIDE.md)

### Contributing

To suggest improvements to the workflow:

1. Fork the Infrastructure repository
2. Create a feature branch
3. Make changes to `.github/workflows/infra-checks.yml`
4. Test in your service repository
5. Submit a pull request

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-01 | Initial release with tfsec, checkov, conftest, infracost |

## Additional Resources

- [tfsec Documentation](https://aquasecurity.github.io/tfsec/)
- [checkov Documentation](https://www.checkov.io/documentation.html)
- [Conftest Documentation](https://www.conftest.dev/)
- [Infracost Documentation](https://www.infracost.io/docs/)
- [GitHub Actions Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
