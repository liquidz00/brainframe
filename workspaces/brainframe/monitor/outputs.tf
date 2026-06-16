output "function_name" {
  description = "Lambda function name (handy for `aws lambda invoke`)."
  value       = aws_lambda_function.monitor.function_name
}

output "log_group" {
  description = "CloudWatch log group for the probe."
  value       = aws_cloudwatch_log_group.lambda.name
}

output "status_table" {
  description = "DynamoDB table holding last-known status per target."
  value       = aws_dynamodb_table.status.name
}

output "slack_webhook_param" {
  description = "SSM parameter the Lambda reads the webhook from. Populate it once before the first run."
  value       = local.slack_webhook_name
}
