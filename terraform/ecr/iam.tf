# ─── ECR PUSH POLICY (for CI/CD team) ────────────────────────────────────────
#
# Attach this policy to whichever IAM identity your CI/CD pipeline uses
# (e.g. a GitHub Actions OIDC role or a dedicated IAM user).
# EKS nodes pull via AmazonEC2ContainerRegistryReadOnly on their node role —
# no additional policy is needed on the EKS side.

resource "aws_iam_policy" "ecr_push" {
  name        = "${local.name_prefix}-ecr-push-policy"
  description = "Minimum permissions to authenticate and push images to ${var.project_name} ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
        ]
        Resource = [for repo in aws_ecr_repository.services : repo.arn]
      }
    ]
  })
}
