# Archived Terraform Configurations

This directory contains Terraform configurations that are no longer actively maintained but are preserved for historical reference and state file preservation.

## 📁 Contents

### `atlantis-iam/`
**Status**: Archived (2025-10-14)  
**Original Purpose**: Atlantis server IAM role and policy configuration  
**Current State**: Contains only Terraform state files  

- Terraform code files (.tf) have been removed
- State files preserved for resource tracking
- See [atlantis-iam/README.md](./atlantis-iam/README.md) for details

**Migration Path**: IAM configurations now managed via:
- Primary approach: Terraform in active directories
- GitHub Actions: `.github/workflows/`

---

### `bootstrap/`
**Status**: Archived (2025-10-14)  
**Original Purpose**: Infrastructure bootstrap configuration (S3 backend, DynamoDB, initial setup)  
**Current State**: Contains only Terraform lock file  

- No state files present
- Resources likely migrated or manually managed
- See [bootstrap/README.md](./bootstrap/README.md) for details

**Migration Path**: Bootstrap operations now handled by:
- Manual AWS Console setup
- Or dedicated bootstrap Terraform project (if recreated)

---

## 📋 Archive Policy

### What's Here
- **State Files**: Preserved for AWS resource tracking
- **Lock Files**: Terraform provider version constraints
- **Documentation**: Original README files explaining historical context

### What to Do
- ✅ **Keep**: Do not delete or modify these directories
- ✅ **Reference**: Use for historical context or troubleshooting
- ❌ **Do Not Modify**: These are read-only archives
- ❌ **Do Not Run**: Do not execute `terraform apply/destroy` in these directories

### State File Safety
State files may contain:
- Resource identifiers (ARNs, IDs)
- Configuration snapshots
- **Note**: Sensitive values should be stored in AWS Secrets Manager, not state files

If you need to remove resources tracked by these state files:
1. Review state contents: `terraform state list`
2. Manually delete AWS resources via Console
3. Or use `terraform state rm` to untrack without deletion

---

## 🔗 Related Documentation

- [Infrastructure Governance](../../docs/infrastructure_governance.md)
- [GitHub Actions Setup](../../docs/github_actions_setup.md)
- [Terraform State Management](https://developer.hashicorp.com/terraform/language/state)

---

## 📞 Questions?

- **Team**: Infrastructure Team
- **Archived Date**: 2025-10-14

---

**⚠️ Important**: If you're looking for active Terraform configurations, see:
- `terraform/atlantis/` - Atlantis ECR and KMS
- `terraform/monitoring/` - Grafana, Prometheus, CloudWatch
- `terraform/modules/` - Reusable modules
