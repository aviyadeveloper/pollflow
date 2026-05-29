output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role used by EBS CSI driver"
  value       = module.ebs_csi_driver_irsa.iam_role_arn
}

output "ebs_csi_driver_addon_version" {
  description = "Version of the EBS CSI driver addon installed"
  value       = aws_eks_addon.ebs_csi_driver.addon_version
}

output "ebs_csi_driver_addon_arn" {
  description = "ARN of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi_driver.arn
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role used by External Secrets Operator"
  value       = module.external_secrets_irsa.iam_role_arn
}

output "grafana_role_arn" {
  description = "ARN of the IAM role used by Grafana for CloudWatch access"
  value       = module.grafana_irsa.iam_role_arn
}

output "grafana_ingress_hostname" {
  description = "Hostname for accessing Grafana (ALB DNS)"
  value       = try(kubernetes_ingress_v1.grafana.status[0].load_balancer[0].ingress[0].hostname, "pending")
}
