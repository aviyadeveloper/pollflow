# ============================================================================
# Required Variables
# ============================================================================

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

# ============================================================================
# Network Variables
# ============================================================================

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS subnet group"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group ID of EKS nodes (for allowing database access)"
  type        = string
}

variable "bastion_security_group_id" {
  description = "Security group ID of bastion host (for allowing database access)"
  type        = string
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.13"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "pollflow"
}

variable "database_username" {
  description = "Master username for the database"
  type        = string
  default     = "pollflow"
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 100
}

# ============================================================================
# High Availability & Backup
# ============================================================================

variable "multi_az" {
  description = "Enable multi-AZ deployment for high availability"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

# ============================================================================
# Protection & Lifecycle
# ============================================================================

variable "deletion_protection" {
  description = "Enable deletion protection (recommended for production)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying (set to false for production)"
  type        = bool
  default     = true
}

# ============================================================================
# Tags
# ============================================================================

variable "tags" {
  description = "Additional tags for RDS resources"
  type        = map(string)
  default     = {}
}

