terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }
  required_version = ">=1.6.6"

  backend "s3" {
    bucket = "tf-iac-state"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = var.project_name
    }
  }
}