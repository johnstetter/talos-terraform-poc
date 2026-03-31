# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform project that deploys Talos Linux Kubernetes clusters on Proxmox VE infrastructure. It uses the `bbtechsys/talos/proxmox` Terraform module (v0.1.5) to automate the provisioning of control plane and worker nodes.

## Development Environment

The project uses **Devbox** for reproducible development environments. All tools are declared in `devbox.json`:

- `terraform` - Infrastructure as Code
- `kubectl` - Kubernetes CLI
- `talosctl` - Talos Linux CLI  
- `kubernetes-helm` - Helm package manager

### Environment Setup

```bash
# Enter development environment
devbox shell

# The shell will display available tools and load environment
```

## Common Development Tasks

### Devbox Scripts

The project includes predefined devbox scripts for all common operations:

```bash
# Terraform workflow
devbox run init      # Initialize Terraform (downloads modules, sets up backend)
devbox run plan      # Generate and review deployment plan
devbox run apply     # Deploy infrastructure
devbox run destroy   # Tear down infrastructure

# Cluster management  
devbox run k8s-status     # Check cluster health (kubectl cluster-info + get nodes)
devbox run talos-config   # Show current talosctl configuration
```

All terraform commands run from the `terraform/` directory automatically.

### Management Scripts

The project includes automation scripts in `scripts/`:

- **`setup-proxmox-permissions.sh`** - Automatically creates Proxmox user, role, and API token
- **`cleanup-proxmox-permissions.sh`** - Removes all Terraform-related permissions

These eliminate the need for manual UI-based permission setup.

## Configuration Architecture

The project supports two configuration approaches:

### 1. Terraform Variables (Recommended)
- Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` 
- Edit with your specific values
- This file is gitignored for security

### 2. Environment Variables (Alternative)
- Copy `.env.example` to `.env`
- Uses `TF_VAR_*` prefixed variables
- Source with `source .env` before terraform commands

### Key Configuration Areas

- **Proxmox Authentication**: API token (format: `user@realm!tokenid=secret`)
- **Node Mapping**: Control and worker nodes mapped to specific Proxmox hosts
- **Network Configuration**: VIP, service/pod subnets, cluster domain
- **Resource Allocation**: CPU, memory, and disk per VM
- **Versions**: Talos and Kubernetes versions

## Infrastructure Architecture

The Terraform module creates:

1. **Control Plane Nodes**: Mapped via `control_nodes` variable (node_name -> proxmox_host)
2. **Worker Nodes**: Mapped via `worker_nodes` variable (node_name -> proxmox_host)
3. **Cluster VIP**: High-availability API endpoint
4. **Network Configuration**: Pod and service subnets for Kubernetes networking

Node mapping example:
```hcl
control_nodes = {
  "control-0" = "pve1"    # Deploy control-0 to pve1 host
  "control-1" = "pve2"    # Deploy control-1 to pve2 host
  "control-2" = "pve3"    # Deploy control-2 to pve3 host  
}
```

## Post-Deployment Workflow

After successful `terraform apply`, cluster credentials are available as sensitive outputs:

```bash
# Save cluster credentials (run from terraform/ directory)
terraform output -raw talos_config > ../talosconfig
terraform output -raw kubeconfig > ../kubeconfig

# Set environment variables for cluster access
export TALOSCONFIG=../talosconfig
export KUBECONFIG=../kubeconfig

# Verify cluster
talosctl health
kubectl get nodes
```

## Security Considerations

- **Never commit** `terraform.tfvars`, `.env`, or credential files (all are gitignored)
- **API tokens** require specific Proxmox permissions (see README for full list)
- **Cluster credentials** are marked as sensitive in Terraform outputs
- **SSH agent** is used for Proxmox host authentication

## Provider Configuration

The project uses two main Terraform providers:

- **proxmox** (`bpg/proxmox` ~> 0.75.0): Proxmox VE API interactions
- **talos** (`siderolabs/talos` ~> 0.7.1): Talos Linux configuration

Provider authentication is handled via:
- API token for Proxmox operations
- SSH agent for file operations on Proxmox hosts

## Troubleshooting Context

Common failure points:
1. **API Token Issues**: Verify format and permissions in Proxmox
2. **SSH Connectivity**: Ensure SSH key is loaded and accessible to Proxmox hosts
3. **Module Downloads**: Run `devbox run init` if module not found
4. **Resource Conflicts**: Check Proxmox resource availability (CPU, memory, storage)

Debug mode: `export TF_LOG=DEBUG` before terraform commands.

## File Structure Context

- `main.tf`: Module declaration and outputs only
- `variables.tf`: All configurable parameters with defaults
- `providers.tf`: Provider requirements and configuration
- `terraform.tfvars.example`: Template for local configuration
- `.env.example`: Template for environment variable configuration

The actual infrastructure logic is in the external `bbtechsys/talos/proxmox` module.