# terraform/modules/common/monitoring/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for monitoring components"
  type        = string
  default     = "monitoring"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

##########################
# Helm Chart Versions   #
##########################

variable "kube_prometheus_stack_version" {
  description = "Version of the kube-prometheus-stack Helm chart"
  type        = string
  default     = "55.5.0"
}

variable "loki_version" {
  description = "Version of the Loki Helm chart"
  type        = string
  default     = "5.41.4"
}

variable "promtail_version" {
  description = "Version of the Promtail Helm chart"
  type        = string
  default     = "6.15.3"
}

##########################
# Prometheus Configuration #
##########################

variable "prometheus_config" {
  description = "Prometheus configuration"
  type = object({
    retention_period = string
    storage_size     = string
    storage_class    = string
  })
  default = {
    retention_period = "15d"
    storage_size     = "50Gi"
    storage_class    = "default"
  }
}

##########################
# Grafana Configuration  #
##########################

variable "grafana_config" {
  description = "Grafana configuration"
  type = object({
    admin_password     = string
    storage_size       = string
    storage_class      = string
    enable_persistence = bool
  })
  default = {
    admin_password     = "admin123!"  # Change in production
    storage_size       = "10Gi"
    storage_class      = "default"
    enable_persistence = true
  }
  
  sensitive = true
}

##########################
# AlertManager Configuration #
##########################

variable "alerting_config" {
  description = "AlertManager configuration"
  type = object({
    slack_webhook_url     = string
    pagerduty_service_key = string
    email_from           = string
    email_to             = string
    smtp_smarthost       = string
    smtp_auth_username   = string
    smtp_auth_password   = string
  })
  default = {
    slack_webhook_url     = ""
    pagerduty_service_key = ""
    email_from           = ""
    email_to             = ""
    smtp_smarthost       = ""
    smtp_auth_username   = ""
    smtp_auth_password   = ""
  }
  
  sensitive = true
}

##########################
# Loki Configuration     #
##########################

variable "enable_loki" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = false  # Disabled by default for simpler setup
}

variable "loki_config" {
  description = "Loki configuration"
  type = object({
    storage_size     = string
    storage_class    = string
    retention_period = string
  })
  default = {
    storage_size     = "50Gi"
    storage_class    = "default"
    retention_period = "168h"  # 7 days
  }
}

##########################
# Feature Toggles        #
##########################

variable "enable_network_policies" {
  description = "Enable network policies for monitoring namespace"
  type        = bool
  default     = true
}

variable "enable_pod_disruption_budgets" {
  description = "Enable Pod Disruption Budgets for high availability"
  type        = bool
  default     = true
}

##########################
# Resource Limits        #
##########################

variable "resource_limits" {
  description = "Resource limits for monitoring components"
  type = object({
    prometheus = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    grafana = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    alertmanager = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    prometheus = {
      requests = {
        cpu    = "500m"
        memory = "2Gi"
      }
      limits = {
        cpu    = "2"
        memory = "8Gi"
      }
    }
    grafana = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
    alertmanager = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }
  }
}