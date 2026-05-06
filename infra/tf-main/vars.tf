variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Name of the project (used for tagging and naming resources)"
  type        = string
  default     = "cloudpollpro"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (costs ~$32/month per AZ). Required for EKS nodes to access internet."
  type        = bool
  default     = true
}
