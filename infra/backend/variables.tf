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

variable "github_repo" {
  description = "GitHub repository in the form owner/repo, used to scope the OIDC trust policy"
  type        = string
  default     = "tatan461/aws-cost-optimization-dashboard"
}