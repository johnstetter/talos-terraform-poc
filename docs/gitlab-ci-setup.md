# GitLab CI/CD Setup Guide

This guide covers setting up GitLab CI/CD for deploying Talos clusters to local Proxmox infrastructure with enhanced security for public repositories.

## Overview

The CI/CD pipeline supports two environments:
- **Development**: Single control + 2 workers for testing (`talos-dev` @ 192.168.1.181)
- **Production**: 2 control + 3 workers for production workloads (`talos-prod` @ 192.168.1.180)

## Security Advantages over GitHub Actions

GitLab provides superior security for public repositories with self-hosted runners:

- ✅ **Fork MR pipelines disabled by default** for external contributors
- ✅ **Manual approval required** for external merge request pipelines  
- ✅ **Granular runner access control** - restrict to specific users/groups
- ✅ **Protected environments** with deployment approvals
- ✅ **Repository remains public** for co-worker collaboration

## Architecture

```
GitLab CI/CD (Cloud)
    ↓ triggers
Self-Hosted GitLab Runner (core.rsdn.io)
    ↓ local API calls
Proxmox VE (core.rsdn.io:8006)
    ↓ VM creation
Talos VMs (192.168.1.x)
```

## Setup Steps

### 1. Create GitLab Repository

Create repository at: **gitlab.com/stetter-homelab/talos-terraform-poc**

### 2. Install Self-Hosted Runner

Run on **core.rsdn.io** as root:

```bash
# Clone the repository
git clone https://gitlab.com/stetter-homelab/talos-terraform-poc.git
cd talos-terraform-poc

# Run the setup script
sudo ./scripts/setup-gitlab-runner.sh
```

This creates:
- Dedicated `gitlab-runner` user account
- Secured runner installation with systemd hardening
- SSH key setup for Terraform operations
- Devbox environment for the runner

### 3. Register Runner with GitLab

Get registration token from: **GitLab Project Settings → CI/CD → Runners**

```bash
# Register runner (as root)
sudo gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token YOUR_REGISTRATION_TOKEN \
  --name core-runner \
  --tag-list homelab,linux,proxmox \
  --executor shell \
  --shell bash

# Start runner service
systemctl enable gitlab-runner
systemctl start gitlab-runner
```

### 4. Configure GitLab Variables

Add these variables in **Project Settings → CI/CD → Variables**:

| Variable Name | Value | Scope | Masked | Protected |
|---------------|--------|--------|---------|-----------|
| `PROXMOX_API_TOKEN` | `terraform@pve!terraform=SECRET` | All | ✅ | ✅ |
| `TF_VAR_proxmox_endpoint` | `https://192.168.1.5:8006/` | All | ❌ | ❌ |

### 5. Configure Security Settings

#### Protected Branches
- **Project Settings → Repository → Protected Branches**
- Protect `main` branch with push/merge restrictions

#### Environment Protection  
- **Project Settings → CI/CD → Environments**
- Add `production` environment with:
  - **Protected**: ✅ (Maintainers only)
  - **Required approvals**: ✅ (Manual gate)

#### External MR Pipeline Control
- **Project Settings → CI/CD → General pipelines**
- Set **Fork pipelines** to: "Run pipelines in the parent project" (manual approval)

## Workflow Overview

### Merge Request Workflow (`.gitlab-ci.yml`)
- **Trigger**: MR with terraform changes
- **Stage**: `plan-dev` 
- **Actions**: Plan dev environment deployment
- **Security**: Internal MRs run automatically, external MRs require approval
- **Output**: Terraform plan artifact and MR comment

### Main Branch Workflow
- **Trigger**: Push to main with terraform changes
- **Stages**: 
  1. `plan-prod` - Plan production deployment
  2. `deploy-prod` - **Manual approval required** → Deploy cluster
- **Actions**: Deploy, validate health, upload credentials

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
| **Deployment** | Automatic on MR | Manual approval required |

## Security Features

- **Dedicated user account** (`gitlab-runner`) with restricted permissions
- **SSH key isolation** for Terraform operations  
- **Systemd security hardening** with filesystem restrictions
- **Fork MR protection** - external contributions require approval
- **Environment gating** - production requires manual approval
- **Variable masking** - API tokens hidden in logs
- **Network isolation** - runner only accessible from local network

## Pipeline Configuration

### Workflow Rules
```yaml
workflow:
  rules:
    # Internal MRs run automatically
    - if: $CI_PIPELINE_SOURCE == "merge_request_event" && $CI_MERGE_REQUEST_SOURCE_PROJECT_PATH == $CI_PROJECT_PATH
    # External MRs require manual approval  
    - if: $CI_PIPELINE_SOURCE == "merge_request_event" && $CI_MERGE_REQUEST_SOURCE_PROJECT_PATH != $CI_PROJECT_PATH
      when: manual
    # Main branch pushes run automatically
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### Runner Tags
Jobs run on runners with tags:
- `homelab` - Identifies homelab infrastructure
- `linux` - Linux-based runner
- `proxmox` - Access to Proxmox infrastructure

## Troubleshooting

### Check Runner Status
```bash
systemctl status gitlab-runner
gitlab-runner list
journalctl -u gitlab-runner -f
```

### SSH Key Issues
```bash
# Test SSH access as gitlab-runner user
sudo -u gitlab-runner ssh localhost "echo 'SSH working'"
```

### Runner Registration Issues
```bash
# Re-register runner
sudo gitlab-runner unregister --name core-runner
# Then re-run registration command
```

### Pipeline Debug
```bash
# Enable debug mode in GitLab variable
CI_DEBUG_TRACE = true
```

## Migration from GitHub Actions

Key differences for teams migrating from GitHub Actions:

| GitHub Actions | GitLab CI/CD |
|----------------|--------------|
| `.github/workflows/` | `.gitlab-ci.yml` |
| `runs-on: self-hosted` | `tags: [homelab]` |
| `environment:` | `environment:` (similar) |
| Secrets in repo settings | Variables in project settings |
| Manual approval via environment | `when: manual` in rules |

## Future Enhancements

- **GitOps integration** for dev → prod promotion
- **Slack notifications** for deployment status  
- **Automated testing** in dev environment
- **Performance metrics** collection
- **Disaster recovery** automation

## Security Best Practices

1. **Regular Updates**: Keep GitLab Runner updated
2. **Token Rotation**: Rotate API tokens quarterly
3. **Access Review**: Review runner access permissions monthly
4. **Audit Logging**: Monitor pipeline execution logs
5. **Network Segmentation**: Isolate runner network access
6. **Backup Strategy**: Backup runner configuration and SSH keys