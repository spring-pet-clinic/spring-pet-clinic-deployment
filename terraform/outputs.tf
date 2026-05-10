# ─── NETWORKING ──────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private app subnets"
  value       = module.networking.private_subnet_ids
}

output "db_subnet_ids" {
  description = "IDs of the isolated database subnets"
  value       = module.networking.db_subnet_ids
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA service account bindings"
  value       = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for the cluster"
  value       = module.eks.kubeconfig_command
}

# ─── RDS ─────────────────────────────────────────────────────────────────────

output "db_endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = module.rds.db_endpoint
}

output "db_address" {
  description = "RDS hostname"
  value       = module.rds.db_address
}

output "db_secret_arns" {
  description = "Secrets Manager ARNs for each service's database credentials"
  value       = module.rds.secret_arns
}

output "customers_secret_arn" {
  description = "Secrets Manager ARN for customers-service DB credentials"
  value       = module.rds.customers_secret_arn
}

output "visits_secret_arn" {
  description = "Secrets Manager ARN for visits-service DB credentials"
  value       = module.rds.visits_secret_arn
}

output "vets_secret_arn" {
  description = "Secrets Manager ARN for vets-service DB credentials"
  value       = module.rds.vets_secret_arn
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

output "ecr_registry_url" {
  description = "ECR registry base URL (account-id.dkr.ecr.region.amazonaws.com)"
  value       = module.ecr.registry_url
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service name — use as image references in Kubernetes manifests"
  value       = module.ecr.repository_urls
}

output "ecr_push_policy_arn" {
  description = "IAM policy ARN to attach to the CI/CD role for ECR push access"
  value       = module.ecr.ecr_push_policy_arn
}
