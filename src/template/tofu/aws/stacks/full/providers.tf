terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.4"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = var.name
      Stack   = "full"
      Managed = "opentofu"
    }
  }
}
