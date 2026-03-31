module "talos" {
  source  = "bbtechsys/talos/proxmox"
  version = "0.1.5"

  talos_cluster_name = var.talos_cluster_name
  talos_version      = var.talos_version
  control_nodes      = var.control_nodes
  worker_nodes       = var.worker_nodes
}

output "talos_config" {
    description = "Talos configuration file"
    value       = module.talos.talos_config
    sensitive   = true
}

output "kubeconfig" {
    description = "Kubeconfig file"
    value       = module.talos.kubeconfig
    sensitive   = true
}
