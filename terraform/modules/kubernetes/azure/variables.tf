# terraform/modules/kubernetes/azure/variables.tf

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.cluster_name))
    error_message = "Cluster name must be lowercase alphanumeric with hyphens."
  }
}

variable "location" {
  description = "Azure region for the cluster"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multi-cloud-k8s"
}

variable "cost_center" {
  description = "Cost center for billing purposes"
  type        = string
  default     = "platform-engineering"
}

variable "owner" {
  description = "Owner of the cluster"
  type        = string
  default     = "platform-team"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the AKS cluster"
  type        = string
  default     = "1.28.3"
}

##########################
# Network Configuration #
##########################

variable "create_vnet" {
  description = "Whether to create a new VNet for the cluster"
  type        = bool
  default     = true
}

variable "vnet_address_space" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "existing_subnet_id" {
  description = "ID of existing subnet to use (if create_vnet is false)"
  type        = string
  default     = null
}

variable "network_plugin" {
  description = "Network plugin to use for AKS"
  type        = string
  default     = "azure"
  
  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "Network plugin must be either 'azure' or 'kubenet'."
  }
}

variable "network_policy" {
  description = "Network policy to use"
  type        = string
  default     = "azure"
  
  validation {
    condition     = contains(["azure", "calico", ""], var.network_policy)
    error_message = "Network policy must be 'azure', 'calico', or empty string."
  }
}

variable "dns_service_ip" {
  description = "IP address within the Kubernetes service address range that will be used by cluster service discovery"
  type        = string
  default     = "10.2.0.10"
}

variable "service_cidr" {
  description = "CIDR notation IP range from which to assign service cluster IPs"
  type        = string
  default     = "10.2.0.0/24"
}

variable "docker_bridge_cidr" {
  description = "CIDR notation IP for Docker bridge"
  type        = string
  default     = "172.17.0.1/16"
}

variable "outbound_type" {
  description = "Outbound (egress) routing method"
  type        = string
  default     = "loadBalancer"
  
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting"], var.outbound_type)
    error_message = "Outbound type must be 'loadBalancer' or 'userDefinedRouting'."
  }
}

###########################
# Default Node Pool Config #
###########################

variable "default_node_pool" {
  description = "Configuration for the default node pool"
  type = object({
    node_count           = number
    vm_size              = string
    enable_auto_scaling  = bool
    min_count            = number
    max_count            = number
    max_pods             = number
    os_disk_size_gb      = number
    os_disk_type         = string
    node_labels          = map(string)
    node_taints          = list(string)
    max_surge            = string
  })
  default = {
    node_count           = 2
    vm_size              = "Standard_D2s_v3"
    enable_auto_scaling  = true
    min_count            = 1
    max_count            = 5
    max_pods             = 30
    os_disk_size_gb      = 128
    os_disk_type         = "Managed"
    node_labels          = {}
    node_taints          = []
    max_surge            = "1"
  }
}

variable "additional_node_pools" {
  description = "Additional node pools configuration"
  type = map(object({
    vm_size              = string
    node_count           = number
    enable_auto_scaling  = bool
    min_count            = number
    max_count            = number
    max_pods             = number
    os_disk_size_gb      = number
    os_disk_type         = string
    os_type              = string
    priority             = string
    eviction_policy      = string
    spot_max_price       = number
    node_labels          = map(string)
    node_taints          = list(string)
    max_surge            = string
  }))
  default = {}
}

variable "common_node_labels" {
  description = "Common labels to apply to all nodes"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "Availability zones for node pools"
  type        = list(string)
  default     = ["1", "2", "3"]
}

############################
# Private Cluster Settings #
############################

variable "enable_private_cluster" {
  description = "Enable private cluster"
  type        = bool
  default     = false
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for private cluster"
  type        = string
  default     = "System"
}

variable "enable_private_cluster_public_fqdn" {
  description = "Enable public FQDN for private cluster"
  type        = bool
  default     = false
}

######################
# Azure AD Integration #
######################

variable "enable_azure_ad_integration" {
  description = "Enable Azure AD integration"
  type        = bool
  default     = true
}

variable "azure_ad_admin_group_object_ids" {
  description = "Object IDs of Azure AD groups with admin access"
  type        = list(string)
  default     = []
}

variable "enable_azure_rbac" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

#########################
# Cluster Autoscaler    #
#########################

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}

variable "autoscaler_profile" {
  description = "Cluster autoscaler profile"
  type = object({
    balance_similar_node_groups       = bool
    expander                         = string
    max_graceful_termination_sec     = string
    max_node_provisioning_time       = string
    max_unready_nodes               = number
    max_unready_percentage          = number
    new_pod_scale_up_delay          = string
    scale_down_delay_after_add      = string
    scale_down_delay_after_delete   = string
    scale_down_delay_after_failure  = string
    scan_interval                   = string
    scale_down_unneeded             = string
    scale_down_utilization_threshold = number
    empty_bulk_delete_max           = number
    skip_nodes_with_local_storage   = bool
    skip_nodes_with_system_pods     = bool
  })
  default = {
    balance_similar_node_groups       = false
    expander                         = "random"
    max_graceful_termination_sec     = "600"
    max_node_provisioning_time       = "15m"
    max_unready_nodes               = 3
    max_unready_percentage          = 45
    new_pod_scale_up_delay          = "10s"
    scale_down_delay_after_add      = "10m"
    scale_down_delay_after_delete   = "10s"
    scale_down_delay_after_failure  = "3m"
    scan_interval                   = "10s"
    scale_down_unneeded             = "10m"
    scale_down_utilization_threshold = 0.5
    empty_bulk_delete_max           = 10
    skip_nodes_with_local_storage   = true
    skip_nodes_with_system_pods     = true
  }
}

#########################
# Monitoring & Logging  #
#########################

variable "enable_log_analytics" {
  description = "Enable Log Analytics workspace"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention must be between 30 and 730 days."
  }
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

######################
# Key Vault Settings #
######################

variable "enable_key_vault" {
  description = "Create Azure Key Vault for secrets"
  type        = bool
  default     = true
}

variable "enable_key_vault_secrets_provider" {
  description = "Enable Key Vault secrets provider"
  type        = bool
  default     = true
}

variable "key_vault_secrets_provider" {
  description = "Key Vault secrets provider configuration"
  type = object({
    secret_rotation_enabled  = bool
    secret_rotation_interval = string
  })
  default = {
    secret_rotation_enabled  = false
    secret_rotation_interval = "2m"
  }
}

#######################
# Container Registry  #
#######################

variable "create_acr" {
  description = "Create Azure Container Registry"
  type        = bool
  default     = true
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "acr_georeplications" {
  description = "Geo-replication locations for Premium ACR"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = []
}

####################
# Feature Toggles  #
####################

variable "enable_http_application_routing" {
  description = "Enable HTTP application routing (not recommended for production)"
  type        = bool
  default     = false
}

variable "enable_workload_identity" {
  description = "Enable workload identity"
  type        = bool
  default     = true
}

variable "enable_oidc_issuer" {
  description = "Enable OIDC issuer"
  type        = bool
  default     = true
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