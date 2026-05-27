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


# ECR Outputs
output "ecr_repository_urls" {
  description = "Map of ECR repository names to their URLs"
  value       = module.ecr.repository_urls
}

output "ecr_registry_id" {
  description = "The registry ID where the repositories were created"
  value       = module.ecr.registry_id
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

# EKS Add-ons Outputs
output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role used by EBS CSI driver"
  value       = module.eks_addons.ebs_csi_driver_role_arn
}

output "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon installed"
  value       = module.eks_addons.ebs_csi_driver_addon_version
}

# RDS Outputs
output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance (host:port)"
  value       = module.rds.db_endpoint
}

output "rds_address" {
  description = "The hostname of the RDS instance"
  value       = module.rds.db_address
}

output "rds_port" {
  description = "The port the database is listening on"
  value       = module.rds.db_port
}

output "rds_database_name" {
  description = "The name of the database"
  value       = module.rds.db_name
}

output "rds_username" {
  description = "The master username for the database"
  value       = module.rds.db_username
  sensitive   = true
}

output "rds_master_user_secret_arn" {
  description = "ARN of the RDS-managed master user secret (with automatic rotation)"
  value       = module.rds.db_master_user_secret_arn
}


output "rds_connection_command" {
  description = "Command to connect to RDS from bastion (requires postgresql-client)"
  value       = "psql -h ${module.rds.db_address} -U ${module.rds.db_username} -d ${module.rds.db_name}"
  sensitive   = true
}

# Poll Generator Outputs
output "poll_generator_lambda_arn" {
  description = "ARN of the poll generator Lambda function"
  value       = module.poll_generator.lambda_function_arn
}

output "poll_generator_lambda_name" {
  description = "Name of the poll generator Lambda function"
  value       = module.poll_generator.lambda_function_name
}

output "poll_generator_eventbridge_rule" {
  description = "Name of the EventBridge schedule rule"
  value       = module.poll_generator.eventbridge_rule_name
}

