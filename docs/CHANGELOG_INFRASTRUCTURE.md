# Infrastructure Repository Changelog

All notable changes to this infrastructure repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Documentation**: Comprehensive module standards and guides (IN-121)
  - `docs/MODULES_DIRECTORY_STRUCTURE.md` - Module directory structure guide
  - `docs/MODULE_STANDARDS_GUIDE.md` - Coding standards and conventions
  - `docs/MODULE_EXAMPLES_GUIDE.md` - Example structure guide
  - `docs/MODULE_TEMPLATE.md` - README template for modules
  - `docs/VERSIONING.md` - Semantic versioning guide
  - `docs/CHANGELOG_TEMPLATE.md` - Changelog format template
  - `docs/PROJECT_OVERVIEW_KR.md` - Project overview (Korean)
  - `docs/TERRAFORM_MODULES_KR.md` - Terraform modules guide (Korean)
  - `docs/SCRIPTS_GUIDE_KR.md` - Scripts usage guide (Korean)

- **Module Catalog**: `terraform/modules/README.md` with module listing and quick start

- **Archived Documentation**: README files for archived directories
  - `terraform/archived/README.md` - Archive policy and guidance
  - `terraform/archived/atlantis-iam/README.md` - Archived IAM configuration
  - `terraform/archived/bootstrap/README.md` - Archived bootstrap config

### Changed
- **Directory Structure**: Moved inactive configurations to `terraform/archived/`
  - `terraform/atlantis-iam/` → `terraform/archived/atlantis-iam/`
  - `terraform/bootstrap/` → `terraform/archived/bootstrap/`

- **Terraform Naming**: Fixed IAM role resource naming in `terraform/monitoring/amg.tf`
  - Changed `aws_iam_role.grafana-workspace` to `aws_iam_role.grafana_workspace`
  - Compliance with Terraform snake_case convention

- **README.md**: Enhanced with module documentation sections
  - Added module catalog reference
  - Added Korean documentation links
  - Added module quick start examples

### Removed
- **cleanup-kms.sh** (48 lines)
  - **Reason**: Manual AWS Console operations preferred for safety
  - **Migration**: Use `aws kms list-keys --region ap-northeast-2` and AWS Console
  - **Impact**: This was an optional utility script, not part of core workflow
  - **Alternative**: 
    ```bash
    # List KMS keys
    aws kms list-keys --region ap-northeast-2
    
    # Describe specific key
    aws kms describe-key --key-id <key-id>
    
    # Schedule deletion (use Console for safety)
    # Navigate to: https://console.aws.amazon.com/kms
    ```

- **setup-github-actions-role.sh** (51 lines)
  - **Reason**: Infrastructure as Code (Terraform) preferred over imperative scripts
  - **Migration**: Use Terraform for IAM role management
  - **Impact**: Script was used for initial setup, now replaced by declarative approach
  - **Alternative**: 
    - Follow [GitHub Actions Setup Guide](./github_actions_setup.md)
    - Reference Terraform configurations in `terraform/atlantis/` or archived configs
    - Use AWS OIDC provider setup via Terraform

- **update-iam-policy.sh** (18 lines)
  - **Reason**: CI/CD automation replaces manual policy updates
  - **Migration**: IAM policies now managed via GitHub Actions workflows
  - **Impact**: Manual updates no longer needed
  - **Alternative**: 
    - IAM policies automatically updated by `.github/workflows/terraform-apply-and-deploy.yml`
    - For manual updates: Use AWS Console or `aws iam` CLI commands
    - For Terraform-managed policies: Update .tf files and apply

### Migration Guide for Deleted Scripts

#### For Teams Previously Using These Scripts

1. **KMS Key Management** (replaced `cleanup-kms.sh`)
   - **Recommended**: Use AWS KMS Console for visual confirmation before deletion
   - **Console**: https://console.aws.amazon.com/kms
   - **CLI Alternative**:
     ```bash
     # List all KMS keys
     aws kms list-keys --region ap-northeast-2
     
     # Get key details
     aws kms describe-key --key-id alias/your-key-name
     
     # List key grants
     aws kms list-grants --key-id <key-id>
     
     # Schedule deletion (30-day waiting period)
     aws kms schedule-key-deletion \
       --key-id <key-id> \
       --pending-window-in-days 30
     ```

2. **GitHub Actions IAM Setup** (replaced `setup-github-actions-role.sh`)
   - **Recommended**: Use Terraform for reproducible infrastructure
   - **Documentation**: [docs/github_actions_setup.md](./github_actions_setup.md)
   - **Terraform Example**:
     ```hcl
     # Create OIDC provider for GitHub Actions
     resource "aws_iam_openid_connect_provider" "github" {
       url = "https://token.actions.githubusercontent.com"
       client_id_list = ["sts.amazonaws.com"]
       thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
     }
     
     # Create IAM role for GitHub Actions
     resource "aws_iam_role" "github_actions" {
       name = "GitHubActionsRole"
       # ... (see archived configs for full example)
     }
     ```

3. **IAM Policy Updates** (replaced `update-iam-policy.sh`)
   - **Automated**: GitHub Actions workflows handle policy updates
   - **Manual Updates** (if needed):
     ```bash
     # Update inline policy
     aws iam put-role-policy \
       --role-name YourRoleName \
       --policy-name YourPolicyName \
       --policy-document file://policy.json
     
     # Attach managed policy
     aws iam attach-role-policy \
       --role-name YourRoleName \
       --policy-arn arn:aws:iam::aws:policy/YourPolicy
     ```

### Breaking Changes

**None** - All removed scripts were optional utilities, not required for core infrastructure operations.

Existing workflows continue to function:
- ✅ Terraform apply/destroy workflows unchanged
- ✅ GitHub Actions CI/CD unchanged
- ✅ Infrastructure governance unchanged

---

## [Previous Releases]

### Initial Project Setup
- ECR repository for Atlantis
- KMS encryption setup
- GitHub Actions workflows
- Governance validation scripts
- Common tags module
- CloudWatch log group module

---

## Migration Timeline

| Date | Change | Status |
|------|--------|--------|
| 2025-10-14 | Remove utility scripts | ✅ Complete |
| 2025-10-14 | Archive inactive configs | ✅ Complete |
| 2025-10-14 | Add module documentation | ✅ Complete |
| 2025-10-14 | Fix Terraform naming | ✅ Complete |

---

## Questions or Issues?

- **Jira Epic**: [IN-121 - Module Directory Structure Design](https://ryuqqq.atlassian.net/browse/IN-121)
- **Documentation**: [docs/](.) directory
- **Team**: Infrastructure Team

---

**Note**: For detailed module-specific changes, see individual module CHANGELOG.md files in `terraform/modules/{module-name}/`.
