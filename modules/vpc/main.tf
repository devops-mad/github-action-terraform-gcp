/**
 * VPC Network Module
 *
 * Implements an enterprise-grade custom VPC with zero default subnets,
 * dedicated secondary IP ranges for GKE Autopilot Pods and Services,
 * Private Google Access, and Private Services Access (PSA) for Cloud SQL.
 */

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = var.project_id
  description             = "Custom VPC for dev environment - no auto subnets"
}

# Subnet configured with Private Google Access and secondary IP ranges for GKE
resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  project                  = var.project_id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# -----------------------------------------------------------------------------
# Private Services Access (PSA) for Cloud SQL & Managed GCP Services
# -----------------------------------------------------------------------------
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${var.network_name}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_peering_prefix_length
  network       = google_compute_network.vpc.id
  project       = var.project_id
  description   = "Reserved IP address range for Private Services Access peering"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
  deletion_policy         = "ABANDON"
}


# -----------------------------------------------------------------------------
# Baseline Firewall Rules
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name        = "${var.network_name}-allow-internal"
  network     = google_compute_network.vpc.name
  project     = var.project_id
  description = "Allow internal traffic between all subnets in the VPC"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    var.subnet_cidr,
    var.pods_cidr,
    var.services_cidr
  ]
}

resource "google_compute_firewall" "allow_health_checks" {
  name        = "${var.network_name}-allow-health-checks"
  network     = google_compute_network.vpc.name
  project     = var.project_id
  description = "Allow Google Cloud Load Balancer health check probes"

  allow {
    protocol = "tcp"
  }

  # GCP standard health checking source ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]
}
