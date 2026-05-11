terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "petclinic-tfstate-rj79q8aw"
    key            = "root/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "petclinic-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "tls" {}

provider "random" {}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
} 

provider "kubernetes" {
  host = module.eks.cluster_endpoint

  cluster_ca_certificate = base64decode(
    module.eks.cluster_certificate_authority
  )

  token = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host = module.eks.cluster_endpoint

    cluster_ca_certificate = base64decode(
      module.eks.cluster_certificate_authority
    )

    token = data.aws_eks_cluster_auth.this.token
  }
}