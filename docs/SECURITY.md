# Security Guide - Sensitive Information Management

## 🔐 Overview

This document explains how to securely manage sensitive information (credentials, tokens, private keys) in this Terraform infrastructure project.

## ⚠️ Important: What NOT to Commit

**NEVER commit these to Git:**
- ❌ `*.tfvars` files (except `.auto.tfvars` with non-sensitive data)
- ❌ GitHub Personal Access Tokens (PAT)
- ❌ GitHub App Private Keys
- ❌ Webhook Secrets
- ❌ AWS Access/Secret Keys
- ❌ Database Passwords
- ❌ `.pem` or `.key` files
- ❌ `.env` files

**Already protected by `.gitignore`:**
```gitignore
*.tfvars          # All tfvars files
!*.auto.tfvars   # Except auto.tfvars (for non-sensitive config)
*.pem
*.key
.env
.env.local
```

## 🎯 Recommended Approach: Environment Variables

### Method 1: Local Development with Environment Variables

```bash
# Set environment variables (recommended for local development)
export TF_VAR_github_username="your-username"
export TF_VAR_github_token="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export TF_VAR_github_app_id="123456"
export TF_VAR_github_app_installation_id="12345678"
export TF_VAR_github_app_private_key="$(base64 < path/to/private-key.pem)"
export TF_VAR_github_webhook_secret="your-webhook-secret"

# Then run Terraform
cd terraform/atlantis
terraform plan
```

### Method 2: AWS Secrets Manager (Best for Production)

#### Step 1: Store secrets in AWS Secrets Manager

```bash
# Store GitHub token
aws secretsmanager create-secret \
  --name atlantis/github-token \
  --secret-string '{"token":"ghp_xxxxxxxxxxxx"}' \
  --region ap-northeast-2

# Store GitHub App private key
aws secretsmanager create-secret \
  --name atlantis/github-app-private-key \
  --secret-binary fileb://private-key.pem \
  --region ap-northeast-2

# Store webhook secret
aws secretsmanager create-secret \
  --name atlantis/webhook-secret \
  --secret-string '{"secret":"your-webhook-secret"}' \
  --region ap-northeast-2
```

#### Step 2: Reference in Terraform

```hcl
# terraform/atlantis/data.tf
data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "atlantis/github-token"
}

data "aws_secretsmanager_secret_version" "github_app_private_key" {
  secret_id = "atlantis/github-app-private-key"
}

data "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id = "atlantis/webhook-secret"
}

locals {
  github_token           = jsondecode(data.aws_secretsmanager_secret_version.github_token.secret_string)["token"]
  github_app_private_key = data.aws_secretsmanager_secret_version.github_app_private_key.secret_binary
  webhook_secret         = jsondecode(data.aws_secretsmanager_secret_version.webhook_secret.secret_string)["secret"]
}
```

### Method 3: Terraform Cloud/Enterprise Variables (CI/CD)

1. Go to Terraform Cloud workspace
2. Navigate to Variables
3. Add sensitive variables:
   - Mark as "Sensitive" ✅
   - Set as "Environment variable" or "Terraform variable"

## 🔧 GitHub Actions Integration

For CI/CD pipelines, use GitHub Secrets:

```yaml
# .github/workflows/terraform-apply.yml
env:
  AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
  TF_VAR_github_token: ${{ secrets.ATLANTIS_GITHUB_TOKEN }}
  TF_VAR_github_app_private_key: ${{ secrets.ATLANTIS_GITHUB_APP_KEY }}
```

## 📋 Setting Up for the First Time

### Step 1: Copy Template Files

```bash
# Copy terraform.tfvars.example to terraform.tfvars
cp terraform/atlantis/terraform.tfvars.example terraform/atlantis/terraform.tfvars
```

### Step 2: Fill in Non-Sensitive Values

Edit `terraform.tfvars` and fill in:
- ✅ Environment, region
- ✅ VPC ID, subnet IDs (not sensitive)
- ✅ Resource sizing (CPU, memory)

### Step 3: Choose Secret Management Method

**Option A: Environment Variables (Quick Start)**
```bash
# Create a .envrc file (DO NOT COMMIT!)
cat > .envrc << 'ENVRC'
export TF_VAR_github_token="your-token-here"
export TF_VAR_github_app_id="123456"
export TF_VAR_github_app_installation_id="12345678"
export TF_VAR_github_app_private_key="base64-encoded-key"
export TF_VAR_github_webhook_secret="webhook-secret"
ENVRC

# Load environment
source .envrc
```

**Option B: AWS Secrets Manager (Production)**
Follow "Method 2" instructions above.

## 🚨 What to Do If Secrets Were Exposed

### 1. Immediately Revoke Exposed Credentials

**GitHub Personal Access Token:**
1. Go to https://github.com/settings/tokens
2. Find the exposed token
3. Click "Delete" immediately
4. Generate a new token

**GitHub App Private Key:**
1. Go to https://github.com/settings/apps
2. Select your app
3. Generate new private key
4. Revoke the old key

**Webhook Secret:**
1. Go to https://github.com/settings/apps
2. Update webhook secret
3. Update in your infrastructure

### 2. Remove from Git History (if committed)

```bash
# WARNING: This rewrites git history!
# Make sure team is aware before doing this.

# Using BFG Repo-Cleaner (recommended)
brew install bfg
bfg --delete-files terraform.tfvars .
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force
```

### 3. Rotate All Related Secrets

Even if you remove from git history, assume the secret is compromised:
- Rotate GitHub tokens
- Regenerate webhook secrets
- Update AWS Secrets Manager

## ✅ Security Checklist

Before committing:
- [ ] Run `git status` - ensure no `*.tfvars` files are staged
- [ ] Run `git diff --cached` - verify no secrets in staged changes
- [ ] Verify `.gitignore` includes sensitive patterns
- [ ] Check that only `.auto.tfvars` with non-sensitive data are committed

Before deploying to production:
- [ ] All secrets stored in AWS Secrets Manager or environment variables
- [ ] No hardcoded credentials in any `.tf` files
- [ ] GitHub tokens have minimum required permissions
- [ ] Webhook secrets are strong (64+ characters)
- [ ] Access restricted by IP/VPC where possible

## 📚 Additional Resources

- [Terraform Variable Files Best Practices](https://developer.hashicorp.com/terraform/language/values/variables#variable-files)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [GitHub Apps Authentication](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app)

## 🆘 Need Help?

If you accidentally committed sensitive information:
1. **Stop immediately** - don't push to remote
2. Follow "What to Do If Secrets Were Exposed" section above
3. Notify security team if already pushed to remote

---

**Last Updated**: 2025-10-24
