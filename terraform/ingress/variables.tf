variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod, ireland)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod", "ireland"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, ireland."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "eks_nodes_security_group_id" {
  description = "Security group ID of EKS worker nodes"
  type        = string
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID of EKS cluster control plane"
  type        = string
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
  default     = "3.3.0"
}

variable "alb_controller_replicas" {
  description = "Number of controller replicas for high availability"
  type        = number
  default     = 2
  validation {
    condition     = var.alb_controller_replicas >= 1 && var.alb_controller_replicas <= 5
    error_message = "Controller replicas must be between 1 and 5."
  }
}

variable "alb_controller_log_level" {
  description = "Log level for ALB controller (debug, info, warn, error)"
  type        = string
  default     = "info"
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.alb_controller_log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "enable_shield" {
  description = "Enable AWS Shield Standard protection (free DDoS protection)"
  type        = bool
  default     = false
}

variable "enable_waf" {
  description = "Enable AWS WAF Classic integration"
  type        = bool
  default     = false
}

variable "enable_wafv2" {
  description = "Enable AWS WAF v2 integration"
  type        = bool
  default     = false
}
