# Development Scripts

## pre-commit.sh

Manual validation script for Terraform - runs formatting, documentation, and validation checks.

### What it does:

1. **Formats** all Terraform files (`terraform fmt`)
2. **Generates** module documentation (if `terraform-docs` is installed)
3. **Validates** Terraform configuration

### Usage:

**Run manually before committing:**
```bash
./scripts/pre-commit.sh
```

**Quick workflow:**
```bash
# Make changes to .tf files
./scripts/pre-commit.sh  # Format, generate docs, validate
git add -A
git commit -m "your message"
```

### Why not a git hook?

- Git hooks can be fragile and annoying
- Different workflows (CLI vs VS Code) behave differently
- Better to run manually when you're ready
- Future: CI/CD will check and generate docs automatically

### Requirements:

- Terraform (required)
- terraform-docs (optional, for auto-generating README.md)

### Installing terraform-docs:

```bash
# Linux
curl -Lo ./terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v0.16.0/terraform-docs-v0.16.0-$(uname)-amd64.tar.gz
tar -xzf terraform-docs.tar.gz
chmod +x terraform-docs
sudo mv terraform-docs /usr/local/bin/
rm terraform-docs.tar.gz

# Verify
terraform-docs --version
```

---

## migrate-rds-schema.sh

Database migration script for applying the new PollFlow schema to AWS RDS.

### What it does:

1. **Retrieves** RDS endpoint from Terraform outputs
2. **Checks** existing schema and warns about data loss
3. **Drops** old tables (if migrating from old single-poll architecture)
4. **Applies** new multi-poll schema (`services/database/schema.sql`)
5. **Optionally** applies seed data for testing

### Usage:

**Before running:**
- Ensure Terraform infrastructure is deployed (`make infra-main`)
- Have database credentials ready (from AWS Secrets Manager)

**Run the migration:**
```bash
./scripts/migrate-rds-schema.sh
```

**The script will prompt for:**
- Database username (default: pollflow)
- Database password
- Database name (default: pollflow)
- Confirmation before dropping tables
- Whether to apply seed data

### When to use:

- **Migrating from old architecture**: Transitioning from vote/result/worker services to poll-broker/frontend
- **Fresh deployment**: Setting up schema on new RDS instance
- **Schema updates**: Reapplying schema after changes

### Requirements:

- `psql` (PostgreSQL client) installed
- Terraform infrastructure deployed
- Network access to RDS (via bastion or VPN)
- Database credentials from AWS Secrets Manager

### Getting database credentials:

```bash
# Retrieve from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id pollflow-rds-credentials \
  --region eu-west-3 \
  --query SecretString \
  --output text | jq -r '.password'
```

### Important notes:

⚠️ **WARNING**: This script will DROP existing tables and ALL DATA will be lost!

- Always backup production databases before running
- For production, consider using proper migration tools (Flyway, golang-migrate)
- Seed data is for development/testing only - do not use in production

### Troubleshooting:

**Connection refused:**
- Ensure you're connected via bastion host or have RDS security group access
- Check RDS endpoint is correct: `make bastion-ssh`

**Authentication failed:**
- Verify credentials from Secrets Manager
- Ensure database user has CREATE/DROP privileges

