# Infrastructure Wizard 🔧

Automated Terraform code generator for company infrastructure standards.

## 📋 Overview

The Infrastructure Wizard helps you generate production-ready Terraform code by:
1. Asking guided questions about your infrastructure needs
2. Generating Terraform code from templates
3. Updating `atlantis.yaml` automatically
4. Creating a Pull Request with all changes

**No Terraform knowledge required!**

## 🚀 Quick Start

```bash
# Run the wizard
./wizard/infra-wizard.sh

# Or with Python directly
python3 wizard/infra-wizard.py
```

## 📦 Prerequisites

- Python 3.9 or later
- Git installed and configured
- GitHub CLI (`gh`) for PR creation (optional)

## 🎯 Features

### Supported Infrastructure

- ✅ **ECS Service** (Fargate)
  - With or without ALB
  - Shared or dedicated RDS database
  - Shared or dedicated ElastiCache
  - Optional S3 storage

### More templates coming soon:
- 🚧 Lambda Function
- 🚧 RDS Database (standalone)
- 🚧 ElastiCache (standalone)
- 🚧 S3 Bucket with lifecycle policies
- 🚧 SQS + SNS messaging pattern

## 📖 Usage Guide

### Step 1: Run the Wizard

```bash
./wizard/infra-wizard.sh
```

### Step 2: Answer Questions

The wizard will ask about:
- **Service name** (kebab-case: api-server, worker, etc.)
- **Environment** (dev, staging, prod)
- **Resources** (CPU, Memory)
- **Optional components** (database, cache, load balancer)

### Step 3: Review Summary

The wizard shows what will be created:
```
📊 생성 요약
─────────────────────────────────────
서비스: api-server
환경: prod
CPU: 512 units
메모리: 1024 MiB

선택된 컴포넌트:
├─ 데이터베이스: 기존 공유 RDS
├─ 캐시: 전용 Redis
└─ 로드밸런서: ALB

생성될 위치: terraform/services/api-server/
```

### Step 4: Wizard Generates

The wizard automatically:
1. ✅ Generates Terraform files
2. ✅ Updates `atlantis.yaml`
3. ✅ Creates Git branch
4. ✅ Commits changes
5. ✅ Creates PR

### Step 5: Review & Deploy

1. Open the PR link
2. Wait for Atlantis plan (1-2 minutes)
3. Review plan results in PR comment
4. Approve and merge
5. Atlantis applies automatically

## 📁 Generated Structure

```
terraform/services/api-server/
├── data.tf              # Shared infrastructure references
├── locals.tf            # Local variables and tags
├── main.tf              # ECS service, security groups
├── alb.tf               # ALB (if selected)
├── elasticache.tf       # Redis (if selected)
├── outputs.tf           # Service outputs
├── provider.tf          # Terraform backend config
└── README.md            # Service documentation
```

## 🔧 Development

### Project Structure

```
wizard/
├── infra-wizard.sh       # Shell wrapper (entry point)
├── infra-wizard.py       # Main CLI application
├── requirements.txt      # Python dependencies
├── .venv/                # Virtual environment (auto-created)
└── README.md             # This file
```

### Adding New Templates

1. Create template directory:
   ```bash
   mkdir -p terraform/templates/{template-name}
   ```

2. Create `metadata.json`:
   ```json
   {
     "module": "template-name",
     "version": "1.0.0",
     "description": "Template description",
     "required_parameters": [...],
     "optional_components": {...}
   }
   ```

3. Create Jinja2 templates (`.tf.j2` files)

4. Test with wizard

### Running in Development Mode

```bash
# With dry-run (no files created)
python3 wizard/infra-wizard.py --dry-run

# With specific template
python3 wizard/infra-wizard.py --template ecs-service

# With debug mode
python3 wizard/infra-wizard.py --debug
```

## 🔍 Troubleshooting

### Virtual Environment Issues

```bash
# Remove and recreate venv
rm -rf wizard/.venv
./wizard/infra-wizard.sh
```

### Python Version Issues

```bash
# Check Python version
python3 --version

# Must be 3.9 or later
```

### Template Not Found

```bash
# List available templates
ls terraform/templates/

# Check metadata.json exists
cat terraform/templates/ecs-service/metadata.json
```

## 📚 Related Documentation

- [atlantis.yaml Structure](../atlantis.yaml)
- [Template Development Guide](../terraform/templates/README.md) (TODO)
- [Infrastructure Governance](../docs/governance/)

## 🤝 Contributing

To add new features:
1. Create feature branch
2. Add templates and wizard logic
3. Test thoroughly
4. Create PR with examples

## 📝 License

Internal use only. Property of [Your Company].

---

**Version**: 1.0.0 (MVP)
**Last Updated**: 2025-10-24
**Maintainer**: Platform Team
