variable "project_id" {
  description = "The Google Cloud Platform Project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region for all infrastructure resources"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

# -----------------------------------------------------------------------------
# VPC Networking Variables
# -----------------------------------------------------------------------------
variable "network_name" {
  description = "Name of the custom VPC network"
  type        = string
  default     = "dev-vpc"
}

variable "subnet_name" {
  description = "Name of the primary subnetwork"
  type        = string
  default     = "dev-subnet-us-central1"
}

variable "subnet_cidr" {
  description = "Primary CIDR block for nodes and VMs"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR block for GKE Autopilot Pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR block for GKE Autopilot Services"
  type        = string
  default     = "10.30.0.0/20"
}

# -----------------------------------------------------------------------------
# Artifact Registry Variables
# -----------------------------------------------------------------------------
variable "artifact_registry_repo_id" {
  description = "Artifact Registry Docker repository ID"
  type        = string
  default     = "dev-docker-repo"
}

# -----------------------------------------------------------------------------
# Secret Manager Variables
# -----------------------------------------------------------------------------
variable "cloud_sql_password" {
  description = "Password for Cloud SQL user. If left null, a secure random password is automatically generated."
  type        = string
  default     = null
  sensitive   = true
}

variable "api_key" {
  description = "Initial API key secret value to store securely in Secret Manager"
  type        = string
  default     = "dev-secret-api-key-sample-token-12345"
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Cloud SQL Variables
# -----------------------------------------------------------------------------
variable "cloud_sql_instance_name" {
  description = "Base name for Cloud SQL PostgreSQL instance"
  type        = string
  default     = "dev-postgres"
}

variable "cloud_sql_tier" {
  description = "Machine tier for Cloud SQL (db-f1-micro is lowest cost tier for dev)"
  type        = string
  default     = "db-f1-micro"
}

variable "cloud_sql_database_name" {
  description = "Default application database name to create"
  type        = string
  default     = "appdb"
}

variable "cloud_sql_username" {
  description = "Default database master user username"
  type        = string
  default     = "appuser"
}

# -----------------------------------------------------------------------------
# GKE Autopilot Variables
# -----------------------------------------------------------------------------
variable "gke_cluster_name" {
  description = "Name of the GKE Autopilot cluster"
  type        = string
  default     = "dev-gke-autopilot"
}

variable "gke_master_ipv4_cidr_block" {
  description = "A /28 CIDR range for the private GKE control plane"
  type        = string
  default     = "172.16.0.0/28"
}

variable "gke_master_authorized_networks" {
  description = "List of CIDR ranges allowed to access the GKE control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "Allow-All-Dev-Workstations"
    }
  ]
}

# -----------------------------------------------------------------------------
# Cloud Run Variables
# -----------------------------------------------------------------------------
variable "cloud_run_service_name" {
  description = "Name of the Cloud Run v2 service"
  type        = string
  default     = "dev-app-service"
}

variable "cloud_run_image" {
  description = "Container image URL to deploy. If left null or empty, defaults dynamically to the Artifact Registry repository image ('app:latest')."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Lifecycle / Cost Controls
# -----------------------------------------------------------------------------
variable "deletion_protection" {
  description = "Enforce deletion protection on database and cluster (set to false for dev)"
  type        = bool
  default     = false
}
