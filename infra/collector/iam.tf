data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "collector_lambda" {
  name               = "${var.project_name}-collector-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "collector_basic_logs" {
  role       = aws_iam_role.collector_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Read-only: this Lambda never modifies billing, EC2, or any other resource.
# It only reads cost/usage data and writes its own report file to S3.
data "aws_iam_policy_document" "collector_permissions" {
  statement {
    sid    = "CostExplorerReadOnly"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostForecast",
      "ce:GetRightsizingRecommendation",
      "ce:GetDimensionValues",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ComputeOptimizerReadOnly"
    effect = "Allow"
    actions = [
      "compute-optimizer:GetEC2InstanceRecommendations",
      "compute-optimizer:GetLambdaFunctionRecommendations",
      "compute-optimizer:GetEnrollmentStatus",
      "compute-optimizer:GetRecommendationSummaries",
      "compute-optimizer:GetEBSVolumeRecommendations",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "WriteReportToDashboardBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${var.dashboard_bucket_name}/data/*",
    ]
  }
}

resource "aws_iam_role_policy" "collector_permissions" {
  name   = "${var.project_name}-collector-permissions"
  role   = aws_iam_role.collector_lambda.id
  policy = data.aws_iam_policy_document.collector_permissions.json
}

# --- EventBridge Scheduler needs its own role to invoke the Lambda ---
data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler_invoke_collector" {
  name               = "${var.project_name}-scheduler-invoke-collector"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

data "aws_iam_policy_document" "scheduler_invoke_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.collector.arn]
  }
}

resource "aws_iam_role_policy" "scheduler_invoke_permissions" {
  name   = "${var.project_name}-scheduler-invoke-permissions"
  role   = aws_iam_role.scheduler_invoke_collector.id
  policy = data.aws_iam_policy_document.scheduler_invoke_permissions.json
}