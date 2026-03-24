terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  profile = "dev2"
  region  = var.aws_region
  skip_region_validation = true
  default_tags {
    tags = {
      environment = "Not production"
      classification = "moderate"
    }
  }

}