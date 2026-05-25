variable "aws_region" {
  description = "AWS region for the IAM user (region-agnostic, but needed for provider)"
  type        = string
  default     = "eu-west-3"
}

variable "main_project_path" {
  description = "Path to the main terraform project where backend.tf will be created"
  type        = string
  default     = "../tf-main"
}

variable "project_name" {
  description = "Name of the project (used for tagging and naming resources)"
  type        = string
  default     = "pollflow-bootstrap"
}

variable "github_repo_owner" {
  description = "GitHub repository owner/organization (e.g., 'myorg' or 'myuser')"
  type        = string
  default     = "aviyadeveloper"
}

variable "github_repo_name" {
  description = "GitHub repository name (e.g., 'pollflow')"
  type        = string
  default     = "pollflow"
}

