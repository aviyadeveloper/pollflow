data "aws_region" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.project_name}-cluster"
  kubernetes_version = var.kubernetes_version

  # Cluster access
  enable_cluster_creator_admin_permissions = true
  endpoint_public_access                   = true
  endpoint_private_access                  = true

  # Grant GitHub Actions role cluster admin access
  access_entries = {
    github_actions = {
      principal_arn = var.github_actions_role_arn
      type          = "STANDARD"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Networking
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Logging
  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Addons - create before nodes to ensure networking is ready
  addons = {
    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    # Main node group in private subnets
    main = {
      name           = "${var.project_name}-main"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 5
      desired_size = 3

      subnet_ids = var.private_subnet_ids

      # AMI and capacity
      ami_type      = "AL2_x86_64"
      capacity_type = "ON_DEMAND"

      # Storage
      disk_size = 20

      # Update configuration
      update_config = {
        max_unavailable_percentage = 33
      }

      # Labels
      labels = {
        Environment = "dev"
        NodeGroup   = "main"
      }

      tags = {
        Name    = "${var.project_name}-main-node"
        Project = var.project_name
      }
    }
  }

  tags = {
    Project = var.project_name
  }
}

