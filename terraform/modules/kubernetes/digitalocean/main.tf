# terraform/modules/kubernetes/digitalocean/main.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
  }
}

# Data source for available Kubernetes versions
data "digitalocean_kubernetes_versions" "available" {
  version_prefix = var.kubernetes_version_prefix
}

# Create VPC if requested
resource "digitalocean_vpc" "cluster_vpc" {
  count = var.create_vpc ? 1 : 0
  
  name     = "${var.cluster_name}-vpc"
  region   = var.region
  ip_range = var.vpc_ip_range
  
  description = "VPC for ${var.cluster_name} Kubernetes cluster"
}

# Create the Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  version = var.kubernetes_version != null ? var.kubernetes_version : data.digitalocean_kubernetes_versions.available.latest_version
  
  vpc_uuid = var.create_vpc ? digitalocean_vpc.cluster_vpc[0].id : var.existing_vpc_id
  
  # Cluster configuration
  auto_upgrade = var.auto_upgrade
  surge_upgrade = var.surge_upgrade
  ha           = var.enable_ha
  
  # Maintenance window
  maintenance_policy {
    start_time = var.maintenance_window.start_time
    day        = var.maintenance_window.day
  }

  # Default node pool
  node_pool {
    name       = var.default_node_pool.name
    size       = var.default_node_pool.size
    node_count = var.default_node_pool.auto_scale ? null : var.default_node_pool.node_count
    auto_scale = var.default_node_pool.auto_scale
    min_nodes  = var.default_node_pool.auto_scale ? var.default_node_pool.min_nodes : null
    max_nodes  = var.default_node_pool.auto_scale ? var.default_node_pool.max_nodes : null
    
    labels = merge(
      var.common_node_labels,
      var.default_node_pool.labels,
      {
        "node-pool" = var.default_node_pool.name
        "cluster"   = var.cluster_name
      }
    )
    
    dynamic "taint" {
      for_each = var.default_node_pool.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  tags = concat(
    var.cluster_tags,
    [
      "kubernetes",
      "managed-by-terraform",
      var.environment,
      var.cluster_name
    ]
  )
}

# Additional node pools
resource "digitalocean_kubernetes_node_pool" "additional" {
  for_each = var.additional_node_pools

  cluster_id = digitalocean_kubernetes_cluster.main.id
  name       = each.key
  size       = each.value.size
  node_count = each.value.auto_scale ? null : each.value.node_count
  auto_scale = each.value.auto_scale
  min_nodes  = each.value.auto_scale ? each.value.min_nodes : null
  max_nodes  = each.value.auto_scale ? each.value.max_nodes : null
  
  labels = merge(
    var.common_node_labels,
    each.value.labels,
    {
      "node-pool" = each.key
      "cluster"   = var.cluster_name
    }
  )
  
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  tags = concat(
    var.cluster_tags,
    each.value.tags,
    [each.key, "additional-pool"]
  )
}

# Write kubeconfig for CI/CD
resource "local_file" "kubeconfig" {
  count = var.create_output_files ? 1 : 0
  
  content  = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  filename = "${path.module}/../../../outputs/kubeconfig-${var.cluster_name}"
  
  depends_on = [digitalocean_kubernetes_cluster.main]
}