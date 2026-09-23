resource "random_id" "dashboard_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "dashboard" {
  bucket = "${var.project_name}-site-${random_id.dashboard_suffix.hex}"

  tags = {
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- CloudFront Origin Access Control (OAC) ---
# Only CloudFront is allowed to read from the private S3 bucket.
resource "aws_cloudfront_origin_access_control" "dashboard" {
  name                              = "${var.project_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "dashboard" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.dashboard.bucket_regional_domain_name
    origin_id                = "s3-dashboard-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.dashboard.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-dashboard-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Short TTL: the dashboard data (data/latest.json) updates daily, and we
    # want visitors to see fresh numbers without a manual invalidation.
    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project = var.project_name
  }
}

data "aws_iam_policy_document" "dashboard_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.dashboard.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.dashboard.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  policy = data.aws_iam_policy_document.dashboard_bucket_policy.json
}

# --- Upload static frontend files (index.html, style.css, script.js) ---
locals {
  dashboard_src_dir = "${path.module}/../../src/dashboard"
  mime_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
  }
}

resource "aws_s3_object" "dashboard_files" {
  for_each = fileset(local.dashboard_src_dir, "**")

  bucket       = aws_s3_bucket.dashboard.id
  key          = each.value
  source       = "${local.dashboard_src_dir}/${each.value}"
  etag         = filemd5("${local.dashboard_src_dir}/${each.value}")
  content_type = lookup(local.mime_types, regex("[.][^.]+$", each.value), "application/octet-stream")
}