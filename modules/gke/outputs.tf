output "cluster_name" {
  description = "The name of the GKE Autopilot cluster"
  value       = google_container_cluster.autopilot_cluster.name
}

output "cluster_id" {
  description = "The ID of the GKE Autopilot cluster"
  value       = google_container_cluster.autopilot_cluster.id
}

output "endpoint" {
  description = "The IP address of the Kubernetes control plane"
  value       = google_container_cluster.autopilot_cluster.endpoint
}

output "ca_certificate" {
  description = "The base64 encoded public CA certificate used to communicate with the cluster"
  value       = google_container_cluster.autopilot_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "The Workload Identity pool for the GKE cluster"
  value       = "${var.project_id}.svc.id.goog"
}
