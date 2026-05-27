# ============================================================================
# IAM Role for Lambda
# ============================================================================

resource "aws_iam_role" "poll_generator" {
  name        = "${var.project_name}-poll-generator-role"
  description = "IAM role for poll generator Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-poll-generator-role"
    }
  )
}

# ============================================================================
# IAM Policy Attachments
# ============================================================================

# AWS managed policy: Lambda VPC execution (includes CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.poll_generator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy: Secrets Manager access for the 3 secrets
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.project_name}-poll-generator-secrets-access"
  role = aws_iam_role.poll_generator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          data.aws_secretsmanager_secret.rds.arn,
          data.aws_secretsmanager_secret.openrouter.arn,
          data.aws_secretsmanager_secret.newsapi.arn
        ]
      }
    ]
  })
}
