/**
 * Artifact Registry Module
 *
 * Provisions a central Docker image repository in Google Artifact Registry
 * with vulnerability scanning and least privilege access.
 */

resource "google_artifact_registry_repository" "docker_repo" {
  provider      = google
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
