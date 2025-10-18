# Infrastructure Documentation

Welcome to the Infrastructure documentation hub. This directory contains all documentation organized by category.

## 📚 Documentation Structure

### 🏛️ [Governance](./governance/)
Infrastructure governance policies and standards
- [Infrastructure Governance](./governance/infrastructure_governance.md) - Required tags, KMS strategy, naming rules
- [Tagging Standards](./governance/TAGGING_STANDARDS.md) - AWS resource tagging requirements
- [Naming Convention](./governance/NAMING_CONVENTION.md) - Resource naming rules (kebab-case)
- [Logging Naming Convention](./governance/LOGGING_NAMING_CONVENTION.md) - CloudWatch Log Group naming standards
- [Infrastructure PR Workflow](./governance/infrastructure_pr.md) - PR process and gate checklist

### 📘 [Guides](./guides/)
Setup and operational guides

#### [Setup Guides](./guides/setup/)
- [GitHub Actions Setup](./guides/setup/github_actions_setup.md) - CI/CD configuration with GitHub Actions
- [Slack Setup Guide](./guides/setup/SLACK_SETUP_GUIDE.md) - AWS Chatbot and Slack integration
- [Jira Integration](./guides/setup/JIRA_INTEGRATION.md) - GitHub Issues to Jira sync

#### [Onboarding Guides](./guides/onboarding/)
- [Service Repository Onboarding](./guides/onboarding/SERVICE_REPO_ONBOARDING.md) - Complete guide for service teams to build infrastructure autonomously

#### [Operations Guides](./guides/operations/)
- [Logs Insights Queries](./guides/operations/LOGS_INSIGHTS_QUERIES.md) - CloudWatch Logs Insights query examples
- [Infrastructure Notion](./guides/operations/infrastructure_notion.md) - Notion integration details

### 🧩 [Modules](./modules/)
Terraform module development guides
- [Directory Structure](./modules/MODULES_DIRECTORY_STRUCTURE.md) - Standard module structure
- [Module Template](./modules/MODULE_TEMPLATE.md) - Documentation template for modules
- [Standards Guide](./modules/MODULE_STANDARDS_GUIDE.md) - Coding standards and conventions
- [Examples Guide](./modules/MODULE_EXAMPLES_GUIDE.md) - How to write example code
- [Versioning Guide](./modules/VERSIONING.md) - Semantic versioning for modules

### 🚨 [Runbooks](./runbooks/)
Operational runbooks for incident response
- [ECS High CPU](./runbooks/ecs-high-cpu.md) - High CPU usage response procedures
- [ECS Memory Critical](./runbooks/ecs-memory-critical.md) - Memory critical alert response
- [ECS Task Count Zero](./runbooks/ecs-task-count-zero.md) - Task failure response procedures

### 📝 [Changelogs](./changelogs/)
Change history and templates
- [Infrastructure Changelog](./changelogs/CHANGELOG_INFRASTRUCTURE.md) - Infrastructure changes history
- [Changelog Template](./changelogs/CHANGELOG_TEMPLATE.md) - Template for module changelogs

### 🇰🇷 [Korean Documentation](./ko/)
한글 문서 (Korean language documentation)
- [프로젝트 개요](./ko/PROJECT_OVERVIEW_KR.md) - Project overview in Korean
- [Terraform 모듈 가이드](./ko/TERRAFORM_MODULES_KR.md) - Terraform modules guide in Korean
- [스크립트 사용 가이드](./ko/SCRIPTS_GUIDE_KR.md) - Scripts guide in Korean

---

## 🚀 Quick Links

### For New Team Members
1. Start with [Service Repository Onboarding Guide](./guides/onboarding/SERVICE_REPO_ONBOARDING.md) - **NEW!**
2. Read [Project Overview (Korean)](./ko/PROJECT_OVERVIEW_KR.md) or main [README](../README.md)
3. Review [Infrastructure Governance](./governance/infrastructure_governance.md)
4. Set up [GitHub Actions](./guides/setup/github_actions_setup.md)
5. Install Git hooks: `./scripts/setup-hooks.sh`

### For Module Developers
1. Read [Module Standards Guide](./modules/MODULE_STANDARDS_GUIDE.md)
2. Use [Module Template](./modules/MODULE_TEMPLATE.md) for documentation
3. Follow [Directory Structure](./modules/MODULES_DIRECTORY_STRUCTURE.md)
4. Review [Examples Guide](./modules/MODULE_EXAMPLES_GUIDE.md)

### For Operations
1. Check [Runbooks](./runbooks/) for incident response
2. Use [Logs Insights Queries](./guides/operations/LOGS_INSIGHTS_QUERIES.md) for troubleshooting
3. Set up [Slack Alerts](./guides/setup/SLACK_SETUP_GUIDE.md)

### For Compliance
1. Review [Tagging Standards](./governance/TAGGING_STANDARDS.md)
2. Check [Naming Convention](./governance/NAMING_CONVENTION.md)
3. Understand [PR Workflow](./governance/infrastructure_pr.md)

---

## 📊 Document Categories

| Category | Files | Purpose |
|----------|-------|---------|
| Governance | 5 | Standards, policies, and conventions |
| Onboarding Guides | 1 | Service team onboarding and first PR tutorial |
| Setup Guides | 3 | Initial configuration and integration |
| Operations | 2 | Day-to-day operational guides |
| Modules | 5 | Module development guidelines |
| Runbooks | 3 | Incident response procedures |
| Changelogs | 2 | Change history tracking |
| Korean Docs | 3 | Korean language documentation |

**Total Documents**: 24 active documents

---

## 🔍 Finding Documentation

### By Task
- **Getting started with infrastructure**: → [Onboarding Guide](./guides/onboarding/SERVICE_REPO_ONBOARDING.md)
- **Creating new modules**: → [Modules](./modules/)
- **Responding to alerts**: → [Runbooks](./runbooks/)
- **Setting up CI/CD**: → [Setup Guides](./guides/setup/)
- **Checking standards**: → [Governance](./governance/)
- **Writing Korean docs**: → [Korean Documentation](./ko/)

### By Role
- **Platform Engineers**: Governance, Modules, Runbooks
- **DevOps Engineers**: Setup Guides, Operations, Runbooks
- **Developers**: Modules, Korean Docs
- **Compliance Officers**: Governance, Changelogs

---

## 📝 Contributing

When adding new documentation:
1. Place files in the appropriate category directory
2. Update this README.md with links
3. Follow naming conventions (UPPERCASE for standards, lowercase for guides)
4. Cross-reference related documents
5. Keep the Korean docs in sync where applicable

---

## 🏷️ Tags

`#infrastructure` `#terraform` `#aws` `#documentation` `#governance` `#modules`

Last updated: 2025-10-18
