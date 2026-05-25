<!-- BEGIN_TF_DOCS -->


## Features

- Production-ready EKS cluster with Kubernetes 1.31
- Managed node groups in private subnets
- Full control plane logging (API, audit, authenticator, controller manager, scheduler)
- Essential addons pre-configured (kube-proxy, CoreDNS, VPC-CNI, Pod Identity Agent)
- Auto-scaling node groups with configurable instance types
- OIDC provider for IAM roles for service accounts (IRSA)
- Public and private endpoint access for cluster API

## Usage

```hcl
module "eks" {
  source = "./eks"

  project_name       = "pollflow"
  kubernetes_version = "1.31"
  
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
}
```

## Post-Deployment

After the cluster is created, configure kubectl to access it:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl get nodes
```

## Node Groups

The module creates a managed node group with the following characteristics:

- **Instance Type**: t3.small
- **Capacity**: 1-3 nodes (desired: 2)
- **Subnet Placement**: Private subnets only
- **AMI**: Amazon Linux 2 (AL2_x86_64)
- **Storage**: 20 GB EBS volumes
- **Update Strategy**: Rolling updates with max 33% unavailable

## IAM Permissions Required

The Terraform role needs the following IAM permissions:
- `eks:*` for cluster management
- `iam:CreateRole`, `iam:DeleteRole`, `iam:PassRole` for service roles
- `iam:CreatePolicy`, `iam:DeletePolicy`, `iam:ListPolicyVersions` for cluster policies
- `ec2:*` for VPC and security group management
- `autoscaling:*` for node group scaling
- `logs:*` for CloudWatch logging
- `kms:*` for encryption

## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 21.0 |

## Resources

| Name | Type |
| ---- | ---- |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | The Kubernetes version for the EKS cluster | `string` | `"1.31"` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs for the EKS cluster and node groups | `list(string)` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project | `string` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | List of public subnet IDs (optional, for public node groups) | `list(string)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the EKS cluster will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data required to communicate with the cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for your Kubernetes API server |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | IAM role ARN of the EKS cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS cluster |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | The URL on the EKS cluster OIDC Issuer |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group ID attached to the EKS cluster |
| <a name="output_configure_kubectl"></a> [configure\_kubectl](#output\_configure\_kubectl) | Command to configure kubectl |
| <a name="output_node_security_group_id"></a> [node\_security\_group\_id](#output\_node\_security\_group\_id) | Security group ID attached to the EKS nodes |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC Provider for EKS |
<!-- END_TF_DOCS -->