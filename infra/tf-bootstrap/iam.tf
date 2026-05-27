# ============================================================
# IAM Role & Permissions
# Purpose: Create dedicated role with minimal permissions
# Security: Uses AssumeRole instead of static access keys
# ============================================================

########
# ROLE #
########

resource "aws_iam_role" "project_role" {
  name = "${var.project_name}-terraform-role"
  path = "/projects/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowMainUserAssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.project_name
          }
        }
      }
    ]
  })

  tags = {
    Project   = var.project_name
    Purpose   = "Terraform and deployment automation"
    ManagedBy = "terraform"
  }
}

############
# Policies #
############

# S3 - Full permissions for state backend + Lambda packages
resource "aws_iam_role_policy" "s3_policy" {
  name = "S3FullManagement"
  role = aws_iam_role.project_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3FullAccess"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::pollflow*",
          "arn:aws:s3:::pollflow*/*"
        ]
      }
    ]
  })
}

############################################
# Managed Policy Attachments
############################################

# ECR - Container registry management
resource "aws_iam_role_policy_attachment" "ecr_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# EC2 Full Access - VPC, Security Groups, EC2 Instances, networking
resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Auto Scaling - For EKS node groups
resource "aws_iam_role_policy_attachment" "autoscaling_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

# Load Balancing - For ALB/NLB ingress controllers
resource "aws_iam_role_policy_attachment" "elb_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# CloudWatch Logs - For EKS logging
resource "aws_iam_role_policy_attachment" "cloudwatch_logs_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# KMS - For EKS encryption
resource "aws_iam_role_policy_attachment" "kms_power_user" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser"
}

# SSM - For reading EKS AMI parameters
resource "aws_iam_role_policy_attachment" "ssm_readonly" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

############################################
# Custom Policies (no suitable managed policy exists)
############################################

# IAM - Scoped to project resources only
resource "aws_iam_role_policy" "iam_role_management" {
  name = "IAMRoleManagement"
  role = aws_iam_role.project_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:PassRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:CreateServiceLinkedRole",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicies",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:ListPolicyVersions"
        ]
        Resource = [
          "arn:aws:iam::*:role/pollflow*",
          "arn:aws:iam::*:role/projects/pollflow*",
          "arn:aws:iam::*:role/aws-service-role/*",
          "arn:aws:iam::*:instance-profile/pollflow*",
          "arn:aws:iam::*:policy/pollflow*",
          "arn:aws:iam::*:policy/AmazonEKS_EBS_CSI_Policy*",
          "arn:aws:iam::*:oidc-provider/*",
          "arn:aws:iam::aws:policy/*"
        ]
      }
    ]
  })
}

# EKS - Full EKS operations (no suitable managed policy for cluster creation)
resource "aws_iam_role_policy" "eks_admin" {
  name = "EKSAdminAccess"
  role = aws_iam_role.project_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSFullAccess"
        Effect = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# RDS - Database management for PostgreSQL
resource "aws_iam_role_policy_attachment" "rds_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

# Secrets Manager - For RDS credentials and application secrets
resource "aws_iam_role_policy_attachment" "secrets_manager_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# Lambda - For serverless functions (poll generator)
resource "aws_iam_role_policy_attachment" "lambda_full_access" {
  role       = aws_iam_role.project_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

# EventBridge - For event scheduling
resource "aws_iam_role_policy" "eventbridge_admin" {
  name = "EventBridgeAdminAccess"
  role = aws_iam_role.project_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EventBridgeFullAccess"
        Effect = "Allow"
        Action = [
          "events:*"
        ]
        Resource = "*"
      }
    ]
  })
}
