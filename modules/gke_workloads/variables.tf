variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "The name of the GKE Autopilot cluster"
  type        = string
}

variable "instance_connection_name" {
  description = "The Cloud SQL instance connection name (e.g. project:region:instance)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy the Cloud SQL Auth Proxy DaemonSet into"
  type        = string
  default     = "cloudsql-proxy"
}

variable "ksa_name" {
  description = "Kubernetes Service Account name"
  type        = string
  default     = "cloudsql-proxy-sa"
}

variable "gsa_name" {
  description = "Google Service Account name for Workload Identity"
  type        = string
  default     = "sa-gke-cloudsql-proxy"
}

variable "proxy_port" {
  description = "Port on which Cloud SQL Proxy listens"
  type        = number
  default     = 5432
}

variable "cpu_request" {
  description = "CPU request for the Cloud SQL Proxy container (Autopilot minimum compliance)"
  type        = string
  default     = "250m"
}

variable "memory_request" {
  description = "Memory request for the Cloud SQL Proxy container (Autopilot minimum compliance)"
  type        = string
  default     = "512Mi"
}
