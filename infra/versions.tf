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
  }

  # Remote state, not local — this stack holds RDS/ASG/IAM resources
  # that must never be re-created from an empty local state file.
  backend "s3" {
    bucket         = "REPLACE-WITH-tfstate-bucket"
    key            = "aws-eks-cicd-capstone/primary/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "REPLACE-WITH-tf-lock-table"
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
