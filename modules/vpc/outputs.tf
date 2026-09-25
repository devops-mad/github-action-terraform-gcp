output "network_id" {
  description = "The ID of the custom VPC network"
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "The name of the custom VPC network"
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "The ID of the primary subnetwork"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "The name of the primary subnetwork"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_self_link" {
  description = "The self_link of the primary subnetwork"
  value       = google_compute_subnetwork.subnet.self_link
}

output "pods_secondary_range_name" {
  description = "The name of the secondary range for GKE Pods"
  value       = "gke-pods"
}

output "services_secondary_range_name" {
  description = "The name of the secondary range for GKE Services"
  value       = "gke-services"
}

output "psa_connection_id" {
  description = "The ID of the Private Services Access connection"
  value       = google_service_networking_connection.private_vpc_connection.id
}
