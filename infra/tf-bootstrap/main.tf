# ============================================================
# Pollflow Bootstrap - Main Entry Point
# ============================================================
# 
# This bootstrap creates the foundation for the Pollflow project:
# - IAM role (no static credentials - uses AssumeRole)
# - S3 bucket for Terraform state storage
# - Auto-generated configuration files for main project
#
# Files:
# - providers.tf      : AWS provider and data sources
# - iam.tf            : IAM role and policies
# - state-backend.tf  : S3 bucket for Terraform state storage
# - generated-files.tf: Auto-generated helper files
# - variables.tf      : Input variables
# - outputs.tf        : Output values
#
# Usage:
#   terraform init
#   terraform apply
#
# Note: Run this ONCE with admin credentials, main project uses role assumption
# ============================================================

