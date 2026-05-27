# ============================================================================
# Data Sources - Look up secrets by name (no hardcoded ARNs!)
# ============================================================================

data "aws_secretsmanager_secret" "rds" {
  name = var.rds_secret_name
}

data "aws_secretsmanager_secret" "openrouter" {
  name = var.openrouter_secret_name
}

data "aws_secretsmanager_secret" "newsapi" {
  name = var.newsapi_secret_name
}

# ============================================================================
# Security Group for Lambda
# ============================================================================

resource "aws_security_group" "poll_generator" {
  name        = "${var.project_name}-poll-generator-sg"
  description = "Security group for poll generator Lambda function"
  vpc_id      = var.vpc_id

  # Allow all outbound traffic (needed for external APIs: OpenRouter, NewsAPI, RDS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-poll-generator-sg"
    }
  )
}

# Allow Lambda to connect to RDS
resource "aws_security_group_rule" "rds_ingress_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.poll_generator.id
  security_group_id        = var.rds_security_group_id
  description              = "Allow PostgreSQL access from poll generator Lambda"
}

# ============================================================================
# S3 Bucket for Lambda Packages (package is 84MB, exceeds 70MB direct upload limit)
# ============================================================================

resource "aws_s3_bucket" "lambda_packages" {
  bucket = "${var.project_name}-lambda-packages-058264398399"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-lambda-packages"
    }
  )
}

resource "aws_s3_bucket_versioning" "lambda_packages" {
  bucket = aws_s3_bucket.lambda_packages.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lambda_packages" {
  bucket = aws_s3_bucket.lambda_packages.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_object" "lambda_package" {
  bucket      = aws_s3_bucket.lambda_packages.id
  key         = "poll-generator/lambda-package.zip"
  source      = "${path.module}/../../../services/poll-generator/lambda-package.zip"
  source_hash = filebase64sha256("${path.module}/../../../services/poll-generator/lambda-package.zip")

  tags = merge(
    var.tags,
    {
      Name = "poll-generator-lambda-package"
    }
  )
}

# ============================================================================
# Lambda Function
# ============================================================================

resource "aws_lambda_function" "poll_generator" {
  function_name = "${var.project_name}-poll-generator"
  description   = "AI-powered poll generator from news headlines"
  role          = aws_iam_role.poll_generator.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  # Package from S3 (too large for direct upload: 84MB > 70MB limit)
  s3_bucket        = aws_s3_object.lambda_package.bucket
  s3_key           = aws_s3_object.lambda_package.key
  source_code_hash = filebase64sha256("${path.module}/../../../services/poll-generator/lambda-package.zip")

  # VPC configuration (required for RDS access)
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.poll_generator.id]
  }

  # Environment variables
  environment {
    variables = {
      # AWS Secrets Manager ARNs (looked up via data sources)
      RDS_SECRET_ARN        = data.aws_secretsmanager_secret.rds.arn
      OPENROUTER_SECRET_ARN = data.aws_secretsmanager_secret.openrouter.arn
      NEWSAPI_SECRET_ARN    = data.aws_secretsmanager_secret.newsapi.arn

      # RDS Connection Info (from RDS module outputs)
      RDS_HOST   = var.rds_host
      RDS_PORT   = tostring(var.rds_port)
      RDS_DBNAME = var.rds_dbname

      # Scheduling Configuration
      SCHEDULE_WINDOW_HOURS = tostring(var.schedule_window_hours)
      TARGET_POLLS_PER_RUN  = tostring(var.target_polls_per_run)

      # News Fetching Configuration
      ARTICLE_COUNT = tostring(var.article_count)

      # Quality Gates Configuration
      SIMILARITY_THRESHOLD = tostring(var.similarity_threshold)

      # Poll Lifecycle Configuration
      POLL_DURATION_HOURS = tostring(var.poll_duration_hours)

      # LLM Configuration
      LLM_MODEL = var.llm_model
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-poll-generator"
    }
  )
}

# ============================================================================
# EventBridge Schedule (2-hour cadence)
# ============================================================================
# Runs every 2 hours at: 00:00, 02:00, 04:00, 06:00, 08:00, 10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00 UTC
# Cron format: cron(Minutes Hours Day-of-month Month Day-of-week Year)

resource "aws_cloudwatch_event_rule" "poll_generator_schedule" {
  name                = "${var.project_name}-poll-generator-schedule"
  description         = "Trigger poll generator every 2 hours (12 runs/day x 24 polls = 288 polls/day)"
  schedule_expression = "cron(0 0/2 * * ? *)"

  # Note: tags removed due to IAM permission constraints (events:TagResource not available)
}

resource "aws_cloudwatch_event_target" "poll_generator" {
  rule      = aws_cloudwatch_event_rule.poll_generator_schedule.name
  target_id = "PollGeneratorLambda"
  arn       = aws_lambda_function.poll_generator.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.poll_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.poll_generator_schedule.arn
}
