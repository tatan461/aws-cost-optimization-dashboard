output "tfstate_bucket" {
  description = "S3 bucket name holding the Terraform remote state"
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_actions_role_arn" {
  description = "IAM role ARN GitHub Actions assumes via OIDC"
  value       = aws_iam_role.github_actions_deploy.arn
}