# Talos Kubernetes on Proxmox with Terraform

[![GitLab](https://img.shields.io/badge/gitlab-stetter--homelab%2Ftalos--terraform--poc-orange?logo=gitlab)](https://gitlab.com/stetter-homelab/talos-terraform-poc)

This project deploys a Talos Linux Kubernetes cluster on Proxmox VE using Terraform with GitLab CI/CD automation. It follows the guide from [BBTech Systems](https://bbtechsystems.com/blog/k8s-with-pxe-tf) but uses API token authentication and secure GitLab CI/CD for deployment automation.

## Prerequisites

- Proxmox VE cluster
- Devbox installed ([installation guide](https://www.jetify.com/docs/devbox))
- SSH access to Proxmox nodes

## Quick Start

1. **Enter the development environment:**
   ```bash
   devbox shell
   ```

2. **Copy and configure variables:**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Set up Proxmox permissions** (see [API Token Setup](#api-token-setup) below)

4. **Initialize and deploy:**
   ```bash
   devbox run init   # Initialize Terraform
   devbox run plan   # Review the deployment plan
   devbox run apply  # Deploy the cluster
   ```

5. **Get cluster credentials:**
   ```bash
   # Save the talosconfig
   terraform output -raw talos_config > ../talosconfig

   # Save the kubeconfig
   terraform output -raw kubeconfig > ../kubeconfig

   # Set environment variables
   export TALOSCONFIG=../talosconfig
   export KUBECONFIG=../kubeconfig
   ```

## API Token Setup

### Automated Setup (Recommended)

Run the setup script on your Proxmox server to automatically create the user, role, and API token:

```bash
# On your Proxmox server
curl -fsSL https://gitlab.com/stetter-homelab/talos-terraform-poc/-/raw/main/scripts/setup-proxmox-permissions.sh | bash

# Or clone the repo and run locally
git clone https://gitlab.com/stetter-homelab/talos-terraform-poc.git
cd talos-terraform-poc
chmod +x scripts/setup-proxmox-permissions.sh
./scripts/setup-proxmox-permissions.sh
```

The script will:
- Create user `terraform@pve`
- Create role `TerraformTalos` with all required permissions
- Create API token `terraform@pve!talos-token`
- Assign permissions at root level (`/`)
- Display the token for your configuration

### Manual Setup (Alternative)

If you prefer manual setup via the web UI:

1. **Create User**: `terraform@pve`
2. **Create Role**: `TerraformTalos` with these permissions:
   ```
   Datastore.AllocateSpace, Datastore.AllocateTemplate, Datastore.Audit,
   Pool.Allocate, SDN.Use, Sys.Audit, Sys.Console, Sys.Modify,
   VM.Allocate, VM.Audit, VM.Clone, VM.Config.CDROM, VM.Config.CPU,
   VM.Config.Cloudinit, VM.Config.Disk, VM.Config.HWType,
   VM.Config.Memory, VM.Config.Network, VM.Config.Options,
   VM.Console, VM.Migrate, VM.Monitor, VM.PowerMgmt
   ```
3. **Create API Token**: With privilege separation disabled
4. **Assign Role**: At root level (`/`)

### Configure Authentication

Update `terraform.tfvars` with your API token:
```hcl
proxmox_api_token = "terraform@pve!talos-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## Configuration Files

### terraform.tfvars (Main Configuration)

Copy from `terraform.tfvars.example` and configure:
- `proxmox_endpoint`: Your Proxmox URL
- `proxmox_api_token`: API token from setup above
- Node mappings in `control_nodes` and `worker_nodes`
- Network settings (`cluster_vip`, subnets)
- VM resource allocations

### Environment Variables (Alternative)

You can also use environment variables instead of tfvars:
```bash
cp .env.example .env
# Edit .env with your values
source .env
```

## Available Commands

The project includes convenient scripts via devbox:

```bash
devbox run init      # Initialize Terraform
devbox run plan      # Plan deployment
devbox run apply     # Apply changes
devbox run destroy   # Destroy infrastructure
devbox run k8s-status    # Check cluster status
devbox run talos-config  # Show talosctl config
```

## Cluster Access

After deployment, you'll have:

- **talosconfig**: Talos Linux cluster configuration
- **kubeconfig**: Kubernetes cluster configuration

Use these to manage your cluster:

```bash
# Set environment variables
export TALOSCONFIG=./talosconfig
export KUBECONFIG=./kubeconfig

# Check cluster status
talosctl health
kubectl get nodes
kubectl get pods --all-namespaces
```

## Customization

### Node Configuration

Modify the node maps in `terraform.tfvars`:

```hcl
# Control plane nodes
control_nodes = {
  "control-0" = "pve1"    # Node name = Proxmox host
  "control-1" = "pve2"
  "control-2" = "pve3"
}

# Worker nodes
worker_nodes = {
  "worker-0" = "pve1"
  "worker-1" = "pve2"
  "worker-2" = "pve3"
}
```

### Resource Allocation

Adjust VM resources in `terraform.tfvars`:

```hcl
vm_cpu_cores = 4          # CPU cores per VM
vm_memory_mb = 8192       # Memory in MB per VM
vm_disk_size = "50G"      # Disk size per VM
```

### Network Settings

Configure cluster networking:

```hcl
cluster_vip    = "10.0.0.100"     # VIP for API server
service_subnet = "10.96.0.0/12"   # Kubernetes services
pod_subnet     = "10.244.0.0/16"  # Kubernetes pods
```

## GitLab CI/CD Automation

This project includes secure GitLab CI/CD pipelines for automated deployment:

### Pipeline Overview
- **Development**: Automatic Terraform planning on merge requests
- **Production**: Manual approval required for production deployments  
- **Security**: External fork merge requests require approval before pipeline execution

### Environments
- **Dev Environment**: `talos-dev` @ 192.168.1.181 (1 control + 2 workers)
- **Prod Environment**: `talos-prod` @ 192.168.1.180 (2 control + 3 workers)

### Setup GitLab CI/CD
See [GitLab CI/CD Setup Guide](docs/gitlab-ci-setup.md) for complete instructions.

## Management Scripts

The project includes utility scripts for managing Proxmox permissions:

### Setup Script
Automatically configures Proxmox permissions for Terraform:
```bash
./scripts/setup-proxmox-permissions.sh
```

Creates:
- User: `terraform@pve`
- Role: `TerraformTalos` with required permissions
- API token: `terraform@pve!talos-token`
- Root-level ACL assignment

### Cleanup Script
Removes all Terraform-related permissions:
```bash
./scripts/cleanup-proxmox-permissions.sh
```

Removes:
- API tokens
- User account  
- Role (if not used elsewhere)
- ACL assignments

Both scripts include safety checks and colored output for easy troubleshooting.

## Troubleshooting

### Common Issues

1. **API Token Authentication Failed**
   - Verify token format: `user@realm!tokenid=secret`
   - Check token permissions in Proxmox
   - Ensure Privilege Separation is disabled

2. **SSH Connection Issues**
   - Verify `proxmox_ssh_username` is correct
   - Ensure SSH key is loaded in ssh-agent: `ssh-add`
   - Test SSH connection: `ssh root@your-proxmox-host`

3. **Module Not Found**
   - Run `devbox run init` to download the Terraform module
   - Check internet connectivity from your machine

### Debug Mode

Enable debug logging:
```bash
export TF_LOG=DEBUG
devbox run plan
```

## Security Notes

- **Never commit** `terraform.tfvars` or `.env` files to git
- Store API tokens securely (1Password, etc.)
- Use least-privilege access for API tokens
- Regularly rotate API tokens

## Module Information

This project uses the [bbtechsys/talos/proxmox](https://registry.terraform.io/modules/bbtechsys/talos/proxmox) Terraform module version 0.1.5.

For more information, see the [original guide](https://bbtechsystems.com/blog/k8s-with-pxe-tf) from BBTech Systems.