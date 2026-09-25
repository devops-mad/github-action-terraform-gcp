/**
 * Root Terraform Configuration
 *
 * Orchestrates modular deployment of GCP enterprise infrastructure:
 * - VPC & Private Services Access (PSA)
 * - Artifact Registry (Docker repositories)
 * - Secret Manager (dynamic secret generation & storage)
 * - Cloud SQL PostgreSQL (private IP only, minimal dev tier)
 * - GKE Autopilot (private cluster with Workload Identity)
 * - Cloud Run v2 (Direct VPC Egress & Secret Manager integration)
 * - GKE DaemonSet (Cloud SQL Auth Proxy with Autopilot compliance)
 */

# -----------------------------------------------------------------------------
# Module 1: VPC Network & Connectivity
# -----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_id    = var.project_id
  region        = var.region
  network_name  = var.network_name
  subnet_name   = var.subnet_name
  subnet_cidr   = var.subnet_cidr
  pods_cidr     = var.pods_cidr
  services_cidr = var.services_cidr
}

# -----------------------------------------------------------------------------
# Module 2: Artifact Registry
# -----------------------------------------------------------------------------
module "artifact_registry" {
  source = "./modules/artifact_registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.artifact_registry_repo_id
}

# -----------------------------------------------------------------------------
# Module 3: Secret Manager
# -----------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  project_id         = var.project_id
  cloud_sql_password = var.cloud_sql_password
  api_key            = var.api_key
}

# -----------------------------------------------------------------------------
# Module 4: Cloud SQL (PostgreSQL - Private IP Only)
# -----------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  project_id          = var.project_id
  region              = var.region
  instance_name       = var.cloud_sql_instance_name
  tier                = var.cloud_sql_tier
  vpc_id              = module.vpc.network_id
  psa_connection_id   = module.vpc.psa_connection_id
  database_name       = var.cloud_sql_database_name
  db_username         = var.cloud_sql_username
  db_password         = module.secrets.cloud_sql_password_value
  deletion_protection = var.deletion_protection
}

# -----------------------------------------------------------------------------
# Module 5: GKE Autopilot (Private Cluster)
# -----------------------------------------------------------------------------
module "gke" {
  source = "./modules/gke"

  project_id                    = var.project_id
  region                        = var.region
  cluster_name                  = var.gke_cluster_name
  vpc_id                        = module.vpc.network_id
  subnet_id                     = module.vpc.subnet_id
  pods_secondary_range_name     = module.vpc.pods_secondary_range_name
  services_secondary_range_name = module.vpc.services_secondary_range_name
  master_ipv4_cidr_block        = var.gke_master_ipv4_cidr_block
  master_authorized_networks    = var.gke_master_authorized_networks
  deletion_protection           = var.deletion_protection
}

# -----------------------------------------------------------------------------
# Module 6: Cloud Run (with Direct VPC Egress)
# -----------------------------------------------------------------------------
module "cloud_run" {
  source = "./modules/cloud_run"

  project_id                         = var.project_id
  region                             = var.region
  service_name                       = var.cloud_run_service_name
  image                              = var.cloud_run_image != null && var.cloud_run_image != "" ? var.cloud_run_image : "${module.artifact_registry.repository_url}/app:latest"
  vpc_id                             = module.vpc.network_id
  subnet_id                          = module.vpc.subnet_id
  cloud_sql_password_secret_id       = module.secrets.cloud_sql_password_secret_id
  api_key_secret_id                  = module.secrets.api_key_secret_id
  cloud_sql_instance_connection_name = module.database.instance_connection_name
  cloud_sql_private_ip               = module.database.private_ip_address
  database_name                      = module.database.database_name
  db_username                        = module.database.db_username
}

# -----------------------------------------------------------------------------
# Module 7: GKE Workloads (Cloud SQL Auth Proxy DaemonSet)
# -----------------------------------------------------------------------------
module "gke_workloads" {
  source = "./modules/gke_workloads"

  project_id               = var.project_id
  cluster_name             = module.gke.cluster_name
  instance_connection_name = module.database.instance_connection_name

  # Ensure GKE control plane and database instance exist before applying k8s manifests
  depends_on = [
    module.gke,
    module.database
  ]
}

# -----------------------------------------------------------------------------
# State Refactoring (Ensures zero resource destruction when renaming modules)
# -----------------------------------------------------------------------------
moved {
  from = module.registry
  to   = module.artifact_registry
}

moved {
  from = module.serverless
  to   = module.cloud_run
}

moved {
  from = module.k8s_resources
  to   = module.gke_workloads
}
