/**
 * Cloud SQL (PostgreSQL) Module
 *
 * Configures an enterprise-hardened, private-only PostgreSQL instance.
 * - Zero public IPv4 access (ipv4_enabled = false).
 * - Connected strictly via Private Services Access (PSA) to the custom VPC.
 * - Single-zone db-f1-micro tier for maximum cost savings in development.
 * - Random suffix added to prevent name collisions upon destroy/recreate.
 */

resource "random_id" "db_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "postgres" {
  name             = "${var.instance_name}-${random_id.db_suffix.hex}"
  project          = var.project_id
  region           = var.region
  database_version = var.database_version

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = "ZONAL" # Single zone for cost efficiency in dev
    disk_type         = "PD_SSD"
    disk_size         = 10 # Minimum disk size allowed in GB
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.vpc_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    insights_config {
      query_insights_enabled  = false
      record_application_tags = false
    }
  }

  # Enforce explicit dependency on the PSA VPC connection
  # Cloud SQL private IP creation fails if peering is not fully established
  depends_on = [var.psa_connection_id]
}

resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

resource "google_sql_user" "user" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
  project  = var.project_id
}
