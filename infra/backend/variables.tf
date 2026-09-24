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
  description = "GitHub repository in the form owner/repo, used to scope the OIDC trust policy (classic sub claim format)"
  type        = string
  default     = "tatan461/aws-cost-optimization-dashboard"
}

variable "github_owner_id" {
  description = "Numeric GitHub owner/organization ID, used for the immutable OIDC sub claim format (repos created on/after 2026-07-15)"
  type        = string
  default     = "96512611"
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID, used for the immutable OIDC sub claim format (repos created on/after 2026-07-15)"
  type        = string
  default     = "1384337871"
}