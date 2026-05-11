locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─── EKS CLUSTER ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = "${local.name_prefix}-eks"
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.cluster_endpoint_public_access
  }

  enabled_cluster_log_types = var.cluster_log_types

  tags = {
    Name = "${local.name_prefix}-eks"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
    aws_cloudwatch_log_group.eks,
  ]
}

# ─── CLOUDWATCH LOG GROUP FOR CONTROL PLANE LOGS ─────────────────────────────

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.name_prefix}-eks/cluster"
  retention_in_days = 30

  tags = {
    Name = "${local.name_prefix}-eks-logs"
  }
}

# ─── CLUSTER SECURITY GROUP ──────────────────────────────────────────────────
# Inline rules intentionally omitted to avoid a cycle with aws_security_group.nodes.
# Cross-referencing rules are added below via aws_security_group_rule resources.

resource "aws_security_group" "cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "EKS cluster control plane communication"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-eks-cluster-sg"
  }
}

# ─── NODE SECURITY GROUP ─────────────────────────────────────────────────────
# Inline rules intentionally omitted to avoid a cycle with aws_security_group.cluster.
# Cross-referencing rules are added below via aws_security_group_rule resources.

resource "aws_security_group" "nodes" {
  name        = "${local.name_prefix}-eks-nodes-sg"
  description = "EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                             = "${local.name_prefix}-eks-nodes-sg"
    "kubernetes.io/cluster/${local.name_prefix}-eks" = "owned"
  }
}

# ─── CROSS-REFERENCING SECURITY GROUP RULES ──────────────────────────────────
# Defined as standalone resources so both SGs can be created before either
# rule is attached, breaking the dependency cycle.

resource "aws_security_group_rule" "nodes_to_cluster_443" {
  description              = "Node groups to cluster API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
}

resource "aws_security_group_rule" "node_to_node" {
  description       = "Node-to-node communication"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nodes.id
  self              = true
}

resource "aws_security_group_rule" "cluster_to_nodes_ephemeral" {
  description              = "Cluster control plane to nodes (ephemeral ports)"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_to_nodes_443" {
  description              = "Cluster API to node kubelets"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
}

# ─── EKS ADD-ONS ─────────────────────────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = "v1.18.1-eksbuild.1"

  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${local.name_prefix}-vpc-cni"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = "v1.11.1-eksbuild.9"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.app]

  tags = {
    Name = "${local.name_prefix}-coredns"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = "v1.30.0-eksbuild.3"

  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${local.name_prefix}-kube-proxy"
  }
}
