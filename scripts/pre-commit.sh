#!/bin/bash
# Pre-commit validation script
# Run manually: ./scripts/pre-commit.sh
# Checks: Frontend TypeScript, Poll-broker Go, Terraform

set -e

# Change to project root
cd "$(git rev-parse --show-toplevel)"

echo "🔍 Running pre-commit checks..."
echo ""

# ============================================
# 1. Frontend TypeScript/SvelteKit checks
# ============================================
echo "📦 Checking Frontend (SvelteKit + TypeScript)..."
cd services/frontend

if ! command -v pnpm &> /dev/null; then
  echo "❌ pnpm not installed. Install: npm install -g pnpm"
  exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
  echo "  📥 Installing dependencies..."
  pnpm install --frozen-lockfile
fi

# Sync SvelteKit (generates .svelte-kit directory)
echo "  🔄 Syncing SvelteKit..."
pnpm exec svelte-kit sync

# Run TypeScript and Svelte checks
echo "  🔎 Running svelte-check..."
pnpm run check

echo "  ✅ Frontend checks passed"
cd ../..
echo ""

# ============================================
# 2. Poll-broker Go checks
# ============================================
echo "🔧 Checking Poll-broker (Go)..."
cd services/poll-broker

if ! command -v go &> /dev/null; then
  echo "⚠️  Go not installed, skipping poll-broker checks"
else
  # Format Go code
  echo "  📝 Formatting Go code..."
  go fmt ./...
  
  # Run Go vet
  echo "  🔎 Running go vet..."
  go vet ./...
  
  # Try to build (without external dependencies)
  echo "  🔨 Checking build..."
  go build -o /dev/null ./...
  
  echo "  ✅ Poll-broker checks passed"
fi

cd ../..
echo ""

# ============================================
# 3. Terraform checks
# ============================================
echo "🏗️  Checking Terraform..."

# Format Terraform files
echo "  📝 Formatting Terraform files..."
terraform -chdir=infra/tf-bootstrap fmt -recursive
terraform -chdir=infra/tf-main fmt -recursive

# Validate Terraform if initialized
if [ -d "infra/tf-main/.terraform" ]; then
  echo "  ✅ Validating Terraform configuration..."
  terraform -chdir=infra/tf-main validate
else
  echo "  ℹ️  Terraform not initialized, skipping validation"
fi

echo "  ✅ Terraform checks passed"
echo ""

# ============================================
# Summary
# ============================================
echo "✨ All pre-commit checks passed!"
echo ""
echo "💡 To install as git hook, run:"
echo "   ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit"
