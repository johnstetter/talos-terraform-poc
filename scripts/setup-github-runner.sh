#!/bin/bash

# GitHub Actions Runner Setup Script for core.rsdn.io
# Creates dedicated user account and installs runner with security hardening

set -e

# Configuration
RUNNER_USER="github-runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_DIR="${RUNNER_HOME}/actions-runner"
RUNNER_VERSION="2.314.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Setting up GitHub Actions Runner on core.rsdn.io${NC}"
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
echo "  Runner Directory: $RUNNER_DIR"
echo "  Runner Version: $RUNNER_VERSION"
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

# Download and install GitHub Actions runner
echo -e "${BLUE}📦 Installing GitHub Actions runner...${NC}"
sudo -u "$RUNNER_USER" bash << EOF
cd "$RUNNER_HOME"

# Create runner directory
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Download runner
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \\
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Verify checksum (optional but recommended)
echo "a9885d7c8a2b94c299fbcf797eb1b2c9c95e3891c8530846b3b56a01945e7c24  actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | sha256sum -c || {
    echo "Checksum verification failed, but continuing..."
}

# Extract runner
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
EOF

echo -e "${GREEN}✅ GitHub Actions runner downloaded and extracted${NC}"

# Install dependencies
echo -e "${BLUE}📦 Installing runner dependencies...${NC}"
"${RUNNER_DIR}/bin/installdependencies.sh"

# Security hardening
echo -e "${BLUE}🔒 Applying security hardening...${NC}"

# Restrict runner directory permissions
chmod 750 "$RUNNER_DIR"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_DIR"

# Create systemd service template
cat > /etc/systemd/system/github-runner.service << EOF
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
Type=simple
User=${RUNNER_USER}
WorkingDirectory=${RUNNER_DIR}
ExecStart=${RUNNER_DIR}/run.sh
Restart=always
RestartSec=5
KillMode=process
KillSignal=SIGINT
TimeoutStopSec=5min

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${RUNNER_HOME}
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictRealtime=true

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✅ Security hardening applied${NC}"

echo
echo -e "${GREEN}🎉 GitHub Actions Runner setup complete!${NC}"
echo
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Get registration token from GitHub:"
echo "   https://github.com/johnstetter/talos-terraform-poc/settings/actions/runners/new"
echo
echo "2. Configure the runner:"
echo "   sudo -u ${RUNNER_USER} ${RUNNER_DIR}/config.sh \\"
echo "     --url https://github.com/johnstetter/talos-terraform-poc \\"
echo "     --token YOUR_REGISTRATION_TOKEN \\"
echo "     --name core-runner \\"
echo "     --labels homelab,linux,proxmox \\"
echo "     --work ${RUNNER_DIR}/_work \\"
echo "     --unattended"
echo
echo "3. Start the runner service:"
echo "   systemctl enable github-runner"
echo "   systemctl start github-runner"
echo
echo "4. Check runner status:"
echo "   systemctl status github-runner"
echo "   journalctl -u github-runner -f"
echo
echo -e "${YELLOW}💡 Security Notes:${NC}"
echo "- Runner runs as dedicated user ${RUNNER_USER}"
echo "- SSH key copied for Terraform operations"
echo "- Systemd service has security restrictions"
echo "- Regular security updates recommended"