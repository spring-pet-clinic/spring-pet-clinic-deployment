# ─────────────────────────────────────────────────────────────────────────────
# Root module — Spring PetClinic Microservices
#
# Dependency graph:
#   networking ──► eks
#              └──► rds
#   ecr  (independent — no deps on other modules)
# ─────────────────────────────────────────────────────────────────────────────

# ─── MODULE 1: NETWORKING ────────────────────────────────────────────────────
# VPC, public/private/db subnets, IGW, NAT Gateway, route tables,
# and all service-tier security groups.

module "networking" {
  source = "./networking"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
}

# ─── MODULE 2: EKS ───────────────────────────────────────────────────────────
# EKS cluster, three node groups (infra / app / monitoring),
# IAM roles, OIDC provider, and core add-ons.

module "eks" {
  source = "./eks"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment

  # Networking inputs
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids
  sg_app_services_id   = module.networking.sg_app_services_id
  sg_infra_services_id = module.networking.sg_infra_services_id

  kubernetes_version             = var.kubernetes_version
  cluster_endpoint_public_access = var.cluster_endpoint_public_access

  infra_node_instance_types      = var.infra_node_instance_types
  app_node_instance_types        = var.app_node_instance_types
  monitoring_node_instance_types = var.monitoring_node_instance_types
  app_node_desired               = var.app_node_desired
  app_node_min                   = var.app_node_min
  app_node_max                   = var.app_node_max

}

# ─── MODULE 3: RDS ───────────────────────────────────────────────────────────
# MySQL 8.4 RDS instance, parameter group, per-service Secrets Manager
# secrets for customers, visits, and vets services.

module "rds" {
  source = "./rds"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment

  # Networking inputs
  vpc_id               = module.networking.vpc_id
  db_subnet_ids        = module.networking.db_subnet_ids
  db_subnet_group_name = module.networking.db_subnet_group_name
  sg_database_id       = module.networking.sg_database_id

  mysql_version            = var.mysql_version
  instance_class           = var.db_instance_class
  multi_az                 = var.db_multi_az
  backup_retention_days    = var.db_backup_retention_days
  deletion_protection      = var.db_deletion_protection
  skip_final_snapshot      = var.db_skip_final_snapshot

}

# ─── MODULE 4: ECR ───────────────────────────────────────────────────────────
# One ECR repository per microservice.
# EKS nodes pull via AmazonEC2ContainerRegistryReadOnly on their node role.
# CI/CD team pushes images using the ecr_push_policy output from this module.

module "ecr" {
  source = "./ecr"

  aws_region   = var.aws_region
  project_name = var.project_name
  environment  = var.environment

  image_tag_mutability = var.ecr_image_tag_mutability
  untagged_expiry_days = var.ecr_untagged_expiry_days
  tagged_image_count   = var.ecr_tagged_image_count
}

# ─── MODULE 5: monitoring ───────────────────────────────────────────────────────────
# This module creates the monitoring using prometheus, grafana and zipkin
# We are using terraform and helm for all the above installations.
# For each of the microservice it opens the path at /actuator/prometheus
# these will monitor varios resources like clusters,  nodegroups etc, along with all the 8 microservices.

module "monitoring" {
  source = "./monitoring"
  prometheus-values = file("${path.module}/../observability/prometheus/values.yml")
  services = {
    "api-gateway" = {
      port = "http"
      path = "/actuator/prometheus"
    }
    "customers-service" = {
      port = "http"
      path = "/actuator/prometheus"
    }
    "vets-service" = {
      port = "http"
      path = "/actuator/prometheus"
    }
    "visits-service" = {
      port = "http"
      path = "/actuator/prometheus"
    }
    "config-server" = {
      port = "http"
      path = "/actuator/prometheus"
    }
    "discovery-server" = {
      port = "http"
      path = "/actuator/prometheus"
    }
    "admin-server" = {
      port = "http"
      path = "/actuator/prometheus"
    }
    "genai-service" = {
      port = "http"
      path = "/actuator/prometheus"
    }
  }
}
