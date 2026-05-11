terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # backend "s3" {
  #   bucket         = "petclinic-tfstate"
  #   key            = "rds/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "petclinic-tfstate-lock"
  #   encrypt        = true
  # }
}

