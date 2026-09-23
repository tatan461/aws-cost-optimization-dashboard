output "dashboard_bucket_name" {
  description = "S3 bucket name hosting the static dashboard (used as input by infra/collector)"
  value       = aws_s3_bucket.dashboard.bucket
}

output "cloudfront_domain_name" {
  description = "Public CloudFront URL for the dashboard"
  value       = aws_cloudfront_distribution.dashboard.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID, useful for cache invalidations"
  value       = aws_cloudfront_distribution.dashboard.id
}