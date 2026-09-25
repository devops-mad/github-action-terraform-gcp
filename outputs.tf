# =============================================================================
# Root Infrastructure Outputs
# =============================================================================

output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = module.vpc.network_name
}

output "vpc_subnet_name" {
  description = "The name of the primary subnet"
  value       = module.vpc.subnet_name
}

output "artifact_registry_url" {
  description = "Docker repository endpoint in Artifact Registry"
  value       = module.artifact_registry.repository_url
}

output "cloud_sql_instance_connection_name" {
  description = "Connection name for Cloud SQL (project:region:instance)"
  value       = module.database.instance_connection_name
}

output "cloud_sql_private_ip" {
  description = "Private IP address of the Cloud SQL PostgreSQL instance"
  value       = module.database.private_ip_address
}

output "gke_cluster_name" {
  description = "Name of the GKE Autopilot cluster"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "Kubernetes control plane API endpoint"
  value       = module.gke.endpoint
}

output "cloud_run_service_uri" {
  description = "HTTPS endpoint URL for the deployed Cloud Run service"
  value       = module.cloud_run.service_uri
}

output "k8s_cloudsql_proxy_dns" {
  description = "Cluster-internal DNS name for the Cloud SQL Auth Proxy DaemonSet Service"
  value       = module.gke_workloads.proxy_internal_dns
}

output "cloudsql_proxy_gsa_email" {
  description = "Workload Identity Google Service Account email for Cloud SQL Proxy"
  value       = module.gke_workloads.service_account_email
}
