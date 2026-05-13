# ─── INFRA NODE GROUP ────────────────────────────────────────────────────────
# Runs: Config Server (8888), Discovery Server / Eureka (8761)

resource "aws_eks_node_group" "infra" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-infra-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.infra_node_instance_types
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version_number
  }

  scaling_config {
    desired_size = var.infra_node_desired
    min_size     = var.infra_node_min
    max_size     = var.infra_node_max
  }

  update_config {
    max_unavailable = 1
  }

  # Taint so only infra workloads are scheduled here
  taint {
    key    = "workload"
    value  = "infra"
    effect = "NO_SCHEDULE"
  }

  labels = {
    workload = "infra"
    role     = "config-discovery"
  }

  tags = {
    Name = "${local.name_prefix}-infra-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_readonly,
  ]
}

# ─── APP NODE GROUP ──────────────────────────────────────────────────────────
# Runs: API Gateway (8080), Customers (8081), Visits (8082), Vets (8083), GenAI (8084)

resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-app-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.app_node_instance_types
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version_number
  }

  scaling_config {
    desired_size = var.app_node_desired
    min_size     = var.app_node_min
    max_size     = var.app_node_max
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "app"
    role     = "microservices"
  }

  tags = {
    Name = "${local.name_prefix}-app-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_readonly,
  ]
}

# ─── MONITORING NODE GROUP ───────────────────────────────────────────────────
# Runs: Admin Server (9090), Prometheus (9091), Zipkin (9411), Grafana (3030)

resource "aws_eks_node_group" "monitoring" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-monitoring-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.monitoring_node_instance_types
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version_number
  }

  scaling_config {
    desired_size = var.monitoring_node_desired
    min_size     = var.monitoring_node_min
    max_size     = var.monitoring_node_max
  }

  update_config {
    max_unavailable = 1
  }

  taint {
    key    = "workload"
    value  = "monitoring"
    effect = "NO_SCHEDULE"
  }

  labels = {
    workload = "monitoring"
    role     = "observability"
  }

  tags = {
    Name = "${local.name_prefix}-monitoring-nodes"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_readonly,
  ]
}
