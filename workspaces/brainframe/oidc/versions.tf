terraform {
  required_version = ">= 1.9"

  cloud {
    organization = "liquidzoo"

    workspaces {
      project = "brainframe"
      name    = "oidc"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}