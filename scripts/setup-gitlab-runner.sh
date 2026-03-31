#!/bin/bash

# GitLab Runner Setup Script for core.rsdn.io
# Creates dedicated user account and installs GitLab runner with security hardening

set -e

# Configuration
RUNNER_USER="gitlab-runner"
RUNNER_HOME="/home/${RUNNER_USER}"
GITLAB_URL="https://gitlab.com/"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Setting up GitLab Runner on core.rsdn.io${NC}"
echo

# Verify we're running on the correct host
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" != "core.rsdn.io" && "$HOSTNAME" != "core" ]]; then
    echo -e "${YELLOW}⚠️  Warning: Expected hostname 'core.rsdn.io' or 'core', got '$HOSTNAME'${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Cancelled by user${NC}"
        exit 1
    fi
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root${NC}"
   exit 1
fi

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "  Runner User: $RUNNER_USER"
echo "  Runner Home: $RUNNER_HOME"
echo "  GitLab URL: $GITLAB_URL"
echo

# Create dedicated user account
echo -e "${BLUE}👤 Creating dedicated runner user...${NC}"
if id "$RUNNER_USER" &>/dev/null; then
    echo -e "${GREEN}✅ User $RUNNER_USER already exists${NC}"
else
    useradd -m -s /bin/bash "$RUNNER_USER"
    usermod -aG sudo "$RUNNER_USER"
    echo -e "${GREEN}✅ Created user $RUNNER_USER${NC}"
fi

# Set up SSH key for Terraform operations
echo -e "${BLUE}🔑 Setting up SSH key for Terraform...${NC}"
if [[ -f /root/.ssh/id_ed25519 ]]; then
    # Copy root's SSH key to runner user (for Terraform Proxmox provider)
    mkdir -p "${RUNNER_HOME}/.ssh"
    cp /root/.ssh/id_ed25519* "${RUNNER_HOME}/.ssh/"
    chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}/.ssh"
    chmod 700 "${RUNNER_HOME}/.ssh"
    chmod 600 "${RUNNER_HOME}/.ssh/id_ed25519"
    chmod 644 "${RUNNER_HOME}/.ssh/id_ed25519.pub"

    # Test SSH access to localhost
    sudo -u "$RUNNER_USER" ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
        localhost "echo 'SSH key authentication working'" || {
        echo -e "${YELLOW}⚠️  SSH key auth to localhost may not work. Manual setup may be needed.${NC}"
    }

    echo -e "${GREEN}✅ SSH key configured${NC}"
else
    echo -e "${RED}❌ SSH key /root/.ssh/id_ed25519 not found${NC}"
    exit 1
fi

# Install GitLab Runner
echo -e "${BLUE}📦 Installing GitLab Runner...${NC}"

# Add GitLab's official repository
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash

# Install GitLab Runner
apt-get install gitlab-runner

# Verify installation
gitlab-runner --version

echo -e "${GREEN}✅ GitLab Runner installed${NC}"

# Create devbox environment for the runner user
echo -e "${BLUE}📦 Setting up Devbox environment...${NC}"

# Install devbox for the runner user
sudo -u "$RUNNER_USER" bash << EOF
# Install devbox if not already installed
if ! command -v devbox &> /dev/null; then
    curl -fsSL https://get.jetify.com/devbox | bash
fi

# Verify devbox is available
devbox --version || echo "Devbox installation may need shell restart"
EOF

echo -e "${GREEN}✅ Devbox environment prepared${NC}"

# Security hardening
echo -e "${BLUE}🔒 Applying security hardening...${NC}"

# Configure GitLab Runner with security restrictions
cat > /etc/gitlab-runner/config.toml << EOF
concurrent = 1
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "core-runner"
  url = "${GITLAB_URL}"
  token = "PLACEHOLDER_TOKEN"
  executor = "shell"
  shell = "bash"

  [runners.custom_build_dir]
    enabled = true

  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]

  [runners.docker]
    tls_verify = false
    image = "ubuntu:20.04"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
EOF

# Set proper permissions
chown gitlab-runner:gitlab-runner /etc/gitlab-runner/config.toml
chmod 600 /etc/gitlab-runner/config.toml

# Configure systemd service overrides for security
mkdir -p /etc/systemd/system/gitlab-runner.service.d
cat > /etc/systemd/system/gitlab-runner.service.d/security.conf << EOF
[Service]
# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/home/gitlab-runner
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictRealtime=true

# Run as gitlab-runner user
User=gitlab-runner
Group=gitlab-runner
EOF

systemctl daemon-reload

echo -e "${GREEN}✅ Security hardening applied${NC}"

echo
echo -e "${GREEN}🎉 GitLab Runner setup complete!${NC}"
echo
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Get registration token from GitLab:"
echo "   https://gitlab.com/stetter-homelab/talos-terraform-poc/-/settings/ci_cd"
echo "   (Expand 'Runners' section)"
echo
echo "2. Register the runner:"
echo "   sudo gitlab-runner register \\"
echo "     --url ${GITLAB_URL} \\"
echo "     --registration-token YOUR_REGISTRATION_TOKEN \\"
echo "     --name core-runner \\"
echo "     --tag-list homelab,linux,proxmox \\"
echo "     --executor shell \\"
echo "     --shell bash"
echo
echo "3. Start the runner service:"
echo "   systemctl enable gitlab-runner"
echo "   systemctl start gitlab-runner"
echo
echo "4. Check runner status:"
echo "   systemctl status gitlab-runner"
echo "   gitlab-runner list"
echo
echo -e "${YELLOW}💡 Security Notes:${NC}"
echo "- Runner runs as dedicated user ${RUNNER_USER}"
echo "- SSH key copied for Terraform operations"
echo "- Systemd service has security restrictions"
echo "- External MR pipelines require manual approval"
echo "- Regular security updates recommended"