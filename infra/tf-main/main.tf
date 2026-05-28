module "vpc" {
  source = "./vpc"

  project_name       = var.project_name
  region             = var.region
  vpc_cidr           = "10.0.0.0/16"
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = false
  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

module "ecr" {
  source = "./ecr"

  project_name = var.project_name
  region       = var.region
  repositories = ["frontend", "poll-broker"]
  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

module "bastion" {
  source = "./bastion"

  project_name  = var.project_name
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  instance_type = "t3.micro"
}

module "eks" {
  source = "./eks"

  project_name            = var.project_name
  kubernetes_version      = "1.31"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnets
  github_actions_role_arn = var.github_actions_role_arn
}

module "eks_addons" {
  source = "./eks-addons"

  project_name                       = var.project_name
  cluster_name                       = module.eks.cluster_name
  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  oidc_provider_arn                  = module.eks.oidc_provider_arn
  vpc_id                             = module.vpc.vpc_id
}

module "rds" {
  source = "./rds"

  project_name               = var.project_name
  region                     = var.region
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnets
  eks_node_security_group_id = module.eks.node_security_group_id
  bastion_security_group_id  = module.bastion.security_group_id

  # Database configuration
  database_name     = "pollflow"
  database_username = "pollflow"

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

module "poll_generator" {
  source = "./poll-generator"

  project_name       = var.project_name
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  # RDS connection info (from RDS module)
  rds_host              = module.rds.db_address
  rds_port              = module.rds.db_port
  rds_dbname            = module.rds.db_name
  rds_security_group_id = module.rds.db_security_group_id

  # Optional: override defaults if needed
  # schedule_window_hours = 2
  # target_polls_per_run  = 24
  # similarity_threshold  = 0.8

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

module "internal_tools" {
  source = "./internal-tools"

  vpc_id                    = module.vpc.vpc_id
  public_subnet_id          = module.vpc.public_subnets[0]
  bastion_security_group_id = module.bastion.security_group_id
  vpc_cidr                  = module.vpc.vpc_cidr_block
  cluster_name              = var.project_name
  environment               = "production"
  instance_type             = "t3.large"
  volume_size               = 50
  key_name                  = module.bastion.key_name
}

