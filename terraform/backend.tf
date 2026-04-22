terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "REPLACE_WITH_TF_STATE_BUCKET"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "taskapp-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "kops-admin"
}
