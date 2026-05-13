# ─── IAM POLICY FOR AWS LOAD BALANCER CONTROLLER ────────────────────────────
# This policy allows the controller pods to create/manage ALBs and target groups

data "aws_iam_policy_document" "aws_load_balancer_controller" {
  statement {
    sid       = "AWSLoadBalancerController"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:*"]
    resources = ["*"]
  }

  statement {
    sid    = "EC2Permissions"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeVpcs",
      "ec2:GetCoipPoolUsage",
      "ec2:ModifyNetworkInterfaceAttribute",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EKS"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecurityGroupManagement"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TagManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${local.name_prefix}-alb-controller-policy"
  path        = "/"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller.json

  tags = {
    Name = "${local.name_prefix}-alb-controller-policy"
  }
}

# ─── IAM ROLE FOR SERVICE ACCOUNT ────────────────────────────────────────────
# Trust policy allows the kube-system:aws-load-balancer-controller service account
# to assume this role using OIDC

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    sid     = "AssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${local.name_prefix}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = {
    Name = "${local.name_prefix}-alb-controller-role"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# ─── SERVICE ACCOUNT IN KUBERNETES ───────────────────────────────────────────

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

# ─── GET CURRENT AWS ACCOUNT ID AND OIDC INFO ──────────────────────────────

data "aws_caller_identity" "current" {}
