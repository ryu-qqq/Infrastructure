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

# Install terraform versions (optional - can use tfenv or similar)
# Atlantis comes with terraform pre-installed

# Switch back to atlantis user for security
USER atlantis

# Copy server-side repository configuration
COPY --chown=atlantis:atlantis terraform/atlantis/repos.yaml /home/atlantis/repos.yaml

# Set working directory
WORKDIR /home/atlantis

# Expose Atlantis server port
EXPOSE 4141

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:4141/healthz || exit 1

# Use the default Atlantis entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]
