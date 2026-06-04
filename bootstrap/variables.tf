variable "state_bucket_name" {
  description = "Globally-unique S3 bucket for Terraform state. Empty derives one from the account ID."
  type        = string
  default     = ""
}
