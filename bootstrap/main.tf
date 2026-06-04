data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "brainframe-tfstate-${data.aws_caller_identity.current.account_id}"
}

# Holds remote Terraform state for every project in this repo. Created on its own
# because the backend bucket can't store the state of its own creation, so this
# config keeps local state while the other projects move into the bucket.
resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name
}

# Versioning is the safety net: every state write keeps a recoverable prior version.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
