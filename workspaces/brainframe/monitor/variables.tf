variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "schedule_expression" {
  description = "EventBridge rate/cron for the probe."
  type        = string
  default     = "rate(15 minutes)"
}

variable "stats_url" {
  description = "Catalog /stats endpoint for the freshness check. Empty string disables it."
  type        = string
  default     = "https://api.patcherctl.dev/stats"
}

variable "freshness_max_age_hours" {
  description = "Alert if the catalog's last_refresh is older than this many hours (daily refresh + headroom)."
  type        = number
  default     = 26
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
