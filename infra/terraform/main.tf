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

module "bastion" {
  source = "./bastion"

  project_name  = var.project_name
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  instance_type = "t3.micro"
}
