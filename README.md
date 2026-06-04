# brainframe

A personal AWS + Terraform playground. Each subfolder is an independent project with its own Terraform state.

## Projects

### `monitor/`

A serverless uptime monitor for [Patcher](https://github.com/liquidz00/Patcher). An EventBridge schedule invokes a Python Lambda every 15 minutes; the Lambda probes the public endpoints (`api`, `mcp`), records last-known status per target in DynamoDB, and posts to Slack only on a transition (one alert when something goes down, one when it recovers). It runs off-site, so it survives both a Linode outage and a home-internet outage.

Stack: Lambda, EventBridge, DynamoDB, SSM Parameter Store, IAM, all in Terraform.

## Prerequisites

- Terraform >= 1.9
- AWS CLI v2 with an SSO profile named `patcher` (override via `-var aws_profile=...`)
- A Slack incoming webhook URL

## Deploy the monitor

```bash
cd monitor

# 1. Store the Slack webhook as a SecureString (kept out of Terraform state).
aws ssm put-parameter \
  --name /brainframe/monitor/slack_webhook \
  --type SecureString \
  --value 'https://hooks.slack.com/services/XXX/YYY/ZZZ' \
  --profile patcher --region us-east-1

# 2. Refresh SSO creds, then apply.
aws sso login --profile patcher
terraform init
terraform plan
terraform apply
```

### Test it

```bash
# Invoke once on demand and read the result.
aws lambda invoke --function-name brainframe-monitor \
  --profile patcher --region us-east-1 /dev/stdout
```

To prove the alert path, temporarily point a target's `body_match` at something that won't match (in `variables.tf`), `apply`, invoke, confirm the Slack message, then revert.

## Tear down

```bash
terraform destroy        # removes everything except the SSM parameter
aws ssm delete-parameter --name /brainframe/monitor/slack_webhook \
  --profile patcher --region us-east-1
```

## Cost

Everything sits inside the AWS free tier by a wide margin (~96 Lambda invocations/day, on-demand DynamoDB, one SSM parameter). Expected cost: $0.
