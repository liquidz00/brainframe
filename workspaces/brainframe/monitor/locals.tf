locals {
  function_name = "brainframe-monitor"

  # Created out-of-band so the webhook value never lands in Terraform state.
  # Terraform only references its ARN to grant the Lambda read access.
  slack_webhook_name = "/brainframe/monitor/slack_webhook"
  slack_webhook_arn  = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${local.slack_webhook_name}"
}