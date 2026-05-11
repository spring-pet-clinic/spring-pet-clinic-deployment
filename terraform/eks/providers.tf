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
  }

  # backend "s3" {
  #   bucket         = "petclinic-tfstate"
  #   key            = "eks/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "petclinic-tfstate-lock"
  #   encrypt        = true
  # }
}

