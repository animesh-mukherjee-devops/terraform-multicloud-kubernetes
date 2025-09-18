# terraform/modules/kubernetes/azure/main.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.cluster_name}-rg"
  location = var.location

  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  count = var.create_vnet ? 1 : 0

  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]

  tags = local.common_tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  count = var.create_vnet ? 1 : 0

  name                 = "${var.cluster_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.aks_subnet_address_prefix]

  # Delegate subnet to AKS
  delegation {
    name = "aks-delegation"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Network Security Group for AKS subnet
resource "azurerm_network_security_group" "aks" {
  count = var.create_vnet ? 1 : 0

  name                = "${var.cluster_name}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow HTTPS traffic
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP traffic
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "aks" {
  count = var.create_vnet ? 1 : 0

  subnet_id                 = azurerm_subnet.aks[0].id
  network_security_group_id = azurerm_network_security_group.aks[0].id
}

# User Assigned Identity for AKS
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.cluster_name}-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Role assignment for AKS identity
resource "azurerm_role_assignment" "aks_network" {
  count = var.create_vnet ? 1 : 0

  scope                = azurerm_virtual_network.main[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Key Vault for secrets
resource "azurerm_key_vault" "main" {
  count = var.enable_key_vault ? 1 : 0

  name                = "${var.cluster_name}-kv-${random_string.key_vault_suffix[0].result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable RBAC instead of access policies
  enable_rbac_authorization = true

  # Network access rules
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Allow access from AKS subnet
    virtual_network_subnet_ids = var.create_vnet ? [azurerm_subnet.aks[0].id] : []
  }

  tags = local.common_tags
}

# Random string for Key Vault name (must be globally unique)
resource "random_string" "key_vault_suffix" {
  count = var.enable_key_vault ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_log_analytics ? 1 : 0

  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = local.common_tags
}

# Container Registry
resource "azurerm_container_registry" "main" {
  count = var.create_acr ? 1 : 0

  name                = "${replace(var.cluster_name, "-", "")}acr${random_string.acr_suffix[0].result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = false

  # Enable geo-replication for Premium SKU
  dynamic "georeplications" {
    for_each = var.acr_sku == "Premium" ? var.acr_georeplications : []
    content {
      location                = georeplications.value.location
      zone_redundancy_enabled = georeplications.value.zone_redundancy_enabled
      tags                    = local.common_tags
    }
  }

  tags = local.common_tags
}

# Random string for ACR name (must be globally unique)
resource "random_string" "acr_suffix" {
  count = var.create_acr ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # Private cluster configuration
  private_cluster_enabled             = var.enable_private_cluster
  private_dns_zone_id                = var.enable_private_cluster ? var.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = var.enable_private_cluster ? var.enable_private_cluster_public_fqdn : false

  # Identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Default node pool
  default_node_pool {
    name                 = "default"
    node_count           = var.default_node_pool.node_count
    vm_size              = var.default_node_pool.vm_size
    vnet_subnet_id       = var.create_vnet ? azurerm_subnet.aks[0].id : var.existing_subnet_id
    zones                = var.availability_zones
    enable_auto_scaling  = var.default_node_pool.enable_auto_scaling
    min_count            = var.default_node_pool.min_count
    max_count            = var.default_node_pool.max_count
    max_pods             = var.default_node_pool.max_pods
    os_disk_size_gb      = var.default_node_pool.os_disk_size_gb
    os_disk_type         = var.default_node_pool.os_disk_type
    enable_node_public_ip = false
    
    # Node labels
    node_labels = merge(var.common_node_labels, var.default_node_pool.node_labels)

    # Node taints
    node_taints = var.default_node_pool.node_taints

    upgrade_settings {
      max_surge = var.default_node_pool.max_surge
    }

    tags = local.common_tags
  }

  # Network profile
  network_profile {
    network_plugin      = var.network_plugin
    network_policy      = var.network_policy
    dns_service_ip      = var.dns_service_ip
    docker_bridge_cidr  = var.docker_bridge_cidr
    service_cidr        = var.service_cidr
    load_balancer_sku   = "standard"
    outbound_type       = var.outbound_type
  }

  # Azure AD integration
  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_azure_ad_integration ? [1] : []
    content {
      managed                = true
      admin_group_object_ids = var.azure_ad_admin_group_object_ids
      azure_rbac_enabled     = var.enable_azure_rbac
    }
  }

  # Auto-scaler profile
  dynamic "auto_scaler_profile" {
    for_each = var.enable_cluster_autoscaler ? [1] : []
    content {
      balance_similar_node_groups      = var.autoscaler_profile.balance_similar_node_groups
      expander                         = var.autoscaler_profile.expander
      max_graceful_termination_sec     = var.autoscaler_profile.max_graceful_termination_sec
      max_node_provisioning_time       = var.autoscaler_profile.max_node_provisioning_time
      max_unready_nodes               = var.autoscaler_profile.max_unready_nodes
      max_unready_percentage          = var.autoscaler_profile.max_unready_percentage
      new_pod_scale_up_delay          = var.autoscaler_profile.new_pod_scale_up_delay
      scale_down_delay_after_add      = var.autoscaler_profile.scale_down_delay_after_add
      scale_down_delay_after_delete   = var.autoscaler_profile.scale_down_delay_after_delete
      scale_down_delay_after_failure  = var.autoscaler_profile.scale_down_delay_after_failure
      scan_interval                   = var.autoscaler_profile.scan_interval
      scale_down_unneeded             = var.autoscaler_profile.scale_down_unneeded
      scale_down_utilization_threshold = var.autoscaler_profile.scale_down_utilization_threshold
      empty_bulk_delete_max           = var.autoscaler_profile.empty_bulk_delete_max
      skip_nodes_with_local_storage   = var.autoscaler_profile.skip_nodes_with_local_storage
      skip_nodes_with_system_pods     = var.autoscaler_profile.skip_nodes_with_system_pods
    }
  }

  # OMS Agent (Azure Monitor)
  dynamic "oms_agent" {
    for_each = var.enable_log_analytics ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.main[0].id
    }
  }

  # HTTP application routing (not recommended for production)
  http_application_routing_enabled = var.enable_http_application_routing

  # Key Vault secrets provider
  dynamic "key_vault_secrets_provider" {
    for_each = var.enable_key_vault_secrets_provider ? [1] : []
    content {
      secret_rotation_enabled  = var.key_vault_secrets_provider.secret_rotation_enabled
      secret_rotation_interval = var.key_vault_secrets_provider.secret_rotation_interval
    }
  }

  # Workload identity
  workload_identity_enabled = var.enable_workload_identity
  oidc_issuer_enabled      = var.enable_oidc_issuer

  tags = local.common_tags

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Local values
locals {
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "terraform"
    ClusterName   = var.cluster_name
    CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
    CostCenter    = var.cost_center
    Owner         = var.owner
  }
} = [
    azurerm_role_assignment.aks_network
  ]
}

# Additional node pools
resource "azurerm_kubernetes_cluster_node_pool" "additional" {
  for_each = var.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  vnet_subnet_id        = var.create_vnet ? azurerm_subnet.aks[0].id : var.existing_subnet_id
  zones                 = var.availability_zones
  enable_auto_scaling   = each.value.enable_auto_scaling
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  max_pods              = each.value.max_pods
  os_disk_size_gb       = each.value.os_disk_size_gb
  os_disk_type          = each.value.os_disk_type
  os_type               = each.value.os_type
  enable_node_public_ip = false
  
  # Node labels
  node_labels = merge(var.common_node_labels, each.value.node_labels)

  # Node taints
  node_taints = each.value.node_taints

  # Spot instances
  priority        = each.value.priority
  eviction_policy = each.value.priority == "Spot" ? each.value.eviction_policy : null
  spot_max_price  = each.value.priority == "Spot" ? each.value.spot_max_price : null

  upgrade_settings {
    max_surge = each.value.max_surge
  }

  tags = local.common_tags
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.main.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config.0.cluster_ca_certificate)
  }
}

# Install essential cluster components
module "monitoring" {
  count  = var.install_monitoring ? 1 : 0
  source = "../../common/monitoring"
  
  cluster_name = var.cluster_name
  namespace    = var.monitoring_namespace
  
  depends_on = [azurerm_kubernetes_cluster.main]
}

module "rbac" {
  count  = var.configure_rbac ? 1 : 0
  source = "../../common/rbac"
  
  cluster_name = var.cluster_name
  rbac_config  = var.rbac_config
  
  depends_on = [azurerm_kubernetes_cluster.main]
}

module "security_policies" {
  count  = var.enable_security_policies ? 1 : 0
  source = "../../common/security-policies"
  
  cluster_name      = var.cluster_name
  security_policies = var.security_policies
  
  depends_on