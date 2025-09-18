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

# Add Helm repositories
resource "helm_release" "prometheus_operator_crds" {
  name       = "prometheus-operator-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-operator-crds"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.prometheus_operator_crds_version

  create_namespace = false
  
  depends_on = [kubernetes_namespace.monitoring]
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
  
  values = [
    templatefile("${path.module}/templates/prometheus-values.yaml", {
      cluster_name           = var.cluster_name
      retention_period       = var.prometheus_config.retention_period
      storage_size          = var.prometheus_config.storage_size
      storage_class         = var.prometheus_config.storage_class
      grafana_admin_password = var.grafana_config.admin_password
      grafana_storage_size   = var.grafana_config.storage_size
      grafana_storage_class  = var.grafana_config.storage_class
      enable_persistence     = var.grafana_config.enable_persistence
      slack_webhook_url      = var.alerting_config.slack_webhook_url
      pagerduty_service_key  = var.alerting_config.pagerduty_service_key
      email_from            = var.alerting_config.email_from
      email_to              = var.alerting_config.email_to
      smtp_smarthost        = var.alerting_config.smtp_smarthost
      smtp_auth_username    = var.alerting_config.smtp_auth_username
      smtp_auth_password    = var.alerting_config.smtp_auth_password
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.prometheus_operator_crds
  ]
}

# Loki for log aggregation (optional)
resource "helm_release" "loki" {
  count = var.enable_loki ? 1 : 0
  
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.loki_version

  create_namespace = false
  
  values = [
    templatefile("${path.module}/templates/loki-values.yaml", {
      storage_size  = var.loki_config.storage_size
      storage_class = var.loki_config.storage_class
      retention_period = var.loki_config.retention_period
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Promtail for log collection (if Loki is enabled)
resource "helm_release" "promtail" {
  count = var.enable_loki ? 1 : 0
  
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.promtail_version

  create_namespace = false
  
  values = [
    templatefile("${path.module}/templates/promtail-values.yaml", {
      loki_url = "http://loki:3100/loki/api/v1/push"
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.loki
  ]
}

# Jaeger for distributed tracing (optional)
resource "helm_release" "jaeger" {
  count = var.enable_jaeger ? 1 : 0
  
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.jaeger_version

  create_namespace = false
  
  values = [
    templatefile("${path.module}/templates/jaeger-values.yaml", {
      storage_type = var.jaeger_config.storage_type
      es_server_urls = var.jaeger_config.elasticsearch_urls
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Node Exporter for hardware metrics
resource "helm_release" "node_exporter" {
  name       = "node-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-node-exporter"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.node_exporter_version

  create_namespace = false
  
  values = [
    templatefile("${path.module}/templates/node-exporter-values.yaml", {
      cluster_name = var.cluster_name
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# Metrics Server (if not already installed by cloud provider)
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0
  
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_version

  create_namespace = false
  
  set {
    name  = "args"
    value = "{--cert-dir=/tmp,--secure-port=4443,--kubelet-preferred-address-types=InternalIP\\,ExternalIP\\,Hostname,--kubelet-use-node-status-port,--metric-resolution=15s}"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }
}

# Custom Grafana dashboards
resource "kubernetes_config_map" "grafana_dashboards" {
  for_each = var.custom_dashboards

  metadata {
    name      = "grafana-dashboard-${each.key}"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "${each.key}.json" = each.value
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# Custom Prometheus rules
resource "kubernetes_manifest" "prometheus_rules" {
  for_each = var.custom_prometheus_rules

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    
    metadata = {
      name      = each.key
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      
      labels = {
        app                = "kube-prometheus-stack"
        release           = "kube-prometheus-stack"
        prometheus        = "kube-prometheus-stack-prometheus"
      }
    }
    
    spec = each.value
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# ServiceMonitor for custom metrics
resource "kubernetes_manifest" "service_monitors" {
  for_each = var.service_monitors

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    
    metadata = {
      name      = each.key
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      
      labels = {
        app     = "kube-prometheus-stack"
        release = "kube-prometheus-stack"
      }
    }
    
    spec = each.value
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# Network Policy for monitoring namespace
resource "kubernetes_network_policy" "monitoring" {
  count = var.enable_network_policies ? 1 : 0

  metadata {
    name      = "monitoring-network-policy"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    # Allow ingress from anywhere (for Grafana UI access)
    ingress {
      from {}
      
      ports {
        port     = "3000"
        protocol = "TCP"
      }
      
      ports {
        port     = "9090"
        protocol = "TCP"
      }
      
      ports {
        port     = "9093"
        protocol = "TCP"
      }
    }
    
    # Allow egress to anywhere (for scraping metrics)
    egress {
      to {}
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# PodDisruptionBudget for high availability
resource "kubernetes_pod_disruption_budget_v1" "prometheus" {
  metadata {
    name      = "prometheus-pdb"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    min_available = 1
    
    selector {
      match_labels = {
        app                         = "kube-prometheus-stack-prometheus"
        "app.kubernetes.io/name"    = "prometheus"
      }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_pod_disruption_budget_v1" "grafana" {
  metadata {
    name      = "grafana-pdb"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    min_available = 1
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "grafana"
        "app.kubernetes.io/instance" = "kube-prometheus-stack"
      }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_pod_disruption_budget_v1" "alertmanager" {
  metadata {
    name      = "alertmanager-pdb"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    min_available = 1
    
    selector {
      match_labels = {
        app                         = "kube-prometheus-stack-alertmanager"
        "app.kubernetes.io/name"    = "alertmanager"
      }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}