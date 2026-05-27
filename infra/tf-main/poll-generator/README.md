# Poll Generator Module

Terraform module for deploying the AI-powered poll generator Lambda function with EventBridge scheduling.

## Overview

This module deploys a Lambda function that:
- Fetches news articles from NewsAPI.org (35 articles across 7 categories)
- Generates poll questions using OpenRouter LLM (google/gemma-4-26b-a4b-it)
- Applies quality gates (deduplication + content moderation)
- Schedules 24 polls over 4-hour windows with 10-minute intervals
- Inserts polls to RDS PostgreSQL with status='pending'

**Execution Cadence**: Every 4 hours (6 runs/day) = 144 polls/day total

## Architecture

```
EventBridge (rate 4h) → Lambda (VPC) → [NewsAPI + OpenRouter + RDS]
                                    ↓
                            Secrets Manager (3 secrets)
```

## Resources Created

- **Lambda Function**: `pollflow-poll-generator` (Python 3.12, 512MB, 5min timeout)
- **Security Group**: Allows outbound traffic for external APIs
- **IAM Role**: VPC execution + Secrets Manager access
- **EventBridge Rule**: `rate(4 hours)` schedule
- **EventBridge Target**: Invokes Lambda
- **Lambda Permission**: Allows EventBridge to invoke

## Secrets (via Data Sources)

The module looks up existing secrets by name - **no hardcoded ARNs**:

1. **RDS**: `rds!db-707a2143-ee96-49b7-9c9a-f7f0f445f5bd` (RDS-managed, auto-rotates)
2. **OpenRouter**: `pollflow/openrouter-key` (API key for LLM)
3. **NewsAPI**: `pollflow/newsapi-key` (API key for news)

These must exist before applying this module.

## Usage

```hcl
module "poll_generator" {
  source = "./poll-generator"

  project_name       = var.project_name
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # Optional: override defaults
  schedule_window_hours = 2
  target_polls_per_run  = 24
  similarity_threshold  = 0.8

  tags = {
    Project   = "pollflow"
    ManagedBy = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `project_name` | Project name for resource naming | `string` | - |
| `region` | AWS region | `string` | `"eu-west-3"` |
| `vpc_id` | VPC ID where Lambda runs | `string` | - |
| `private_subnet_ids` | Private subnet IDs for Lambda | `list(string)` | - |
| `rds_secret_name` | RDS secret name in Secrets Manager | `string` | `"rds!db-707a2143..."` |
| `openrouter_secret_name` | OpenRouter secret name | `string` | `"pollflow/openrouter-key"` |
| `newsapi_secret_name` | NewsAPI secret name | `string` | `"pollflow/newsapi-key"` |
| `lambda_memory_size` | Lambda memory in MB | `number` | `512` |
| `lambda_timeout` | Lambda timeout in seconds | `number` | `300` |
| `schedule_window_hours` | Scheduling window (hours) | `number` | `2` |
| `target_polls_per_run` | Polls per run | `number` | `24` |
| `article_count` | Articles to fetch | `number` | `35` |
| `similarity_threshold` | Deduplication threshold (0-1) | `number` | `0.8` |
| `poll_duration_hours` | Poll duration | `number` | `12` |
| `llm_model` | LLM model name | `string` | `"google/gemma-4-26b-a4b-it"` |
| `tags` | Resource tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `lambda_function_arn` | ARN of the Lambda function |
| `lambda_function_name` | Name of the Lambda function |
| `lambda_role_arn` | ARN of the Lambda execution role |
| `eventbridge_rule_arn` | ARN of the EventBridge rule |
| `eventbridge_rule_name` | Name of the EventBridge rule |
| `rds_secret_arn` | ARN of RDS secret (looked up) |
| `openrouter_secret_arn` | ARN of OpenRouter secret |
| `newsapi_secret_arn` | ARN of NewsAPI secret |

## Deployment

### Prerequisites

1. **Build Lambda package** (from `services/poll-generator/`):
   ```bash
   cd services/poll-generator
   ./build.sh
   # Creates lambda-package.zip (84MB)
   ```

2. **Verify secrets exist**:
   ```bash
   aws secretsmanager get-secret-value --secret-id pollflow/openrouter-key --region eu-west-3
   aws secretsmanager get-secret-value --secret-id pollflow/newsapi-key --region eu-west-3
   ```

### Apply Terraform

```bash
cd infra/tf-main
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Verify Deployment

```bash
# Check Lambda
aws lambda get-function --function-name pollflow-poll-generator --region eu-west-3

# Check EventBridge rule
aws events list-rules --name-prefix pollflow-poll-generator --region eu-west-3

# Manual test invocation
aws lambda invoke \
  --function-name pollflow-poll-generator \
  --region eu-west-3 \
  --log-type Tail \
  response.json

# Check logs
aws logs tail /aws/lambda/pollflow-poll-generator --follow --region eu-west-3
```

## Monitoring

**CloudWatch Logs**: `/aws/lambda/pollflow-poll-generator`

**Key Metrics**:
- Execution time (target: < 90s)
- Memory usage (512MB limit)
- Error rate (should be 0%)
- Polls generated per run (24)

## Troubleshooting

### Lambda fails with "Unable to connect to RDS"
- Verify Lambda is in private subnets
- Check security group allows outbound to RDS port 5432
- Verify RDS security group allows inbound from Lambda SG

### "Access denied" to Secrets Manager
- Check IAM role has `secretsmanager:GetSecretValue` permission
- Verify secret ARNs in IAM policy match actual secrets

### Package size error (> 250MB)
- Current package: 84MB (well within limits)
- If exceeds 50MB: Terraform auto-uploads to S3 (no action needed)
- If exceeds 250MB unzipped: Consider Lambda layers

## Cost Estimate

**Per Month** (assuming 180 invocations/month):
- Lambda: ~$0.50 (512MB, 90s avg)
- EventBridge: $0 (free tier covers 1M events/month)
- Secrets Manager: ~$2.40 (3 secrets × $0.40/month + retrievals)
- **Total**: ~$3/month

## Security

- ✅ No hardcoded credentials
- ✅ Secrets in AWS Secrets Manager
- ✅ IAM role with least-privilege permissions
- ✅ VPC isolation for Lambda
- ✅ Encrypted Lambda environment variables
- ✅ CloudWatch Logs for audit trail

## Future Enhancements

See `docs/POLL_GENERATOR_FUTURE_ENHANCEMENTS.md` for planned features:
- International news sources
- Article URL inclusion in polls
- Image support
- Category balancing
- CloudWatch custom metrics dashboard
