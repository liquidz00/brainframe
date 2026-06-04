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

variable "schedule_expression" {
  description = "EventBridge rate/cron for the probe."
  type        = string
  default     = "rate(15 minutes)"
}

variable "targets" {
  description = "Endpoints to probe. body_match, if set, is a substring the response body must contain."
  type = list(object({
    name       = string
    url        = string
    body_match = optional(string)
  }))
  default = [
    {
      name       = "api /health"
      url        = "https://api.patcherctl.dev/health"
      body_match = "\"status\":\"ok\""
    },
    {
      name = "mcp"
      url  = "https://mcp.patcherctl.dev/mcp"
    },
  ]
}
