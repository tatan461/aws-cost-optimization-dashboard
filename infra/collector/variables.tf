variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used as a prefix for resource names"
  type        = string
  default     = "cost-optimization-dashboard"
}

variable "dashboard_bucket_name" {
  description = "Name of the S3 bucket (created in infra/dashboard) where the collector writes latest.json"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge Scheduler expression for how often the collector runs"
  type        = string
  default     = "rate(1 day)"
}