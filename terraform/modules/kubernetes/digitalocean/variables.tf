# terraform/modules/kubernetes/digitalocean/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens."
  }
}

variable "region" {
  description = "DigitalOcean region for the cluster"
  type        = string
  default     = "nyc3"
}

variable "kubernetes_version_prefix" {
  description = "Kubernetes version prefix to use"
  type        = string
  default     = "1.28."
}

variable "create_vpc" {
  description = "Whether to create a new VPC for the cluster"
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use (if create_vpc is false)"
  type        = string
  default     = null
}

variable "vpc_ip_range" {
  description = "IP range for the VPC in CIDR notation"
  type        = string
  default     = "10.0.0.0/16"
}

variable "auto_upgrade" {
  description = "Enable automatic cluster upgrades"
  type        = bool
  default     = false
}

variable "surge_upgrade" {
  description = "Enable surge upgrades for better availability"
  type        = bool
  default     = true
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    start_time = string
    day        = string
  })
  default = {
    start_time = "04:00"
    day        = "sunday"
  }
}

variable "main_node_pool" {
  description = "Configuration for the main node pool"
  type = object({
    size       = string
    node_count = number
    auto_scale = bool
    min_nodes  = number
    max_nodes  = number
    labels     = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  })
  default = {
    size       = "s-2vcpu-4gb"
    node_count = 2
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 5
    labels     = {}
    taints     = []
  }
}

variable "additional_node_pools" {
  description = "Additional node pools configuration"
  type = map(object({
    size       = string
    node_count = number
    auto_scale = bool
    min_nodes  = number
    max_nodes  = number
    labels     = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {}
}

variable "common_labels" {
  description = "Common labels to apply to all nodes"
  type        = map(string)
  default     = {}
}

variable "cluster_tags" {
  description = "Tags to apply to the cluster and nodes"
  type        = list(string)
  default     = []
}

variable "install_monitoring" {
  description = "Install monitoring stack (Prometheus, Grafana)"
  type        = bool
  default     = true
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring components"
  type        = string
  default     = "monitoring"
}

variable "configure_rbac" {
  description = "Configure RBAC policies"
  type        = bool
  default     = true
}

variable "rbac_config" {
  description = "RBAC configuration"
  type        = any
  default     = {}
}

variable "enable_security_policies" {
  description = "Enable security policies (Pod Security Standards, Network Policies)"
  type        = bool
  default     = true
}

variable "security_policies" {
  description = "Security policies configuration"
  type        = any
  default     = {}
}