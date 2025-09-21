# terraform/modules/common/monitoring/main.tf

terraform {
  required_providers {
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

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
    
    labels = {
      name                                 = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Prometheus Stack (includes Prometheus, Grafana, AlertManager)
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.kube_prometheus_stack_version

  create_namespace = false
  timeout          = 900

  # Basic configuration without external templates
  values = [
    yamlencode({
      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          retention      = var.prometheus_config.retention_period
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.prometheus_config.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_config.storage_size
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              cpu    = var.resource_limits.prometheus.requests.cpu
              memory = var.resource_limits.prometheus.requests.memory
            }
            limits = {
              cpu    = var.resource_limits.prometheus.limits.cpu
              memory = var.resource_limits.prometheus.limits.memory
            }
          }
        }
      }

      # Grafana configuration
      grafana = {
        adminPassword = var.grafana_config.admin_password
        persistence = {
          enabled          = var.grafana_config.enable_persistence
          storageClassName = var.grafana_config.storage_class
          size            = var.grafana_config.storage_size
        }
        resources = {
          requests = {
            cpu    = var.resource_limits.grafana.requests.cpu
            memory = var.resource_limits.grafana.requests.memory
          }
          limits = {
            cpu    = var.resource_limits.grafana.limits.cpu
            memory = var.resource_limits.grafana.limits.memory
          }
        }
        # Basic dashboards
        defaultDashboardsEnabled = true
        # Service configuration
        service = {
          type = "ClusterIP"
          port = 80
        }
      }

      # AlertManager configuration
      alertmanager = {
        alertmanagerSpec = {
          resources = {
            requests = {
              cpu    = var.resource_limits.alertmanager.requests.cpu
              memory = var.resource_limits.alertmanager.requests.memory
            }
            limits = {
              cpu    = var.resource_limits.alertmanager.limits.cpu
              memory = var.resource_limits.alertmanager.limits.memory
            }
          }
        }
      }

      # Disable components we don't need for basic setup
      kubeApiServer = {
        enabled = false
      }
      kubelet = {
        enabled = true
      }
      kubeControllerManager = {
        enabled = false
      }
      coreDns = {
        enabled = true
      }
      kubeEtcd = {
        enabled = false
      }
      kubeScheduler = {
        enabled = false
      }
      kubeProxy = {
        enabled = true
      }
      kubeStateMetrics = {
        enabled = true
      }
      nodeExporter = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}