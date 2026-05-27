#!/bin/bash
# ============================================================================
# Lambda Deployment Package Builder
# ============================================================================
# Creates a deployment-ready zip package for AWS Lambda with all dependencies
#
# Usage: ./build.sh
# ============================================================================

set -e

# ============================================================================
# Configuration
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_DIR="${SCRIPT_DIR}/build"
readonly PACKAGE_NAME="lambda-package.zip"
readonly PACKAGE_PATH="${SCRIPT_DIR}/${PACKAGE_NAME}"
readonly REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
readonly PYTHON_VERSION="3.12"

# Size limits (in bytes)
readonly MAX_DIRECT_UPLOAD_SIZE=$((50 * 1024 * 1024))  # 50MB
readonly MAX_UNZIPPED_SIZE=$((250 * 1024 * 1024))      # 250MB

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================
log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# ============================================================================
# Validation
# ============================================================================
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    command -v uv >/dev/null 2>&1 || \
        error_exit "uv is required but not installed. Install from: https://docs.astral.sh/uv/"
    
    command -v zip >/dev/null 2>&1 || \
        error_exit "zip is required but not installed. Install with: apt-get install zip"
    
    [ -f "${SCRIPT_DIR}/pyproject.toml" ] || \
        error_exit "pyproject.toml not found. Run from services/poll-generator/ directory"
    
    log_success "Prerequisites validated"
}

# ============================================================================
# Build Operations
# ============================================================================
clean_previous_build() {
    log_info "Cleaning previous build artifacts..."
    
    [ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"
    [ -f "$PACKAGE_PATH" ] && rm -f "$PACKAGE_PATH"
    [ -f "$REQUIREMENTS_FILE" ] && rm -f "$REQUIREMENTS_FILE"
    
    log_success "Build directory cleaned"
}

create_build_directory() {
    log_info "Creating build directory..."
    mkdir -p "$BUILD_DIR"
    log_success "Build directory created: $BUILD_DIR"
}

copy_source_files() {
    log_info "Copying Python source files..."
    
    local file_count=0
    for file in "${SCRIPT_DIR}"/*.py; do
        if [ -f "$file" ]; then
            cp "$file" "$BUILD_DIR/"
            file_count=$((file_count + 1))
        fi
    done
    
    [ $file_count -eq 0 ] && error_exit "No Python source files found"
    
    log_success "Copied $file_count Python source files"
}

copy_prompts_directory() {
    log_info "Copying prompts directory..."
    
    if [ -d "${SCRIPT_DIR}/prompts" ]; then
        cp -r "${SCRIPT_DIR}/prompts" "$BUILD_DIR/"
        local prompt_count=$(find "${BUILD_DIR}/prompts" -type f | wc -l)
        log_success "Copied prompts directory with $prompt_count files"
    else
        log_warning "No prompts directory found, skipping"
    fi
}

export_dependencies() {
    log_info "Exporting dependencies from pyproject.toml..."
    
    cd "$SCRIPT_DIR" || error_exit "Cannot access script directory"
    
    uv export --no-hashes --output-file "$REQUIREMENTS_FILE" || \
        error_exit "Failed to export dependencies"
    
    local dep_count=$(grep -c "^[^#]" "$REQUIREMENTS_FILE" || true)
    log_success "Exported $dep_count dependencies to requirements.txt"
}

install_dependencies() {
    log_info "Installing dependencies to build directory..."
    
    cd "$SCRIPT_DIR" || error_exit "Cannot access script directory"
    
    uv pip install \
        -r "$REQUIREMENTS_FILE" \
        --target "$BUILD_DIR" \
        --python "$PYTHON_VERSION" || \
        error_exit "Failed to install dependencies"
    
    log_success "Dependencies installed successfully"
}

create_package() {
    log_info "Creating Lambda deployment package..."
    
    cd "$BUILD_DIR" || error_exit "Cannot access build directory"
    
    zip -r "$PACKAGE_PATH" . -q || \
        error_exit "Failed to create zip package"
    
    cd "$SCRIPT_DIR" || exit 1
    
    log_success "Package created: $PACKAGE_NAME"
}

# ============================================================================
# Package Validation
# ============================================================================
validate_package() {
    log_info "Validating package..."
    
    [ -f "$PACKAGE_PATH" ] || error_exit "Package file not found: $PACKAGE_PATH"
    
    local package_size
    package_size=$(stat -f%z "$PACKAGE_PATH" 2>/dev/null || stat -c%s "$PACKAGE_PATH" 2>/dev/null)
    
    local size_mb=$((package_size / 1024 / 1024))
    
    echo "  Package size: ${size_mb}MB"
    
    if [ $package_size -gt $MAX_DIRECT_UPLOAD_SIZE ]; then
        log_warning "Package exceeds 50MB direct upload limit"
        echo "  You'll need to upload via S3 for Terraform deployment"
    fi
    
    if [ $package_size -gt $MAX_UNZIPPED_SIZE ]; then
        error_exit "Package exceeds Lambda's 250MB unzipped limit"
    fi
    
    log_success "Package validation passed"
}

show_package_contents() {
    log_info "Package contents (first 20 files):"
    echo ""
    unzip -l "$PACKAGE_PATH" | head -20
    echo ""
    
    local total_files
    total_files=$(unzip -l "$PACKAGE_PATH" | tail -1 | awk '{print $2}')
    echo "  Total files: $total_files"
}

show_next_steps() {
    echo ""
    echo -e "${GREEN}[NEXT STEPS]${NC}"
    echo "  1. Review package contents above"
    echo "  2. Optional: Test with SAM CLI (see Milestone 2.2)"
    echo "  3. Deploy with Terraform:"
    echo "     cd ../../infra/tf-main"
    echo "     terraform plan"
    echo "     terraform apply"
}

# ============================================================================
# Main Execution
# ============================================================================
main() {
    log_info "Starting Lambda package build..."
    echo ""
    
    validate_prerequisites
    clean_previous_build
    create_build_directory
    copy_source_files
    copy_prompts_directory
    export_dependencies
    install_dependencies
    create_package
    validate_package
    show_package_contents
    
    echo ""
    log_success "Lambda package build complete!"
    show_next_steps
}

main "$@"
