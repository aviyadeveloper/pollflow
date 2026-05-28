variable "vpc_id" {
  description = "VPC ID where the internal tools instance will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the internal tools instance"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group ID of the bastion host for SSH access"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for internal access rules"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 50
}

variable "key_name" {
  description = "Name of the SSH key pair for instance access"
  type        = string
}
