# brainframe

A personal AWS + Terraform playground. Each directory under `workspaces/` is an independent root configuration with its state in [HCP Terraform](https://app.terraform.io) (organization `liquidzoo`, project `brainframe`) — one HCP workspace per directory.

## Layout

### `workspaces/brainframe/oidc/`

Bootstraps the AWS IAM OIDC trust that lets HCP run Terraform against AWS **without long-lived keys**: an OpenID Connect provider for `app.terraform.io` plus an IAM role (`brainframe-hcp-monitor`) whose trust policy is scoped to only the `monitor` workspace. It runs **locally** with an SSO profile, since it creates the very role that remote runs depend on (chicken-and-egg).

### `workspaces/brainframe/monitor/`

A serverless uptime monitor for [Patcher](https://github.com/liquidz00/Patcher). An EventBridge schedule invokes a Python Lambda every 15 minutes; the Lambda probes the public endpoints (`api`, `mcp`) plus catalog freshness (via `/stats`), records last-known status per check in DynamoDB, and posts to Slack only on a transition (one alert when something goes down, one when it recovers). It runs off-site, so it survives both a Linode outage and a home-internet outage. Its plans and applies run **remotely on HCP**, authenticating to AWS via the OIDC role above.

Stack: Lambda, EventBridge, DynamoDB, SSM Parameter Store, IAM — all in Terraform.

## Prerequisites

- Terraform >= 1.9 and an HCP Terraform account (`terraform login`)
- AWS CLI v2 with an SSO profile named `patcher` (used by the local `oidc` workspace and the one-time SSM step; override via `-var aws_profile=...`)
- A Slack incoming webhook URL

## First-time setup

1. **Create the OIDC trust (local, run once):**

   ```bash
   cd workspaces/brainframe/oidc
   aws sso login --profile patcher
   terraform init
   terraform apply
   terraform output monitor_role_arn        # copy this
   ```

2. **Point `monitor` at the role.** In the HCP `monitor` workspace, add two **environment** variables — `TFC_AWS_PROVIDER_AUTH = true` and `TFC_AWS_RUN_ROLE_ARN = <the role ARN>` — and set Execution Mode to **Remote**. Remote runs now assume the role via OIDC; no static credentials anywhere.

3. **Store the Slack webhook** as a SecureString (kept out of Terraform state):

   ```bash
   aws ssm put-parameter \
     --name /brainframe/monitor/slack_webhook \
     --type SecureString \
     --value 'https://hooks.slack.com/services/XXX/YYY/ZZZ' \
     --profile patcher --region us-east-1
   ```

## Deploy the monitor

```bash
cd workspaces/brainframe/monitor
terraform init
terraform plan      # executes remotely on HCP via OIDC
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
cd workspaces/brainframe/monitor
terraform destroy        # removes everything except the SSM parameter
aws ssm delete-parameter --name /brainframe/monitor/slack_webhook \
  --profile patcher --region us-east-1
```

## Cost

Everything sits inside the AWS free tier by a wide margin (~96 Lambda invocations/day, on-demand DynamoDB, one SSM parameter), and HCP Terraform remote runs are free-tier. Expected cost: **$0**.
