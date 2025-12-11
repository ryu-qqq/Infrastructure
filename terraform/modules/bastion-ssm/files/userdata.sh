#!/bin/bash
set -e

# Update system packages
dnf update -y

# Install essential tools
dnf install -y \
  vim \
  git \
  htop \
  curl \
  wget \
  jq \
  unzip \
  tmux

# Install AWS CLI v2 (if not already installed)
if ! command -v aws &> /dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
fi

# Install Session Manager Plugin
dnf install -y https://s3.${region}.amazonaws.com/amazon-ssm-${region}/latest/linux_amd64/amazon-ssm-agent.rpm

# Enable and start SSM Agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Configure timezone
timedatectl set-timezone Asia/Seoul

# Set hostname
hostnamectl set-hostname ${environment}-bastion

# Create a message of the day
cat > /etc/motd << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   🔒 Bastion Host - Production Environment                    ║
║                                                                ║
║   ⚠️  WARNING: All sessions are logged and monitored          ║
║   📝 Session logs: CloudWatch Logs                            ║
║   🔐 Access: SSM Session Manager only                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

Environment: ${environment}
Region: ${region}
Access Method: AWS Systems Manager Session Manager

EOF

# Security hardening
# Disable password authentication (SSM only)
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

# Set up automatic security updates
dnf install -y dnf-automatic
systemctl enable --now dnf-automatic.timer

# Log completion
echo "Bastion host initialization completed at $(date)" >> /var/log/bastion-init.log
