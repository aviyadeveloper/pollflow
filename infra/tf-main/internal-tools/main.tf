# Generate secure random password for Grafana admin
resource "random_password" "grafana_admin" {
  length  = 20
  special = true
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "grafana_password" {
  name                    = "${var.cluster_name}-grafana-admin-password"
  description             = "Grafana admin password for ${var.cluster_name} observability stack"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.cluster_name}-grafana-admin-password"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "grafana_password" {
  secret_id     = aws_secretsmanager_secret.grafana_password.id
  secret_string = random_password.grafana_admin.result
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source to get the latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Internal Tools
resource "aws_security_group" "internal_tools" {
  name        = "${var.cluster_name}-internal-tools-sg"
  description = "Security group for internal tools (Grafana, Prometheus, Loki)"
  vpc_id      = var.vpc_id

  # SSH from bastion only
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
  }

  # Grafana (web UI)
  ingress {
    description = "Grafana web UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Make accessible from anywhere (add your IP for security)
  }

  # Prometheus (web UI + scraping)
  ingress {
    description = "Prometheus web UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Loki (log ingestion)
  ingress {
    description = "Loki ingestion"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Only from VPC
  }

  # Node Exporter (metrics)
  ingress {
    description = "Node Exporter metrics"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-internal-tools-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "internal_tools" {
  name = "${var.cluster_name}-internal-tools-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-internal-tools-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Attach SSM policy for Session Manager access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.internal_tools.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy for logs
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.internal_tools.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for Secrets Manager access
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.cluster_name}-internal-tools-secrets"
  description = "Allow internal tools to read Grafana password from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.grafana_password.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets" {
  role       = aws_iam_role.internal_tools.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "internal_tools" {
  name = "${var.cluster_name}-internal-tools-profile"
  role = aws_iam_role.internal_tools.name

  tags = {
    Name        = "${var.cluster_name}-internal-tools-profile"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# EC2 Instance
resource "aws_instance" "internal_tools" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.internal_tools.id]
  iam_instance_profile   = aws_iam_instance_profile.internal_tools.name
  key_name               = var.key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    delete_on_termination = false # Keep data on instance termination
    encrypted             = true

    tags = {
      Name        = "${var.cluster_name}-internal-tools-volume"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    cluster_name      = var.cluster_name
    grafana_secret_id = aws_secretsmanager_secret.grafana_password.name
    aws_region        = data.aws_region.current.name
  })

  metadata_options {
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = {
    Name        = "${var.cluster_name}-internal-tools"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "observability-tooling"
  }
}

# Elastic IP for stable access
resource "aws_eip" "internal_tools" {
  domain   = "vpc"
  instance = aws_instance.internal_tools.id

  tags = {
    Name        = "${var.cluster_name}-internal-tools-eip"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
