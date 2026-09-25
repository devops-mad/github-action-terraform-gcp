/**
 * Secret Manager Module
 *
 * Provisions Google Secret Manager resources for sensitive application configurations:
 * - cloud-sql-password
 * - api-key
 *
 * Supports dynamic generation of passwords via random_password or secure injection via variables.
 */

resource "random_password" "generated_sql_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  effective_sql_password = coalesce(var.cloud_sql_password, random_password.generated_sql_password.result)
}

# -----------------------------------------------------------------------------
# Secret 1: cloud-sql-password
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret" "cloud_sql_password" {
  project   = var.project_id
  secret_id = "cloud-sql-password"

  replication {
    dynamic "user_managed" {
      for_each = length(var.replication_locations) > 0 ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.replication_locations
          content {
            location = replicas.value
          }
        }
      }
    }

    dynamic "auto" {
      for_each = length(var.replication_locations) == 0 ? [1] : []
      content {}
    }
  }

  labels = {
    environment = "dev"
    managed_by  = "terraform"
    type        = "credentials"
  }
}

resource "google_secret_manager_secret_version" "cloud_sql_password_version" {
  secret      = google_secret_manager_secret.cloud_sql_password.id
  secret_data = local.effective_sql_password
}

# -----------------------------------------------------------------------------
# Secret 2: api-key
# -----------------------------------------------------------------------------
resource "google_secret_manager_secret" "api_key" {
  project   = var.project_id
  secret_id = "api-key"

  replication {
    dynamic "user_managed" {
      for_each = length(var.replication_locations) > 0 ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.replication_locations
          content {
            location = replicas.value
          }
        }
      }
    }

    dynamic "auto" {
      for_each = length(var.replication_locations) == 0 ? [1] : []
      content {}
    }
  }

  labels = {
    environment = "dev"
    managed_by  = "terraform"
    type        = "configuration"
  }
}

resource "google_secret_manager_secret_version" "api_key_version" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = var.api_key
}
