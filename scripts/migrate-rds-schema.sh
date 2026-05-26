#!/bin/bash
# RDS Schema Migration Script for PollFlow
# This script applies the new schema to the existing RDS database

set -e

echo "======================================"
echo "PollFlow RDS Schema Migration"
echo "======================================"
echo ""

# Get RDS endpoint from Terraform
echo "Getting RDS endpoint from Terraform..."
cd infra/tf-main
RDS_HOST=$(terraform output -raw rds_endpoint | cut -d: -f1)
RDS_PORT=$(terraform output -raw rds_endpoint | cut -d: -f2)
cd ../..

echo "RDS Host: $RDS_HOST"
echo "RDS Port: $RDS_PORT"
echo ""

# Database credentials (from Secrets Manager)
echo "Note: Database credentials are stored in AWS Secrets Manager"
echo "You can retrieve them with:"
echo "  aws secretsmanager get-secret-value --secret-id pollflow-rds-credentials --region eu-west-3"
echo ""

read -p "Enter database username (default: pollflow): " DB_USER
DB_USER=${DB_USER:-pollflow}

read -sp "Enter database password: " DB_PASSWORD
echo ""

read -p "Enter database name (default: pollflow): " DB_NAME
DB_NAME=${DB_NAME:-pollflow}

echo ""
echo "======================================"
echo "Migration Steps"
echo "======================================"
echo ""

# Check if old schema exists
echo "1. Checking existing schema..."
PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -c "\dt" > /tmp/existing_tables.txt 2>&1 || true

if grep -q "votes.*votes" /tmp/existing_tables.txt; then
    echo "   ✓ Found existing votes table"
    
    # Check if it's the old schema (simple single poll) or already migrated
    OLD_SCHEMA=$(PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT column_name FROM information_schema.columns WHERE table_name='votes' AND column_name='vote';" 2>/dev/null || echo "")
    
    if [ -n "$OLD_SCHEMA" ]; then
        echo "   ⚠ WARNING: Detected OLD schema (single-poll architecture)"
        echo ""
        echo "   This migration will:"
        echo "   - Drop the old 'votes' table"
        echo "   - Create new 'polls' and 'votes' tables"
        echo "   - All existing vote data will be LOST"
        echo ""
        read -p "   Continue? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            echo "Migration cancelled."
            exit 1
        fi
        
        echo ""
        echo "2. Dropping old schema..."
        PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS votes CASCADE;"
        echo "   ✓ Old schema dropped"
    else
        echo "   ✓ Schema appears to be already migrated"
        echo ""
        read -p "   Re-apply schema anyway? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            echo "Migration cancelled."
            exit 1
        fi
        
        echo ""
        echo "2. Dropping existing tables..."
        PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS votes CASCADE;"
        PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -c "DROP TABLE IF EXISTS polls CASCADE;"
        echo "   ✓ Existing tables dropped"
    fi
else
    echo "   ℹ No existing schema found (fresh database)"
fi

echo ""
echo "3. Applying new schema..."
PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -f services/database/schema.sql
echo "   ✓ Schema applied"

echo ""
read -p "4. Apply seed data? (yes/no, default: no): " SEED
if [ "$SEED" == "yes" ]; then
    PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -f services/database/seed.sql
    echo "   ✓ Seed data applied"
else
    echo "   ⊘ Skipped seed data"
fi

echo ""
echo "======================================"
echo "Migration Complete!"
echo "======================================"
echo ""
echo "Verifying tables..."
PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -c "\dt"

echo ""
echo "Poll count:"
PGPASSWORD=$DB_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM polls;"

echo ""
echo "Next steps:"
echo "1. Deploy new services to EKS: make deploy"
echo "2. Verify application connectivity"
echo "3. Create initial polls via database or admin interface"
