# terraform/modules/common/monitoring/outputs.tf

output "namespace" {
  description = "Monitoring namespace name"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service_name" {
  description = "Prometheus service name"
  value       = "kube-prometheus-stack-prometheus"
}

output "grafana_service_name" {
  description = "Grafana service name"
  value       = "kube-prometheus-stack-grafana"
}

output "alertmanager_service_name" {
  description = "AlertManager service name"
  value       = "kube-prometheus-stack-alertmanager"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_config.admin_password
  sensitive   = true
}

output "prometheus_url" {
  description = "Internal Prometheus URL"
  value       = "http://kube-prometheus-stack-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
}

output "grafana_url" {
  description = "Internal Grafana URL"
  value       = "http://kube-prometheus-stack-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:80"
}

output "alertmanager_url" {
  description = "Internal AlertManager URL"
  value       = "http://kube-prometheus-stack-alertmanager.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093"
}

output "loki_url" {
  description = "Internal Loki URL (if enabled)"
  value       = var.enable_loki ? "http://loki.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:3100" : null
}

output "access_instructions" {
  description = "Instructions for accessing monitoring services"
  value = <<-EOT
    To access monitoring services:
    
    1. Grafana (Web UI):
       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/kube-prometheus-stack-grafana 3000:80
       Open: http://localhost:3000
       Login: admin / ${var.grafana_config.admin_password}
    
    2. Prometheus (Web UI):
       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/kube-prometheus-stack-prometheus 9090:9090
       Open: http://localhost:9090
    
    3. AlertManager (Web UI):
       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/kube-prometheus-stack-alertmanager 9093:9093
       Open: http://localhost:9093
    
    ${var.enable_loki ? "4. Loki (API):\n       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/loki 3100:3100\n       API: http://localhost:3100" : ""}
  EOT
}