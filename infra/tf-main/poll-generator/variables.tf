variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_id" {
  description = "VPC ID where Lambda will run"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda (needs VPC access for RDS)"
  type        = list(string)
}

# ============================================================
# RDS Connection Info
# ============================================================

variable "rds_host" {
  description = "RDS database host address"
  type        = string
}

variable "rds_port" {
  description = "RDS database port"
  type        = number
  default     = 5432
}

variable "rds_dbname" {
  description = "RDS database name"
  type        = string
}

variable "rds_security_group_id" {
  description = "RDS security group ID (to allow Lambda ingress)"
  type        = string
}

# ============================================================
# Secrets Manager Secret Names
# ============================================================

variable "rds_secret_name" {
  description = "Name/ARN pattern of RDS credentials secret in Secrets Manager"
  type        = string
  default     = "rds!db-707a2143-ee96-49b7-9c9a-f7f0f445f5bd"
}

variable "openrouter_secret_name" {
  description = "Name of OpenRouter API key secret in Secrets Manager"
  type        = string
  default     = "pollflow/openrouter-key"
}

variable "newsapi_secret_name" {
  description = "Name of NewsAPI key secret in Secrets Manager"
  type        = string
  default     = "pollflow/newsapi-key"
}

# Lambda configuration
variable "lambda_memory_size" {
  description = "Lambda memory in MB"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 300
}

# Poll generator configuration
variable "schedule_window_hours" {
  description = "Time window for scheduling polls (hours)"
  type        = number
  default     = 2
}

variable "target_polls_per_run" {
  description = "Target number of polls to generate per run"
  type        = number
  default     = 24
}

variable "article_count" {
  description = "Number of articles to fetch from NewsAPI"
  type        = number
  default     = 35
}

variable "similarity_threshold" {
  description = "Similarity threshold for deduplication (0.0-1.0)"
  type        = number
  default     = 0.8
}

variable "poll_duration_hours" {
  description = "Poll duration in hours"
  type        = number
  default     = 12
}

variable "llm_model" {
  description = "LLM model to use for poll generation"
  type        = string
  default     = "google/gemma-4-26b-a4b-it"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
