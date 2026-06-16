terraform {
  required_version = ">= 1.9"

  cloud {
    organization = "liquidzoo"

    workspaces {
      project = "brainframe"
      name    = "monitor"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}
