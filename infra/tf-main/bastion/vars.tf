variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 instance to use for the bastion host"
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
  description = "VPC ID where bastion will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where bastion will be deployed"
  type        = string
}

variable "keys_path" {
  description = "Path to store SSH keys"
  type        = string
  default     = ".keys"
}
