# ============================================================================
# Lambda Outputs
# ============================================================================

output "lambda_function_arn" {
  description = "ARN of the poll generator Lambda function"
  value       = aws_lambda_function.poll_generator.arn
}

output "lambda_function_name" {
  description = "Name of the poll generator Lambda function"
  value       = aws_lambda_function.poll_generator.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.poll_generator.arn
}

output "lambda_package_bucket" {
  description = "S3 bucket containing Lambda deployment packages"
  value       = aws_s3_bucket.lambda_packages.id
}

output "lambda_package_key" {
  description = "S3 key for the Lambda package"
  value       = aws_s3_object.lambda_package.key
}

# ============================================================================
# EventBridge Outputs
# ============================================================================

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge schedule rule"
  value       = aws_cloudwatch_event_rule.poll_generator_schedule.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge schedule rule"
  value       = aws_cloudwatch_event_rule.poll_generator_schedule.name
}

# ============================================================================
# Secret ARNs (for reference)
# ============================================================================

output "rds_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = data.aws_secretsmanager_secret.rds.arn
}

output "openrouter_secret_arn" {
  description = "ARN of the OpenRouter API key secret"
  value       = data.aws_secretsmanager_secret.openrouter.arn
}

output "newsapi_secret_arn" {
  description = "ARN of the NewsAPI key secret"
  value       = data.aws_secretsmanager_secret.newsapi.arn
}
