variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the GKE cluster"
  type        = string
}

variable "cluster_name" {
  description = "The name of the GKE Autopilot cluster"
  type        = string
  default     = "dev-gke-autopilot"
}

variable "vpc_id" {
  description = "The ID or self_link of the VPC network"
  type        = string
}

variable "subnet_id" {
  description = "The ID or self_link of the subnetwork"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "The name of the secondary range for pods"
  type        = string
}

variable "services_secondary_range_name" {
  description = "The name of the secondary range for services"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "The /28 CIDR block for the GKE control plane"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks authorized to reach the Kubernetes control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "Allow-All-Dev-Access"
    }
  ]
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled for the cluster"
  type        = bool
  default     = false
}
