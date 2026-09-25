output "cloud_sql_password_secret_id" {
  description = "The secret ID for Cloud SQL password"
  value       = google_secret_manager_secret.cloud_sql_password.secret_id
}

output "cloud_sql_password_secret_name" {
  description = "The fully qualified resource name of the Cloud SQL password secret"
  value       = google_secret_manager_secret.cloud_sql_password.name
}

output "cloud_sql_password_version_id" {
  description = "The version ID of the Cloud SQL password secret"
  value       = google_secret_manager_secret_version.cloud_sql_password_version.id
}

output "cloud_sql_password_value" {
  description = "The plain text value of the Cloud SQL password (sensitive)"
  value       = local.effective_sql_password
  sensitive   = true
}

output "api_key_secret_id" {
  description = "The secret ID for the API key"
  value       = google_secret_manager_secret.api_key.secret_id
}

output "api_key_secret_name" {
  description = "The fully qualified resource name of the API key secret"
  value       = google_secret_manager_secret.api_key.name
}

output "api_key_version_id" {
  description = "The version ID of the API key secret"
  value       = google_secret_manager_secret_version.api_key_version.id
}
