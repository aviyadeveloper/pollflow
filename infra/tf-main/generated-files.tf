# Generate RDS config for CI/CD to use when deploying K8s manifests
resource "local_file" "rds_config" {
  filename = "${path.module}/../../.ci/rds-config.env"
  content  = <<-EOF
    RDS_HOST=${module.rds.db_address}
    RDS_PORT=${module.rds.db_port}
    RDS_DBNAME=${module.rds.db_name}
    RDS_MASTER_SECRET=${module.rds.db_master_user_secret_name}
  EOF

  file_permission = "0644"
}
