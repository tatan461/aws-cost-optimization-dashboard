# --- GitHub Actions OIDC provider (reused) ---
# This AWS account already has the GitHub OIDC provider created by the
# cloud-resume-ai project (one provider per URL is allowed per account).
# We reference it here instead of creating a new one, to avoid an
# IamOpenIdConnectProviderAlreadyExists error.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "${var.project_name}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Project = var.project_name
  }
}

# Scoped, read-mostly deploy policy. Cost Explorer and Compute Optimizer are
# read-only by design (Get*/Describe*), everything else is limited to the
# services this project actually creates: S3, CloudFront, Lambda, IAM (for
# the Lambda's own role), and EventBridge Scheduler.
data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid    = "TerraformStateAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]
  }

  statement {
    sid    = "CostVisibilityReadOnly"
    effect = "Allow"
    actions = [
      "ce:Get*",
      "ce:Describe*",
      "compute-optimizer:Get*",
      "compute-optimizer:Describe*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AppInfrastructure"
    effect = "Allow"
    actions = [
      "s3:*",
      "cloudfront:*",
      "lambda:*",
      "scheduler:*",
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:TagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetRolePolicy",
      "logs:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${var.project_name}-deploy-policy"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}