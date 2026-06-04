provider "aws" {
  region  = "us-east-1"
  profile = "patcher"

  default_tags {
    tags = {
      Project   = "brainframe"
      Component = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}
