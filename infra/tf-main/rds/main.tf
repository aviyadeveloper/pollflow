# ============================================================================
# Network Resources
# ============================================================================

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.project_name}-db-subnet-"
  description = "Database subnet group for ${var.project_name}"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name      = "${var.project_name}-db-subnet-group"
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  )
}

# ============================================================================
# RDS PostgreSQL Instance (using community module)
# ============================================================================

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-postgres"

  # Engine
  engine               = "postgres"
  engine_version       = var.engine_version
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database
  db_name                     = var.database_name
  username                    = var.database_username
  manage_master_user_password = true # Use AWS-managed secret with automatic rotation
  port                        = 5432

  # Network
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability
  multi_az = var.multi_az

  # Backup & Maintenance
  backup_retention_period          = var.backup_retention_period
  backup_window                    = var.backup_window
  maintenance_window               = var.maintenance_window
  skip_final_snapshot              = var.skip_final_snapshot
  final_snapshot_identifier_prefix = "${var.project_name}-postgres-final"
  deletion_protection              = var.deletion_protection

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true
  auto_minor_version_upgrade      = true

  tags = merge(
    var.tags,
    {
      Name      = "${var.project_name}-postgres"
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  )
}

# Note: RDS manages its own secret with automatic password rotation.
# Connection details (host, port, dbname) are injected via ConfigMap in K8s.

