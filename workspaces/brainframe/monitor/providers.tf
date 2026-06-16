provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "brainframe"
      Component = "monitor"
      ManagedBy = "terraform"
    }
  }
}
