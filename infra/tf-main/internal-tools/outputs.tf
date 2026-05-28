output "instance_id" {
  description = "ID of the internal tools EC2 instance"
  value       = aws_instance.internal_tools.id
}

output "public_ip" {
  description = "Elastic IP address of the internal tools instance"
  value       = aws_eip.internal_tools.public_ip
}

output "private_ip" {
  description = "Private IP address of the internal tools instance"
  value       = aws_instance.internal_tools.private_ip
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${aws_eip.internal_tools.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus UI URL"
  value       = "http://${aws_eip.internal_tools.public_ip}:9090"
}

output "grafana_password_secret_name" {
  description = "AWS Secrets Manager secret name containing Grafana admin password"
  value       = aws_secretsmanager_secret.grafana_password.name
}

output "grafana_password_retrieval_command" {
  description = "AWS CLI command to retrieve Grafana admin password"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.grafana_password.name} --query SecretString --output text"
}

output "security_group_id" {
  description = "Security group ID for the internal tools instance"
  value       = aws_security_group.internal_tools.id
}
