# Helm provider for Kubernetes application deployment
# Configured at root level and inherited by child modules
# Uses local AWS credentials (not assumed role) for EKS authentication

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        "eu-west-3"
      ]
      # Uses ambient AWS credentials (user's profile), not Terraform's assumed role
      env = {
        AWS_PROFILE = "pollflow"
      }
    }
  }
}
