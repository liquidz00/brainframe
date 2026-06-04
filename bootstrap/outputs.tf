output "state_bucket" {
  description = "Bucket name to paste into each project's backend block (e.g. monitor/backend.tf)."
  value       = aws_s3_bucket.state.bucket
}
