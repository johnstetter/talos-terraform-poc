# Proxmox Configuration Variables

variable "proxmox_endpoint" {
  description = "The Proxmox VE API endpoint URL"
  type        = string
  default     = "https://192.168.1.5:8006/"
}

variable "proxmox_insecure" {
  description = "Whether to skip TLS verification for Proxmox API (useful for self-signed certificates)"
  type        = bool
  default     = true
}

variable "proxmox_api_token" {
  description = "Proxmox VE API token for authentication (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_ssh_username" {
  description = "SSH username for connecting to Proxmox nodes (required for file operations)"
  type        = string
  default     = "stetter"
}

# Talos Cluster Configuration Variables

variable "talos_cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "talos-homelab"
}

variable "talos_version" {
  description = "Version of Talos Linux to deploy"
  type        = string
  default     = "1.9.5"
}

variable "kubernetes_version" {
  description = "Version of Kubernetes to deploy"
  type        = string
  default     = "1.31.0"
}

# Node Configuration Variables

variable "control_nodes" {
  description = "Map of control plane node names to Proxmox node assignments"
  type        = map(string)
  default = {
    "control-0" = "pve1"
    "control-1" = "pve1"
    "control-2" = "pve1"
  }
}

variable "worker_nodes" {
  description = "Map of worker node names to Proxmox node assignments"
  type        = map(string)
  default = {
    "worker-0" = "pve1"
    "worker-1" = "pve1"
    "worker-2" = "pve1"
  }
}

# VM Configuration Variables

variable "vm_cpu_cores" {
  description = "Number of CPU cores for each VM"
  type        = number
  default     = 4
}

variable "vm_memory_mb" {
  description = "Amount of memory in MB for each VM"
  type        = number
  default     = 8192
}

variable "vm_disk_size" {
  description = "Disk size for each VM (e.g., '50G')"
  type        = string
  default     = "50G"
}

# Network Configuration Variables

variable "cluster_vip" {
  description = "Virtual IP address for the cluster API endpoint"
  type        = string
  default     = "10.0.0.100"
}

variable "cluster_domain" {
  description = "Cluster domain name"
  type        = string
  default     = "cluster.local"
}

variable "service_subnet" {
  description = "CIDR subnet for Kubernetes services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "pod_subnet" {
  description = "CIDR subnet for Kubernetes pods"
  type        = string
  default     = "10.244.0.0/16"
}