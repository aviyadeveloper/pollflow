# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "vpc_private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}


# Bastion Outputs
output "bastion_ssh_command" {
  description = "Ready-to-use SSH command to connect to bastion (just copy and paste!)"
  value       = module.bastion.ssh_command
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = module.bastion.bastion_public_ip
}

output "bastion_key_location" {
  description = "Location of the private SSH key"
  value       = module.bastion.private_key_path
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host"
  value       = module.bastion.bastion_instance_id
}

output "bastion_connection_details" {
  description = "Complete connection details for the bastion host"
  value       = module.bastion.connection_details
}

# EKS Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "eks_configure_kubectl" {
  description = "Command to configure kubectl"
  value       = module.eks.configure_kubectl
}
