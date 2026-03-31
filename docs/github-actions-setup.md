# GitHub Actions Setup Guide

This guide covers setting up GitHub Actions CI/CD for deploying Talos clusters to local Proxmox infrastructure.

## Overview

The CI/CD pipeline supports two environments:
- **Development**: Single-node cluster for testing (`talos-dev` @ 192.168.1.181)
- **Production**: HA cluster for production workloads (`talos-prod` @ 192.168.1.180)

## Architecture

```
GitHub Actions (Cloud)
    ↓ triggers
Self-Hosted Runner (core.rsdn.io)
    ↓ local API calls
Proxmox VE (core.rsdn.io:8006)
    ↓ VM creation
Talos VMs (192.168.1.x)
```

## Setup Steps

### 1. Install Self-Hosted Runner

Run on **core.rsdn.io** as root:

```bash
# Clone the repository
git clone https://github.com/johnstetter/talos-terraform-poc.git
cd talos-terraform-poc

# Run the setup script
./scripts/setup-github-runner.sh
```

This creates:
- Dedicated `github-runner` user account
- Secured runner installation in `/home/github-runner/actions-runner`
- SSH key setup for Terraform operations
- Systemd service with security hardening

### 2. Register Runner with GitHub

Get registration token from: https://github.com/johnstetter/talos-terraform-poc/settings/actions/runners/new

```bash
# Configure runner (as github-runner user)
sudo -u github-runner /home/github-runner/actions-runner/config.sh \
  --url https://github.com/johnstetter/talos-terraform-poc \
  --token YOUR_REGISTRATION_TOKEN \
  --name core-runner \
  --labels homelab,linux,proxmox \
  --work /home/github-runner/actions-runner/_work

# Start runner service
systemctl enable github-runner
systemctl start github-runner
```

### 3. Configure GitHub Secrets

Add these secrets in GitHub repository settings:

| Secret Name | Value | Description |
|-------------|--------|-------------|
| `PROXMOX_API_TOKEN` | `terraform@pve!TOKEN_NAME=SECRET` | Proxmox API token for Terraform |

### 4. Configure GitHub Environments

Set up protection rules in GitHub:

#### Development Environment
- **Name**: `development`
- **Protection**: None (automatic deployment on PR)

#### Production Environment  
- **Name**: `production`
- **Protection**: Required reviewers (manual approval)
- **URL**: `https://192.168.1.180:6443`

## Workflow Overview

### Pull Request Workflow (`plan-dev.yml`)
- **Trigger**: PR to main with terraform changes
- **Actions**: Plan dev environment deployment
- **Output**: Terraform plan artifact and PR comment

### Main Branch Workflow (`deploy-prod.yml`)
- **Trigger**: Push to main with terraform changes
- **Actions**: 
  1. Plan production deployment
  2. **Wait for manual approval**
  3. Deploy production cluster
  4. Validate cluster health
  5. Upload cluster credentials

## Environment Differences

| Aspect | Development | Production |
|--------|-------------|------------|
| **Cluster Name** | talos-dev | talos-prod |
| **VIP Address** | 192.168.1.181 | 192.168.1.180 |
| **Control Nodes** | 1 | 2 |
| **Worker Nodes** | 2 | 3 |
| **CPU/Node** | 2 cores | 4 cores |
| **RAM/Node** | 4GB | 8GB |
| **Disk/Node** | 30GB | 50GB |
| **Deployment** | Automatic on PR | Manual approval required |

## Security Features

- **Dedicated user account** for runner isolation
- **SSH key isolation** from root account  
- **Systemd security** restrictions on runner service
- **Environment protection** with manual approvals
- **Secret management** through GitHub encrypted secrets
- **Network isolation** (runner only accessible from local network)

## Troubleshooting

### Check Runner Status
```bash
systemctl status github-runner
journalctl -u github-runner -f
```

### SSH Key Issues
```bash
# Test SSH access as runner user
sudo -u github-runner ssh localhost "echo 'SSH working'"
```

### Terraform Issues
```bash
# Check SSH agent
sudo -u github-runner bash -c 'eval $(ssh-agent); ssh-add -L'
```

### Clean Failed Deployment
```bash
# Use existing cleanup procedures
./scripts/cleanup-proxmox-permissions.sh  # If needed
./scripts/setup-proxmox-permissions.sh    # Recreate permissions
```

## Future Enhancements

- GitOps integration for promotion from dev to prod
- Slack notifications for deployment status
- Automated cluster health monitoring
- Disaster recovery automation