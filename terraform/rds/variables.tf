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

# ─── Networking inputs (from networking module outputs) ───────────────────────

variable "vpc_id" {
  description = "VPC ID from the networking module"
  type        = string
}

variable "db_subnet_ids" {
  description = "Isolated DB subnet IDs from the networking module"
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "DB subnet group name from the networking module"
  type        = string
}

variable "sg_database_id" {
  description = "Database security group ID from the networking module"
  type        = string
}

variable "eks_cluster_security_group_id" {
  description = "EKS cluster control plane security group ID for RDS access"
  type        = string
}

variable "eks_node_security_group_id" {
  description = "Terraform-managed security group ID attached to EKS worker node ENIs"
  type        = string
}

# ─── Engine ───────────────────────────────────────────────────────────────────

variable "mysql_version" {
  description = "MySQL engine version (must match mysql:8.4.x used in docker-compose)"
  type        = string
  default     = "8.4.3"
}

variable "instance_class" {
  description = "RDS instance class (free tier: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

# ─── Storage ─────────────────────────────────────────────────────────────────

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GB (0 = disabled)"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "RDS storage type (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}

# ─── Availability & backups ───────────────────────────────────────────────────

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups (0 = disabled, required for free tier)"
  type        = number
  default     = 0
}

variable "backup_window" {
  description = "Preferred UTC window for automated backups (hh24:mi-hh24:mi)"
  type        = string
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Preferred UTC window for maintenance (ddd:hh24:mi-ddd:hh24:mi)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  description = "Prevent accidental deletion of the RDS instance"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (set to false in prod)"
  type        = bool
  default     = true
}

# ─── Databases ───────────────────────────────────────────────────────────────

variable "databases" {
  description = "Map of logical databases to create inside the RDS instance"
  type        = map(string)
  default = {
    customers = "petclinic_customers"
    visits    = "petclinic_visits"
    vets      = "petclinic_vets"
  }
}

variable "master_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "petclinic_admin"
}
