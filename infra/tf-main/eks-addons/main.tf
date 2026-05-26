# EBS CSI Driver - enables EKS to manage EBS volumes as PersistentVolumes
# Uses IRSA (IAM Roles for Service Accounts) for secure AWS API access

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for EBS CSI driver controller
# This role allows the CSI driver pods to call AWS EBS APIs
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Project = var.project_name
    Name    = "${var.project_name}-ebs-csi-driver"
  }
}

# Install EBS CSI driver as an EKS addon
# This is the recommended way (vs Helm) for EKS-managed updates
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  # Use latest available version
  addon_version = var.ebs_csi_driver_version

  # Associate the IRSA role
  service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn

  # Don't fail if addon already exists (for updates)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Project = var.project_name
    Name    = "${var.project_name}-ebs-csi-driver"
  }
}

# ============================================================
# AWS Load Balancer Controller
# Purpose: Enables ALB/NLB creation from Ingress/Service resources
# ============================================================

# Download IAM policy from AWS GitHub
data "http" "alb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json"
}

# Create IAM policy for Load Balancer Controller
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.project_name}-alb-controller"
  path        = "/"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.http.alb_controller_iam_policy.response_body

  tags = {
    Project = var.project_name
    Name    = "${var.project_name}-alb-controller-policy"
  }
}

# IAM role for Load Balancer Controller (IRSA)
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.60.0"

  role_name = "${var.project_name}-alb-controller"

  role_policy_arns = {
    policy = aws_iam_policy.alb_controller.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Project = var.project_name
    Name    = "${var.project_name}-alb-controller"
  }
}

# Install AWS Load Balancer Controller via Helm
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.alb_controller_version

  # Wait for all resources to be ready before marking complete
  wait = true

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "region"
      value = data.aws_region.current.name
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.alb_controller_irsa.iam_role_arn
      type  = "string"
    }
  ]

  depends_on = [
    aws_iam_policy.alb_controller,
    module.alb_controller_irsa
  ]
}
