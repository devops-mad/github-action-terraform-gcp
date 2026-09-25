variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cloud_sql_password" {
  description = "Initial password for Cloud SQL user. If null/empty, a secure random string is generated."
  type        = string
  default     = null
  sensitive   = true
}

variable "api_key" {
  description = "API key value to store in Secret Manager. Can be passed via environment variable (TF_VAR_api_key)."
  type        = string
  default     = "placeholder-dev-api-key-change-me"
  sensitive   = true
}

variable "replication_locations" {
  description = "Replication locations for Secret Manager secrets. Empty list defaults to automatic replication."
  type        = list(string)
  default     = []
}
