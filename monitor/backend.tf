# Remote state in the bucket created by ../bootstrap. Backend blocks can't use
# variables, so the bucket name is a literal: paste the bootstrap `state_bucket`
# output below, then run `terraform init -migrate-state` once to move local state.
# use_lockfile is native S3 locking (Terraform >= 1.10), no DynamoDB table needed.
terraform {
  backend "s3" {
    bucket       = "brainframe-tfstate-317429619345"
    key          = "monitor/terraform.tfstate"
    region       = "us-east-1"
    profile      = "patcher"
    encrypt      = true
    use_lockfile = true
  }
}
