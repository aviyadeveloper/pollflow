<!-- BEGIN_TF_DOCS -->


## Usage

```hcl
module "ecr" {
  source = "./ecr"

  project_name = "pollflow"
  region       = "us-east-1"
  repositories = ["frontend", "poll-broker"]
  
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_image_tag_mutability"></a> [image\_tag\_mutability](#input\_image\_tag\_mutability) | The tag mutability setting for the repository (MUTABLE or IMMUTABLE) | `string` | `"MUTABLE"` | no |
| <a name="input_lifecycle_policy_keep_count"></a> [lifecycle\_policy\_keep\_count](#input\_lifecycle\_policy\_keep\_count) | Number of images to keep in repository | `number` | `3` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region to deploy resources in | `string` | n/a | yes |
| <a name="input_repositories"></a> [repositories](#input\_repositories) | List of ECR repository names to create | `list(string)` | <pre>[<br/>  "frontend",<br/>  "poll-broker"<br/>]</pre> | no |
| <a name="input_scan_on_push"></a> [scan\_on\_push](#input\_scan\_on\_push) | Indicates whether images are scanned after being pushed to the repository | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags for ECR resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_registry_id"></a> [registry\_id](#output\_registry\_id) | The registry ID where the repositories were created |
| <a name="output_repository_arns"></a> [repository\_arns](#output\_repository\_arns) | Map of repository names to their ARNs |
| <a name="output_repository_urls"></a> [repository\_urls](#output\_repository\_urls) | Map of repository names to their URLs |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
<!-- END_TF_DOCS -->