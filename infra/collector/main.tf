data "archive_file" "collector_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/collector"
  output_path = "${path.module}/build/collector.zip"
  excludes    = ["requirements.txt", "__pycache__"]
}

resource "aws_lambda_function" "collector" {
  function_name = "${var.project_name}-collector"
  role          = aws_iam_role.collector_lambda.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.collector_zip.output_path
  source_code_hash = data.archive_file.collector_zip.output_base64sha256

  environment {
    variables = {
      DASHBOARD_BUCKET = var.dashboard_bucket_name
      REPORT_KEY       = "data/latest.json"
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "collector" {
  name              = "/aws/lambda/${aws_lambda_function.collector.function_name}"
  retention_in_days = 14
}

resource "aws_scheduler_schedule" "collector_daily" {
  name       = "${var.project_name}-collector-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.schedule_expression

  target {
    arn      = aws_lambda_function.collector.arn
    role_arn = aws_iam_role.scheduler_invoke_collector.arn
  }
}