# CloudPollPro Infrastructure Setup

## Authentication

This project uses **IAM role assumption** instead of static access keys for enhanced security.

### Prerequisites

- AWS CLI configured with admin credentials
- Permissions to assume role: \`arn:aws:iam::058264398399:role/projects/cloudpollpro-bootstrap-terraform-role\`

### How It Works

1. **Backend (S3/DynamoDB)**: Automatically assumes the role when accessing state
2. **Provider**: Automatically assumes the role for all AWS API calls
3. **No static credentials**: No access keys stored anywhere!

### Usage

\`\`\`bash
# Verify you can assume the role
aws sts assume-role \\
  --role-arn arn:aws:iam::058264398399:role/projects/cloudpollpro-bootstrap-terraform-role \\
  --role-session-name terraform-test \\
  --external-id cloudpollpro-bootstrap

# If successful, proceed with terraform
terraform init
terraform plan
terraform apply
\`\`\`

### Role Details

- **Role ARN**: \`arn:aws:iam::058264398399:role/projects/cloudpollpro-bootstrap-terraform-role\`
- **Role Name**: \`cloudpollpro-bootstrap-terraform-role\`
- **External ID**: \`cloudpollpro-bootstrap\` (for additional security)
- **Session Name**: \`terraform-<workspace>\`

### Troubleshooting

**Error: "AccessDenied"**
- Ensure your current AWS credentials have \`sts:AssumeRole\` permission
- Verify the external ID matches: \`cloudpollpro-bootstrap\`

**Error: "InvalidClientTokenId"**
- Check your AWS CLI configuration: \`aws sts get-caller-identity\`
- Ensure you're using admin credentials that created the bootstrap

## Security Benefits

✅ No static access keys
✅ No secrets in state files  
✅ Temporary credentials (auto-rotate every 12 hours)
✅ CloudTrail logs show both your identity AND the assumed role
✅ Can revoke access instantly by modifying role trust policy
