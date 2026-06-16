variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI (SSO) profile Terraform authenticates with."
  type        = string
  default     = "patcher"
}
