# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts["dev"]}:role/stack_prog_aut"
  }
}

# Configure the AWS Provider
provider "aws" {
  alias  = "management"
  region = var.aws_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.accounts["mgmt"]}:role/stack_prog_aut"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.25.0"
    }
  }
}