terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.37.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.1.0"
    }
  }
  required_version = ">= 0.13"
}
