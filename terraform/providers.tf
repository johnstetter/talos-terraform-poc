terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "~> 0.75.0"
    }
    talos = {
      source = "siderolabs/talos"
      version = "~> 0.7.1"
    }
  }

  # Use Terraform registry for modules (required for bbtechsys/talos/proxmox)
  required_version = ">= 1.0"
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  insecure  = var.proxmox_insecure

  # API Token authentication (preferred method)
  api_token = var.proxmox_api_token

  # SSH configuration for file operations
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
