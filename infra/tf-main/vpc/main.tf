module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  # Required tags for EKS
  public_subnet_tags = merge(
    {
      "kubernetes.io/role/elb"                            = "1"
      "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
    },
    var.extra_public_subnet_tags
  )

  private_subnet_tags = merge(
    {
      "kubernetes.io/role/internal-elb"                   = "1"
      "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
    },
    var.extra_private_subnet_tags
  )

  tags = merge(
    var.tags,
    {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  )
}
