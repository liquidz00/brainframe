data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# The default AWS-managed key SecureString parameters are encrypted under.
data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

# Zip the handler at plan time; source_code_hash triggers redeploys on change.
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/build/handler.zip"
}

# Last-known status per target, so a sustained outage pages once, not every run.
resource "aws_dynamodb_table" "status" {
  name         = "brainframe-monitor-status"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "target"

  attribute {
    name = "target"
    type = "S"
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
  statement {
    sid       = "StatusTable"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.status.arn]
  }
  statement {
    sid       = "ReadWebhook"
    actions   = ["ssm:GetParameter"]
    resources = [local.slack_webhook_arn]
  }
  statement {
    sid       = "DecryptWebhook"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.ssm.target_key_arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

# Declared explicitly so log retention is bounded instead of never-expiring.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "monitor" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      TARGETS             = jsonencode(var.targets)
      DDB_TABLE           = aws_dynamodb_table.status.name
      SLACK_WEBHOOK_PARAM = local.slack_webhook_name
      STATS_URL           = var.stats_url
      FRESH_MAX_AGE_HOURS = tostring(var.freshness_max_age_hours)
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${local.function_name}-schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.monitor.arn
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
