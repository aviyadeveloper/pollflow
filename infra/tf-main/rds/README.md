<!-- BEGIN_TF_DOCS -->


## Usage

```hcl
module "rds" {
  source = "./rds"

  project_name                = "pollflow"
  region                      = "us-east-1"
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnets
  eks_node_security_group_id  = module.eks.node_security_group_id
  bastion_security_group_id   = module.bastion.security_group_id
  
  # Database configuration
  database_name     = "pollflow"
  database_username = "pollflow"
  instance_class    = "db.t3.micro"
  engine_version    = "16.3"
  
  # High availability
  multi_az = true
  
  # Backup configuration
  backup_retention_period = 7
  
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

## Features

- **Multi-AZ**: High availability with automatic failover
- **Encryption**: Data encrypted at rest with AWS-managed keys
- **Secrets Manager**: Database password stored securely
- **Automated Backups**: 7-day retention by default
- **Security Groups**: Restricted access from EKS nodes and bastion only
- **CloudWatch Logs**: PostgreSQL and upgrade logs exported
- **Auto Scaling**: Storage auto-scales up to max_allocated_storage

## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Allocated storage in GB | `number` | `20` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Number of days to retain backups | `number` | `7` | no |
| <a name="input_backup_window"></a> [backup\_window](#input\_backup\_window) | Preferred backup window (UTC) | `string` | `"03:00-04:00"` | no |
| <a name="input_bastion_security_group_id"></a> [bastion\_security\_group\_id](#input\_bastion\_security\_group\_id) | Security group ID of bastion host (for allowing database access) | `string` | n/a | yes |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the database to create | `string` | `"pollflow"` | no |
| <a name="input_database_username"></a> [database\_username](#input\_database\_username) | Master username for the database | `string` | `"pollflow"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection (recommended for production) | `bool` | `false` | no |
| <a name="input_eks_node_security_group_id"></a> [eks\_node\_security\_group\_id](#input\_eks\_node\_security\_group\_id) | Security group ID of EKS nodes (for allowing database access) | `string` | n/a | yes |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | PostgreSQL engine version | `string` | `"16.13"` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | RDS instance class | `string` | `"db.t3.micro"` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Preferred maintenance window (UTC) | `string` | `"mon:04:00-mon:05:00"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Maximum allocated storage for autoscaling in GB | `number` | `100` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Enable multi-AZ deployment for high availability | `bool` | `true` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs for RDS subnet group | `list(string)` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region to deploy resources in | `string` | n/a | yes |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip final snapshot when destroying (set to false for production) | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags for RDS resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where RDS will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_db_address"></a> [db\_address](#output\_db\_address) | The hostname of the RDS instance |
| <a name="output_db_credentials_secret_arn"></a> [db\_credentials\_secret\_arn](#output\_db\_credentials\_secret\_arn) | ARN of the Secrets Manager secret containing database credentials |
| <a name="output_db_credentials_secret_name"></a> [db\_credentials\_secret\_name](#output\_db\_credentials\_secret\_name) | Name of the Secrets Manager secret containing database credentials |
| <a name="output_db_endpoint"></a> [db\_endpoint](#output\_db\_endpoint) | The connection endpoint (host:port) |
| <a name="output_db_instance_arn"></a> [db\_instance\_arn](#output\_db\_instance\_arn) | The ARN of the RDS instance |
| <a name="output_db_instance_id"></a> [db\_instance\_id](#output\_db\_instance\_id) | The RDS instance identifier |
| <a name="output_db_name"></a> [db\_name](#output\_db\_name) | The name of the database |
| <a name="output_db_port"></a> [db\_port](#output\_db\_port) | The port the database is listening on |
| <a name="output_db_security_group_id"></a> [db\_security\_group\_id](#output\_db\_security\_group\_id) | The security group ID of the RDS instance |
| <a name="output_db_subnet_group_name"></a> [db\_subnet\_group\_name](#output\_db\_subnet\_group\_name) | The name of the database subnet group |
| <a name="output_db_username"></a> [db\_username](#output\_db\_username) | The master username for the database |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_secretsmanager_secret.db_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.db_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.rds_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_ingress_from_bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_ingress_from_eks_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [random_password.db_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
<!-- END_TF_DOCS -->