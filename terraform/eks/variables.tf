variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used in resource naming and tagging"
  type        = string
  default     = "spring-petclinic"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

# ─── Networking inputs (from networking module outputs) ───────────────────────

variable "vpc_id" {
  description = "VPC ID from the networking module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes and cluster endpoint"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the cluster's public endpoint"
  type        = list(string)
}

variable "sg_app_services_id" {
  description = "Security group ID for app services (from networking module)"
  type        = string
}

variable "sg_infra_services_id" {
  description = "Security group ID for infra services (from networking module)"
  type        = string
}

# ─── Node group sizing ────────────────────────────────────────────────────────

variable "infra_node_instance_types" {
  description = "Instance types for the infra node group (Config Server, Eureka)"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "infra_node_desired" {
  description = "Desired number of infra nodes"
  type        = number
  default     = 2
}

variable "infra_node_min" {
  description = "Minimum number of infra nodes"
  type        = number
  default     = 1
}

variable "infra_node_max" {
  description = "Maximum number of infra nodes"
  type        = number
  default     = 3
}

variable "app_node_instance_types" {
  description = "Instance types for the app node group (microservices)"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "app_node_desired" {
  description = "Desired number of app nodes"
  type        = number
  default     = 2
}

variable "app_node_min" {
  description = "Minimum number of app nodes"
  type        = number
  default     = 2
}

variable "app_node_max" {
  description = "Maximum number of app nodes"
  type        = number
  default     = 6
}

variable "monitoring_node_instance_types" {
  description = "Instance types for the monitoring node group"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "monitoring_node_desired" {
  description = "Desired number of monitoring nodes"
  type        = number
  default     = 1
}

variable "monitoring_node_min" {
  description = "Minimum number of monitoring nodes"
  type        = number
  default     = 1
}

variable "monitoring_node_max" {
  description = "Maximum number of monitoring nodes"
  type        = number
  default     = 2
}

variable "cluster_endpoint_public_access" {
  description = "Allow public access to the EKS API endpoint (disable in prod)"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "EKS control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}
