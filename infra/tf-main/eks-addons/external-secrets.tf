# External Secrets Operator IAM Role
# Allows the operator to read secrets from AWS Secrets Manager

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "pollflow-external-secrets"

  # Policy for accessing AWS Secrets Manager
  role_policy_arns = {
    secrets_manager = aws_iam_policy.external_secrets_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["external-secrets-system:external-secrets"]
    }
  }

  tags = {
    Name        = "pollflow-external-secrets"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# IAM Policy for Secrets Manager access
resource "aws_iam_policy" "external_secrets_policy" {
  name        = "pollflow-external-secrets-policy"
  description = "Policy for External Secrets Operator to read from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:pollflow-*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"
      }
    ]
  })

  tags = {
    Name        = "pollflow-external-secrets-policy"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Helm Release for External Secrets Operator
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets-system"
  create_namespace = true
  version          = "2.4.1" # Match current installed version

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.external_secrets_irsa.iam_role_arn
      type  = "string"
    }
  ]

  # Ensure IAM role is created before Helm release
  depends_on = [module.external_secrets_irsa]
}
