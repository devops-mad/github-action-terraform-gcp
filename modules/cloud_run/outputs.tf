output "service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.name
}

output "service_uri" {
  description = "The default service URI of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.uri
}

output "service_account_email" {
  description = "The email of the dedicated Cloud Run Service Account"
  value       = google_service_account.cloud_run_sa.email
}
