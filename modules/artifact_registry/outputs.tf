output "repository_id" {
  description = "The ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "repository_name" {
  description = "The fully qualified name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.docker_repo.name
}

output "repository_url" {
  description = "Docker repository URL for pushing/pulling images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}
