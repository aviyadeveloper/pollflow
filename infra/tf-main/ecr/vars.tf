variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["frontend", "poll-broker"]
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "lifecycle_policy_keep_count" {
  description = "Number of images to keep in repository"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Additional tags for ECR resources"
  type        = map(string)
  default     = {}
}
