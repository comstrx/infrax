terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.2"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region

  default_labels = {
    project = var.name
    stack   = "light"
    managed = "opentofu"
  }
}
