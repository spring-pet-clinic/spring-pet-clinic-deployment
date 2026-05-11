output "repository_urls" {
  description = "ECR repository URLs keyed by service name — use these as image references in Kubernetes manifests"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "repository_arns" {
  description = "ECR repository ARNs keyed by service name"
  value       = { for k, v in aws_ecr_repository.services : k => v.arn }
}

output "registry_url" {
  description = "ECR registry base URL (account-id.dkr.ecr.region.amazonaws.com)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_push_policy_arn" {
  description = "IAM policy ARN to attach to the CI/CD role for push access"
  value       = aws_iam_policy.ecr_push.arn
}
