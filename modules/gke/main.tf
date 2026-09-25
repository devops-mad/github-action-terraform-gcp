/**
 * GKE Autopilot Module
 *
 * Provisions a fully managed GKE Autopilot cluster configured according to Google Cloud
 * enterprise security baselines:
 * - Autopilot handles node provisioning, scaling, OS patching, and security hardening.
 * - Workload Identity is automatically enabled on Autopilot (`<project_id>.svc.id.goog`).
 * - Private cluster: Worker nodes receive only internal RFC1918 IPs (no public node IPs).
 * - Control plane is accessible only from specified authorized CIDR ranges.
 */

resource "google_container_cluster" "autopilot_cluster" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  enable_autopilot = true

  network    = var.vpc_id
  subnetwork = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  deletion_protection = var.deletion_protection

  # Autopilot clusters maintain release channels (REGULAR, RAPID, STABLE)
  release_channel {
    channel = "REGULAR"
  }
}
