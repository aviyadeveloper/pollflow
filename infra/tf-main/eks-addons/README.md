<!-- BEGIN_TF_DOCS -->


## Features

- **EBS CSI Driver**: AWS-managed EKS addon for EBS volume provisioning
- **External Secrets Operator**: IAM role for syncing AWS Secrets Manager to Kubernetes
- **IRSA Pattern**: IAM Roles for Service Accounts for secure, credential-free AWS API access
- All add-ons follow AWS best practices with least-privilege IAM policies

## Components

### EBS CSI Driver
- Enables dynamic provisioning of EBS volumes as Kubernetes PersistentVolumes
- Installed as EKS-managed addon (automatic updates available)
- Service account: `ebs-csi-controller-sa` in `kube-system` namespace
- IAM permissions: EC2 volume operations (create, attach, delete, snapshot)

### External Secrets Operator
- IAM role for External Secrets Operator to read AWS Secrets Manager
- Service account: `external-secrets` in `external-secrets-system` namespace
- IAM permissions: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`
- Scoped to secrets with prefix `pollflow-*`

## Usage

```hcl
module "eks_addons" {
  source = "./eks-addons"

  project_name      = "pollflow"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
}
```

## Verification

```bash
# Check EBS CSI Driver
kubectl get pods -n kube-system | grep ebs-csi
kubectl get sa ebs-csi-controller-sa -n kube-system -o yaml | grep role-arn

# Check External Secrets role
kubectl get sa external-secrets -n external-secrets-system -o yaml | grep role-arn
```

## Requirements

## Requirements

No requirements.

## Providers

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |

## Modules

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_ebs_csi_driver_irsa"></a> [ebs\_csi\_driver\_irsa](#module\_ebs\_csi\_driver\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.0 |
| <a name="module_external_secrets_irsa"></a> [external\_secrets\_irsa](#module\_external\_secrets\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.0 |

## Resources

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eks_addon.ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_policy.external_secrets_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [helm_release.external_secrets](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#input\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data for the EKS cluster | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Endpoint for the EKS cluster API server | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_ebs_csi_driver_version"></a> [ebs\_csi\_driver\_version](#input\_ebs\_csi\_driver\_version) | Version of the EBS CSI driver addon to install | `string` | `null` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the EKS OIDC provider for IRSA | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name for resource naming and tagging | `string` | n/a | yes |

## Outputs

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ebs_csi_driver_addon_arn"></a> [ebs\_csi\_driver\_addon\_arn](#output\_ebs\_csi\_driver\_addon\_arn) | ARN of the EBS CSI driver addon |
| <a name="output_ebs_csi_driver_addon_version"></a> [ebs\_csi\_driver\_addon\_version](#output\_ebs\_csi\_driver\_addon\_version) | Version of the EBS CSI driver addon installed |
| <a name="output_ebs_csi_driver_role_arn"></a> [ebs\_csi\_driver\_role\_arn](#output\_ebs\_csi\_driver\_role\_arn) | ARN of the IAM role used by EBS CSI driver |
| <a name="output_external_secrets_role_arn"></a> [external\_secrets\_role\_arn](#output\_external\_secrets\_role\_arn) | ARN of the IAM role used by External Secrets Operator |
<!-- END_TF_DOCS -->