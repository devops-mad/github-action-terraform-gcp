variable "project_id" {
  description = "The GCP project ID to deploy resources into"
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources"
  type        = string
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "dev-vpc"
}

variable "subnet_name" {
  description = "The name of the primary subnet"
  type        = string
  default     = "dev-subnet"
}

variable "subnet_cidr" {
  description = "CIDR block for the primary subnet"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR block for GKE Pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR block for GKE Services"
  type        = string
  default     = "10.30.0.0/20"
}

variable "psa_peering_prefix_length" {
  description = "Prefix length for Cloud SQL Private Services Access"
  type        = number
  default     = 16
}
