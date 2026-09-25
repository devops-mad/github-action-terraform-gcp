/**
 * Serverless Module (Cloud Run v2)
 *
 * Implements a modern Cloud Run service using Direct VPC Egress and Secret Manager integration:
 *
 * Architecture Decisions & Rationale:
 * 1. Direct VPC Egress:
 *    - Replaces legacy Serverless VPC Access Connectors.
 *    - Cost Efficiency: Avoids ~$18+/month fixed fee per connector instance. Scales dynamically.
 *    - Performance: Direct routing inside Google Andromeda SDN reduces latency and eliminates bottlenecking.
 *    - Configured with `egress = "PRIVATE_RANGES_ONLY"` to route RFC1918 traffic (including Cloud SQL Private Services Access)
 *      through the VPC while preserving fast public internet egress for external APIs.
 *
 * 2. Enterprise Security & Secret Manager:
 *    - Dedicated runtime Service Account adhering strictly to least privilege.
 *    - Secret Manager secrets (`cloud-sql-password` and `api-key`) are mounted natively as environment variables via `secret_key_ref`.
 *    - Cloud Run Service Account is explicitly granted `roles/secretmanager.secretAccessor` only on the required secrets,
 *      and `roles/cloudsql.client` for database connectivity.
 */

# Dedicated runtime Service Account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  account_id   = "sa-${var.service_name}"
  display_name = "Cloud Run Service Account for ${var.service_name}"
  project      = var.project_id
}

# Least Privilege: Grant Cloud SQL Client permission to Cloud Run SA
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Least Privilege: Grant Secret Accessor only to the specific secrets
resource "google_secret_manager_secret_iam_member" "sql_password_accessor" {
  project   = var.project_id
  secret_id = var.cloud_sql_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "api_key_accessor" {
  project   = var.project_id
  secret_id = var.api_key_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Least Privilege: Grant Artifact Registry Reader to Cloud Run SA to pull private images
resource "google_project_iam_member" "artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Run v2 Service Definition
resource "google_cloud_run_v2_service" "service" {
  name     = var.service_name
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloud_run_sa.email

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    # Direct VPC Egress configuration
    vpc_access {
      network_interfaces {
        network    = var.vpc_id
        subnetwork = var.subnet_id
        tags       = ["cloud-run-service"]
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }

      # Non-sensitive database connection parameters
      env {
        name  = "DB_HOST"
        value = var.cloud_sql_private_ip
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_NAME"
        value = var.database_name
      }

      env {
        name  = "DB_USER"
        value = var.db_username
      }

      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = var.cloud_sql_instance_connection_name
      }

      # Dynamic Secret Injection via Secret Manager
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.cloud_sql_password_secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "API_KEY"
        value_source {
          secret_key_ref {
            secret  = var.api_key_secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.sql_password_accessor,
    google_secret_manager_secret_iam_member.api_key_accessor,
    google_project_iam_member.cloudsql_client,
    google_project_iam_member.artifact_registry_reader
  ]
}
