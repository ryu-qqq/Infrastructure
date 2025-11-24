# Atlantis Terraform Automation Server
# Based on official Atlantis image with custom configurations

ARG ATLANTIS_VERSION=v0.28.1

FROM ghcr.io/runatlantis/atlantis:${ATLANTIS_VERSION}

# Install additional tools if needed
USER root

# Install AWS CLI for AWS operations
RUN apk add --no-cache \
    aws-cli \
    git \
    bash \
    curl

# Install conftest for OPA policy validation
ARG CONFTEST_VERSION=0.49.1
RUN curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
    | tar xz -C /tmp && \
    mv /tmp/conftest /usr/local/bin/ && \
    chmod +x /usr/local/bin/conftest && \
    conftest --version

# Install terraform versions (optional - can use tfenv or similar)
# Atlantis comes with terraform pre-installed

# Switch back to atlantis user for security
USER atlantis

# Set working directory
WORKDIR /home/atlantis

# Copy server-side repository configuration
# Force rebuild: 2025-10-13
COPY --chown=atlantis:atlantis terraform/atlantis/repos.yaml /home/atlantis/repos.yaml

# Verify file was copied
RUN ls -la /home/atlantis/repos.yaml && echo "repos.yaml successfully copied"

# Expose Atlantis server port
EXPOSE 4141

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:4141/healthz || exit 1

# Use the default Atlantis entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]
