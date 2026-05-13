output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = aws_security_group.cluster.id
}

output "cluster_shared_security_group_id" {
  description = "AWS-managed shared security group ID attached to both EKS control plane and worker nodes"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS worker nodes"
  value       = aws_security_group.nodes.id
}

output "node_group_role_arn" {
  description = "IAM role ARN used by all node groups"
  value       = aws_iam_role.node_group.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (used to create IRSA service accounts)"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer (used for IRSA)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "infra_node_group_name" {
  description = "Name of the infra node group (Config Server, Eureka)"
  value       = aws_eks_node_group.infra.node_group_name
}

output "app_node_group_name" {
  description = "Name of the app node group (microservices)"
  value       = aws_eks_node_group.app.node_group_name
}

output "monitoring_node_group_name" {
  description = "Name of the monitoring node group"
  value       = aws_eks_node_group.monitoring.node_group_name
}

output "kubeconfig_command" {
  description = "AWS CLI command to update kubeconfig for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
