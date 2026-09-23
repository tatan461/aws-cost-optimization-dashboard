output "collector_function_name" {
  description = "Name of the collector Lambda function"
  value       = aws_lambda_function.collector.function_name
}

output "collector_function_arn" {
  description = "ARN of the collector Lambda function"
  value       = aws_lambda_function.collector.arn
}