output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for ALB controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "alb_controller_role_name" {
  description = "IAM role name for ALB controller"
  value       = aws_iam_role.aws_load_balancer_controller.name
}

output "ingress_class_name" {
  description = "Kubernetes IngressClass name to use in manifests"
  value       = kubernetes_ingress_class.aws_load_balancer.metadata[0].name
}

output "helm_chart_version" {
  description = "Deployed Helm chart version"
  value       = helm_release.aws_load_balancer_controller.version
}

output "service_account_name" {
  description = "Kubernetes service account name for ALB controller"
  value       = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
}

output "service_account_namespace" {
  description = "Kubernetes namespace for ALB controller"
  value       = kubernetes_service_account.aws_load_balancer_controller.metadata[0].namespace
}
