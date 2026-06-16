output "monitor_role_arn" {
  description = "Set this as TFC_AWS_RUN_ROLE_ARN in the monitor workspace."
  value       = aws_iam_role.monitor_runner.arn
}