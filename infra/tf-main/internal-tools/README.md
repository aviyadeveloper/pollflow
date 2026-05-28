# Internal Tools Infrastructure

This module provisions a dedicated EC2 instance for internal tooling and observability.

## Components

**Observability Stack** (Docker Compose):
- **Grafana**: Visualization and dashboards (port 3000)
- **Loki**: Log aggregation (port 3100)
- **Promtail**: Log shipping agent
- **Prometheus**: Metrics collection (port 9090)
- **Node Exporter**: System metrics (port 9100)

**Future Tools**:
- SonarQube (code quality)
- Other internal tooling as needed

## Infrastructure

- **Instance Type**: t3.large (2 vCPU, 8 GiB RAM)
- **Storage**: 50 GB EBS volume for persistent data
- **Network**: Public subnet with Elastic IP
- **Access**: SSH from bastion host only
- **Security**: Restrictive security group

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Outputs

- `instance_id`: EC2 instance ID
- `public_ip`: Elastic IP address
- `grafana_url`: Grafana dashboard URL (http://[IP]:3000)
- `prometheus_url`: Prometheus UI URL (http://[IP]:9090)
- `grafana_password_secret_name`: Secret name in AWS Secrets Manager
- `grafana_password_retrieval_command`: Command to retrieve password

## Security

- **Grafana Password**: Randomly generated (20 chars) and stored in AWS Secrets Manager
- **SSH Access**: Only via bastion host jumpbox
- **IAM Permissions**: Instance can read its own Grafana password secret
- **Encryption**: EBS volume encrypted at rest

## Retrieving Grafana Password

```bash
# Get the retrieval command from Terraform
terraform output grafana_password_retrieval_command

# Or directly:
aws secretsmanager get-secret-value \
  --secret-id pollflow-grafana-admin-password \
  --query SecretString \
  --output text
```
