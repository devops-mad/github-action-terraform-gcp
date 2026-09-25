variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the Cloud SQL instance"
  type        = string
}

variable "instance_name" {
  description = "The name of the Cloud SQL database instance"
  type        = string
  default     = "dev-postgres-instance"
}

variable "database_version" {
  description = "The PostgreSQL database engine version"
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "The machine tier for the Cloud SQL instance (lowest cost for dev is db-f1-micro)"
  type        = string
  default     = "db-f1-micro"
}

variable "vpc_id" {
  description = "The self_link or ID of the VPC network for private IP connectivity"
  type        = string
}

variable "psa_connection_id" {
  description = "The ID of the Private Services Access connection (used to enforce module ordering)"
  type        = string
}

variable "database_name" {
  description = "The name of the initial database to create"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "The database user username"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "The database user password"
  type        = string
  sensitive   = true
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled (false for dev environments)"
  type        = bool
  default     = false
}
