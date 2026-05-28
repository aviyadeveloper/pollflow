#!/bin/bash
# ============================================================================
# SSH Tunnel Setup for Local RDS Access
# ============================================================================
# Creates an SSH tunnel through the bastion host to access RDS locally.
# After running this, your local machine can connect to RDS via localhost:5432
#
# Usage: ./tunnel-start.sh
# ============================================================================

set -e

# ============================================================================
# Configuration
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="../../infra/tf-main"
readonly BASTION_KEY_PATH="../../infra/tf-main/.keys/pollflow-bastion-key.pem"
readonly BASTION_USER="ubuntu"
readonly LOCAL_PORT=5432
readonly REMOTE_PORT=5432
readonly TUNNEL_WAIT_SECONDS=2

# SSH options for tunnel stability
readonly SSH_OPTS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ServerAliveInterval=60
    -o ServerAliveCountMax=3
)

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# ============================================================================
# Terraform Operations
# ============================================================================
get_terraform_outputs() {
    local original_dir="$PWD"
    
    log_info "Fetching infrastructure details from Terraform..."
    
    cd "$TERRAFORM_DIR" || error_exit "Cannot access Terraform directory: $TERRAFORM_DIR"
    
    BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null) || true
    RDS_HOST=$(terraform output -raw rds_endpoint 2>/dev/null | cut -d: -f1) || true
    
    cd "$original_dir" || exit 1
    
    if [ -z "$BASTION_IP" ]; then
        error_exit "Failed to retrieve bastion IP from Terraform"
    fi
    
    if [ -z "$RDS_HOST" ]; then
        error_exit "Failed to retrieve RDS endpoint from Terraform"
    fi
    
    echo "  Bastion IP: $BASTION_IP"
    echo "  RDS Host: $RDS_HOST"
}

# ============================================================================
# Tunnel Management
# ============================================================================
find_tunnel_process() {
    ps aux | grep -v grep | grep "ssh.*${LOCAL_PORT}.*${RDS_HOST}" || true
}

is_tunnel_running() {
    [ -n "$(find_tunnel_process)" ]
}

check_port_available() {
    if lsof -i ":${LOCAL_PORT}" > /dev/null 2>&1; then
        error_exit "Port ${LOCAL_PORT} is already in use. Check with: lsof -i :${LOCAL_PORT}"
    fi
}

establish_tunnel() {
    log_info "Establishing SSH tunnel..."
    
    ssh -i "$BASTION_KEY_PATH" \
        -L "${LOCAL_PORT}:${RDS_HOST}:${REMOTE_PORT}" \
        "${SSH_OPTS[@]}" \
        "${BASTION_USER}@${BASTION_IP}" \
        -N -f
    
    sleep "$TUNNEL_WAIT_SECONDS"
}

verify_tunnel() {
    if is_tunnel_running; then
        log_success "SSH tunnel established successfully"
        return 0
    else
        error_exit "Failed to establish SSH tunnel"
    fi
}

show_tunnel_info() {
    echo ""
    echo -e "${GREEN}[CONNECTION]${NC} Tunnel details:"
    echo "  Local endpoint: localhost:${LOCAL_PORT}"
    echo "  Remote RDS: ${RDS_HOST}:${REMOTE_PORT}"
    echo ""
    
    local tunnel_process
    tunnel_process=$(find_tunnel_process | awk '{print "  PID: "$2}' | head -1)
    echo -e "${GREEN}[PROCESS]${NC} $tunnel_process"
    echo ""
    
    echo -e "${YELLOW}[NEXT STEPS]${NC}"
    echo "  1. Ensure .env has: RDS_HOST=localhost"
    echo "  2. Run tests: uv run python tests/test_e2e.py"
    echo "  3. Stop tunnel when done: ./tunnel-stop.sh"
}

# ============================================================================
# Validation
# ============================================================================
validate_prerequisites() {
    if [ ! -f "$BASTION_KEY_PATH" ]; then
        error_exit "Bastion key not found at: $BASTION_KEY_PATH"$'\n'"  Run 'cd $TERRAFORM_DIR && terraform apply' first"
    fi
    
    if is_tunnel_running; then
        log_error "SSH tunnel is already running"
        echo "  Run ./tunnel-stop.sh to close existing tunnel first"
        exit 0
    fi
    
    check_port_available
}

# ============================================================================
# Main Execution
# ============================================================================
main() {
    log_info "Starting SSH tunnel setup..."
    
    validate_prerequisites
    get_terraform_outputs
    establish_tunnel
    verify_tunnel
    show_tunnel_info
}

main "$@"
