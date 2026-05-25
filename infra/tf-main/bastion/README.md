<!-- BEGIN_TF_DOCS -->


## Features

- Ubuntu 24.04 LTS bastion host in public subnet
- Automatic SSH key pair generation with RSA 4096-bit encryption
- Security group with SSH access (port 22)
- Elastic IP for persistent public IP address
- Private key stored locally with secure permissions (0400)
- Ready-to-use SSH command output

## Usage

```hcl
module "bastion" {
  source = "./bastion"

  project_name = "pollflow"
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.public_subnets[0]

  # Optional: customize instance type
  instance_type = "t3.micro"

  # Optional: change keys storage path
  keys_path = ".keys"
}
```

## Connecting to the Bastion

After applying, connect using the output command:

```bash
# Get the SSH command
terraform output -raw bastion_ssh_command

# Or use the Makefile target from the root
make bastion-ssh
```

## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eip.bastion_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_key_pair.bastion_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_security_group.bastion_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [local_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [tls_private_key.bastion_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The type of EC2 instance to use for the bastion host | `string` | `"t3.micro"` | no |
| <a name="input_keys_path"></a> [keys\_path](#input\_keys\_path) | Path to store SSH keys | `string` | `".keys"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet ID where bastion will be deployed | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where bastion will be deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bastion_instance_id"></a> [bastion\_instance\_id](#output\_bastion\_instance\_id) | Instance ID of the bastion host |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP address of the bastion host |
| <a name="output_connection_details"></a> [connection\_details](#output\_connection\_details) | Complete connection details for the bastion host |
| <a name="output_key_name"></a> [key\_name](#output\_key\_name) | Name of the SSH key pair |
| <a name="output_private_key_path"></a> [private\_key\_path](#output\_private\_key\_path) | Path to the private SSH key file |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID of the bastion host |
| <a name="output_ssh_command"></a> [ssh\_command](#output\_ssh\_command) | Ready-to-use SSH command to connect to bastion |
<!-- END_TF_DOCS -->