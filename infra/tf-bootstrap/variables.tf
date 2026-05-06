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
  default     = "cloudpollpro-bootstrap"
}

