output "namespace" {
  description = "The namespace where Cloud SQL Auth Proxy is deployed"
  value       = kubernetes_namespace.proxy_ns.metadata[0].name
}

output "service_account_email" {
  description = "Google Service Account email used by Workload Identity"
  value       = google_service_account.proxy_gsa.email
}

output "proxy_service_name" {
  description = "The Kubernetes Service name for connecting to Cloud SQL proxy"
  value       = kubernetes_service.proxy_service.metadata[0].name
}

output "proxy_internal_dns" {
  description = "Cluster-internal DNS name for Cloud SQL proxy service"
  value       = "${kubernetes_service.proxy_service.metadata[0].name}.${kubernetes_namespace.proxy_ns.metadata[0].name}.svc.cluster.local"
}
