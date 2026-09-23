terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "cost-optimization-dashboard-tfstate-77cc9b41"
    key    = "dashboard/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# CloudFront requires ACM certificates in us-east-1 regardless of where the
# distribution's origin lives. We are not using a custom domain/ACM cert
# here (default *.cloudfront.net domain), so this provider alias is kept
# only for consistency with future custom-domain setups.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}