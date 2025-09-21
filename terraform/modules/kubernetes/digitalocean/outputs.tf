# terraform/modules/kubernetes/digitalocean/outputs.tf

output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.main.name
}

output "cluster_urn" {
  description = "Uniform Resource Name (URN) of the cluster"
  value       = digitalocean_kubernetes_cluster.main.urn
}

output "endpoint" {
  description = "Kubernetes API server endpoint"
  value       = digitalocean_kubernetes_cluster.main.endpoint
}

output "version" {
  description = "Kubernetes version of the cluster"
  value       = digitalocean_kubernetes_cluster.main.version
}

output "region" {
  description = "Region where the cluster is deployed"
  value       = digitalocean_kubernetes_cluster.main.region
}

output "vpc_uuid" {
  description = "UUID of the VPC where the cluster is deployed"
  value       = digitalocean_kubernetes_cluster.main.vpc_uuid
}

output "status" {
  description = "Current status of the cluster"
  value       = digitalocean_kubernetes_cluster.main.status
}

output "ipv4_address" {
  description = "Public IPv4 address of the cluster's API server"
  value       = digitalocean_kubernetes_cluster.main.ipv4_address
}

output "kubeconfig" {
  description = "Complete kubeconfig file contents"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}

output "kube_config_host" {
  description = "Kubernetes API server host"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].host
}

output "kube_config_token" {
  description = "Kubernetes API server token"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].token
  sensitive   = true
}

output "kube_config_cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "default_node_pool" {
  description = "Default node pool information"
  value = {
    id         = digitalocean_kubernetes_cluster.main.node_pool[0].id
    name       = digitalocean_kubernetes_cluster.main.node_pool[0].name
    size       = digitalocean_kubernetes_cluster.main.node_pool[0].size
    node_count = digitalocean_kubernetes_cluster.main.node_pool[0].actual_node_count
    nodes      = digitalocean_kubernetes_cluster.main.node_pool[0].nodes
  }
}

output "additional_node_pools" {
  description = "Additional node pools information"
  value = {
    for k, v in digitalocean_kubernetes_node_pool.additional : k => {
      id         = v.id
      name       = v.name
      size       = v.size
      node_count = v.actual_node_count
      nodes      = v.nodes
    }
  }
}

output "vpc_info" {
  description = "VPC information (if created)"
  value = var.create_vpc ? {
    id       = digitalocean_vpc.cluster_vpc[0].id
    name     = digitalocean_vpc.cluster_vpc[0].name
    ip_range = digitalocean_vpc.cluster_vpc[0].ip_range
    urn      = digitalocean_vpc.cluster_vpc[0].urn
  } : null
}

# Outputs for CI/CD integration
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.main.name}"
}

output "connection_info" {
  description = "Connection information for external tools"
  value = {
    cluster_name = digitalocean_kubernetes_cluster.main.name
    region       = digitalocean_kubernetes_cluster.main.region
    endpoint     = digitalocean_kubernetes_cluster.main.endpoint
    provider     = "digitalocean"
  }

|