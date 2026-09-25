variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for Artifact Registry"
  type        = string
}

variable "repository_id" {
  description = "The ID of the Artifact Registry repository"
  type        = string
  default     = "app-docker-repo"
}

variable "description" {
  description = "Description of the repository"
  type        = string
  default     = "Docker repository for application images"
}
