terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # Remote state, not local — this stack holds RDS/ASG/IAM resources
  # that must never be re-created from an empty local state file.
  backend "s3" {
    bucket         = "aws-eks-cicd-capstone-tfstate-460223322833"
    key            = "aws-eks-cicd-capstone/primary/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "aws-eks-cicd-capstone-tflock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "appointments"
      ManagedBy = "terraform"
    }
  }
}
