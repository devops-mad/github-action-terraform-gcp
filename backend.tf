/**
 * Remote State Backend Configuration
 *
 * Implements a partial GCS backend configuration.
 * The GCS bucket name is provided dynamically at initialization time via:
 *   terraform init -backend-config="bucket=terraform-state-${PROJECT_ID}"
 * or
 *   terraform init -backend-config=backend.tfvars
 *
 * This decouples the bucket name from the codebase, avoiding hardcoded values
 * and allowing the same code to be reused across dev, staging, and prod environments.
 */

terraform {
  backend "gcs" {
    prefix = "terraform/state"
  }
}
