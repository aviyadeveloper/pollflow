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
    Statement = [{
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
    }]
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

# S3 - Terraform state backend access
resource "aws_iam_role_policy" "s3_policy" {
  name = "S3StateManagement"
  role = aws_iam_role.project_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateBackend"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::cloudpollpro*",
          "arn:aws:s3:::cloudpollpro*/*"
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
          "iam:TagPolicy",
          "iam:UntagPolicy",
          "iam:ListPolicyVersions"
        ]
        Resource = [
          "arn:aws:iam::*:role/cloudpollpro*",
          "arn:aws:iam::*:role/projects/cloudpollpro*",
          "arn:aws:iam::*:role/aws-service-role/*",
          "arn:aws:iam::*:instance-profile/cloudpollpro*",
          "arn:aws:iam::*:policy/cloudpollpro*",
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
