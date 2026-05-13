# ─── LOCALS ────────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Extract OIDC provider from issuer URL (remove https://)
  oidc_provider = replace(var.cluster_oidc_issuer_url, "https://", "")
}

# ─── AWS LOAD BALANCER CONTROLLER HELM CHART ────────────────────────────────
# This Helm chart deploys the controller that manages ALBs based on Ingress resources

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_load_balancer_controller_chart_version

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.aws_region
      vpcId       = var.vpc_id

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
      }

      replicaCount = var.alb_controller_replicas

      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }

      enableShield       = var.enable_shield
      enableWaf          = var.enable_waf
      enableWafv2        = var.enable_wafv2
      logLevel           = var.alb_controller_log_level

      # Pod disruption budget (ensures availability during updates)
      podDisruptionBudget = {
        maxUnavailable = 1
      }

      # Node affinity for better pod distribution
      affinity = {
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchExpressions = [
                    {
                      key      = "app.kubernetes.io/name"
                      operator = "In"
                      values   = ["aws-load-balancer-controller"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }

      # Security context for hardened pods
      securityContext = {
        allowPrivilegeEscalation = false
        readOnlyRootFilesystem   = true
        capabilities = {
          drop = ["ALL"]
        }
      }

      # Tags applied to ALBs/TGs created by this controller
      tags = {
        Environment = var.environment
        Project     = var.project_name
        ManagedBy   = "Terraform"
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller,
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
  ]
}

# ─── INGRESS CLASS ──────────────────────────────────────────────────────────
# Defines the controller handling ingresses

resource "kubernetes_ingress_class" "aws_load_balancer" {
  metadata {
    name = "aws-load-balancer-controller"

    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    controller = "ingress.k8s.aws/alb"
  }

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

# ─── ALB SECURITY GROUP ────────────────────────────────────────────────────
# Accepts HTTP/HTTPS traffic from internet
# This SG is created by the controller automatically, but we create one to reference

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for ALB created by AWS Load Balancer Controller"
  vpc_id      = var.vpc_id

  # Allow HTTP from internet
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS from internet (for when TLS is enabled)
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic to reach EKS nodes
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── SECURITY GROUP RULES FOR EKS NODES ──────────────────────────────────────
# Allow ALB to reach node service ports (targets for ingress)

resource "aws_security_group_rule" "alb_to_eks_nodes_http" {
  description              = "Allow ALB to reach EKS nodes on HTTP service ports"
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8999
  protocol                 = "tcp"
  security_group_id        = var.eks_nodes_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_to_eks_nodes_9000_range" {
  description              = "Allow ALB to reach EKS nodes on extended service ports"
  type                     = "ingress"
  from_port                = 9000
  to_port                  = 9999
  protocol                 = "tcp"
  security_group_id        = var.eks_nodes_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

# ─── ALLOW EKS CLUSTER TO REACH ALB ────────────────────────────────────────
# For health checks and cluster-initiated connections

resource "aws_security_group_rule" "eks_cluster_to_alb" {
  description              = "Allow EKS cluster to reach ALB"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = var.eks_cluster_security_group_id
}
