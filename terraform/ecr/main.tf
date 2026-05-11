# ─────────────────────────────────────────────────────────────────────────────
# ECR — Elastic Container Registry
#
# One repository per microservice. EKS nodes pull via the
# AmazonEC2ContainerRegistryReadOnly managed policy attached to their node role.
# The CI/CD team pushes images using the ecr_push_policy (see iam.tf).
# ─────────────────────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  services = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "visits-service",
    "vets-service",
    "genai-service",
    "admin-server",
  ]
}

data "aws_caller_identity" "current" {}

# ─── REPOSITORIES ─────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "services" {
  for_each = toset(local.services)

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# ─── LIFECYCLE POLICIES ───────────────────────────────────────────────────────

resource "aws_ecr_lifecycle_policy" "services" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_expiry_days} day(s)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last ${var.tagged_image_count} tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.tagged_image_count
        }
        action = { type = "expire" }
      }
    ]
  })
}
