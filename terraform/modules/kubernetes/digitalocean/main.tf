# terraform/modules/kubernetes/digitalocean/main.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# Data source for DigitalOcean Kubernetes versions
data "digitalocean_kubernetes_versions" "available" {
  version_prefix = var.kubernetes_version_prefix
}

# VPC for the cluster
resource "digitalocean_vpc" "k8s_vpc" {
  count = var.create_vpc ? 1 : 0
  
  name     = "${var.cluster_name}-vpc"
  region   = var.region
  ip_range = var.vpc_ip_range
}

# DigitalOcean Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  version = data.digitalocean_kubernetes_versions.available.latest_version
  
  vpc_uuid = var.create_vpc ? digitalocean_vpc.k8s_vpc[0].id : var.existing_vpc_id

  # Enable auto-upgrade and surge upgrades for better availability
  auto_upgrade = var.auto_upgrade
  surge_upgrade = var.surge_upgrade
  
  # Maintenance window
  maintenance_policy {
    start_time = var.maintenance_window.start_time
    day        = var.maintenance_window.day
  }

  # Main node pool
  node_pool {
    name       = "${var.cluster_name}-main-pool"
    size       = var.main_node_pool.size
    node_count = var.main_node_pool.node_count
    auto_scale = var.main_node_pool.auto_scale
    min_nodes  = var.main_node_pool.min_nodes
    max_nodes  = var.main_node_pool.max_nodes
    
    # Taints for main pool if needed
    dynamic "taint" {
      for_each = var.main_node_pool.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
    
    labels = merge(var.common_labels, var.main_node_pool.labels)
  }

  tags = var.cluster_tags
}

# Additional node pools
resource "digitalocean_kubernetes_node_pool" "additional" {
  for_each = var.additional_node_pools

  cluster_id = digitalocean_kubernetes_cluster.main.id
  name       = each.key
  size       = each.value.size
  node_count = each.value.node_count
  auto_scale = each.value.auto_scale
  min_nodes  = each.value.min_nodes
  max_nodes  = each.value.max_nodes
  
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  labels = merge(var.common_labels, each.value.labels)
  tags   = var.cluster_tags
}

# Configure Kubernetes provider
provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.main.endpoint
  token = digitalocean_kubernetes_cluster.main.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = digitalocean_kubernetes_cluster.main.endpoint
    token = digitalocean_kubernetes_cluster.main.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
    )
  }
}

# Install essential cluster components
module "monitoring" {
  count  = var.install_monitoring ? 1 : 0
  source = "../../common/monitoring"
  
  cluster_name = var.cluster_name
  namespace    = var.monitoring_namespace
}

module "rbac" {
  count  = var.configure_rbac ? 1 : 0
  source = "../../common/rbac"
  
  cluster_name = var.cluster_name
  rbac_config  = var.rbac_config
}

module "security_policies" {
  count  = var.enable_security_policies ? 1 : 0
  source = "../../common/security-policies"
  
  cluster_name     = var.cluster_name
  security_policies = var.security_policies
}