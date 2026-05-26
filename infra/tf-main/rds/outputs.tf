# ============================================================================
# RDS Instance Outputs
# ============================================================================

output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = module.rds.db_instance_identifier
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = module.rds.db_instance_arn
}

output "db_endpoint" {
  description = "The connection endpoint (host:port)"
  value       = module.rds.db_instance_endpoint
}

output "db_address" {
  description = "The hostname of the RDS instance"
  value       = module.rds.db_instance_address
}

output "db_port" {
  description = "The port the database is listening on"
  value       = module.rds.db_instance_port
}

output "db_name" {
  description = "The name of the database"
  value       = module.rds.db_instance_name
}

output "db_username" {
  description = "The master username for the database"
  value       = module.rds.db_instance_username
  sensitive   = true
}

# ============================================================================
# RDS-Managed Secret Outputs (auto-rotates every 7 days)
# ============================================================================

output "db_master_user_secret_arn" {
  description = "ARN of the RDS-managed master user secret (with automatic rotation)"
  value       = module.rds.db_instance_master_user_secret_arn
}

# Removed db_master_user_secret_name - use ARN directly instead (cleaner, no string manipulation needed)

# ============================================================================
# Network Outputs
# ============================================================================

output "db_security_group_id" {
  description = "The security group ID of the RDS instance"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "The name of the database subnet group"
  value       = aws_db_subnet_group.this.name
}
