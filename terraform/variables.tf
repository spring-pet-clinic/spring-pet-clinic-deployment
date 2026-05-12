# ─── Global ───────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region for all resources"
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

# ─── Networking ───────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to spread resources across"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private app subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for isolated database subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnet egress"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ"
  type        = bool
  default     = true
}

# ─── EKS ──────────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access" {
  description = "Expose the EKS API endpoint publicly (disable in prod)"
  type        = bool
  default     = true
}

variable "infra_node_instance_types" {
  description = "Instance types for the infra node group (Config Server, Eureka)"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "app_node_instance_types" {
  description = "Instance types for the app node group (microservices)"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "monitoring_node_instance_types" {
  description = "Instance types for the monitoring node group"
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

# ─── RDS ──────────────────────────────────────────────────────────────────────

variable "mysql_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.4.3"
}

variable "db_instance_class" {
  description = "RDS instance class (free tier: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Number of days to retain RDS automated backups (0 = disabled, required for free tier)"
  type        = number
  default     = 0
}

variable "db_deletion_protection" {
  description = "Prevent accidental RDS deletion"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final RDS snapshot on deletion"
  type        = bool
  default     = true
}

# ─── ECR ──────────────────────────────────────────────────────────────────────

variable "ecr_image_tag_mutability" {
  description = "Whether image tags can be overwritten (MUTABLE) or not (IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_untagged_expiry_days" {
  description = "Days before untagged images are expired"
  type        = number
  default     = 1
}

variable "ecr_tagged_image_count" {
  description = "Maximum number of tagged images to retain per repository"
  type        = number
  default     = 10
}

# ─── AWS LOAD BALANCER CONTROLLER / INGRESS ───────────────────────────────────

variable "alb_controller_chart_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
  default     = "2.7.0"
}

variable "alb_controller_replicas" {
  description = "Number of controller replicas for high availability"
  type        = number
  default     = 2
}

variable "alb_controller_log_level" {
  description = "Log level for ALB controller (debug, info, warn, error)"
  type        = string
  default     = "info"
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
