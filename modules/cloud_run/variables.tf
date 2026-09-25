variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the Cloud Run service"
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "dev-app-service"
}

variable "image" {
  description = "Container image URL to deploy. If using an image from Artifact Registry, ensure it exists or use the default placeholder."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "vpc_id" {
  description = "VPC network ID/self_link for Direct VPC Egress"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID/self_link for Direct VPC Egress"
  type        = string
}

variable "cloud_sql_password_secret_id" {
  description = "Secret ID for the Cloud SQL password in Secret Manager"
  type        = string
}

variable "api_key_secret_id" {
  description = "Secret ID for the API key in Secret Manager"
  type        = string
}

variable "cloud_sql_instance_connection_name" {
  description = "Cloud SQL instance connection name (project:region:instance)"
  type        = string
}

variable "cloud_sql_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  type        = string
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "min_instance_count" {
  description = "Minimum instances for Cloud Run (0 for scale-to-zero in dev)"
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum instances for Cloud Run"
  type        = number
  default     = 2
}
