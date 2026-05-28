#!/bin/bash
# ============================================================================
# SSH Tunnel Teardown
# ============================================================================
# Closes the SSH tunnel to RDS
#
# Usage: ./tunnel-stop.sh
# ============================================================================

set -e

# ============================================================================
# Configuration
# ============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="../../infra/tf-main"
readonly LOCAL_PORT=5432
readonly PROCESS_WAIT_SECONDS=1

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# ============================================================================
# Terraform Operations
# ============================================================================
get_rds_host() {
    local original_dir="$PWD"
    
    log_info "Fetching RDS endpoint from Terraform..."
    
    cd "$TERRAFORM_DIR" || error_exit "Cannot access Terraform directory: $TERRAFORM_DIR"
    
    RDS_HOST=$(terraform output -raw rds_endpoint 2>/dev/null | cut -d: -f1) || true
    
    cd "$original_dir" || exit 1
    
    if [ -z "$RDS_HOST" ]; then
        error_exit "Failed to retrieve RDS endpoint from Terraform"
    fi
    
    echo "  RDS Host: $RDS_HOST"
}

# ============================================================================
# Tunnel Management
# ============================================================================
find_tunnel_process() {
    ps aux | grep -v grep | grep "ssh.*${LOCAL_PORT}.*${RDS_HOST}" || true
}

get_tunnel_pid() {
    find_tunnel_process | awk '{print $2}' | head -1
}

is_process_running() {
    local pid="$1"
    ps -p "$pid" > /dev/null 2>&1
}

kill_tunnel_process() {
    local tunnel_pid="$1"
    
    log_info "Found tunnel process: PID $tunnel_pid"
    log_info "Attempting graceful shutdown..."
    
    kill "$tunnel_pid" 2>/dev/null || true
    sleep "$PROCESS_WAIT_SECONDS"
    
    if is_process_running "$tunnel_pid"; then
        log_warning "Process still running, forcing termination..."
        kill -9 "$tunnel_pid" 2>/dev/null || true
        sleep "$PROCESS_WAIT_SECONDS"
    fi
    
    if is_process_running "$tunnel_pid"; then
        error_exit "Failed to terminate tunnel process (PID: $tunnel_pid)"
    fi
}

show_env_reminder() {
    echo ""
    echo -e "${YELLOW}[REMINDER]${NC} Update .env if needed:"
    echo "  For local development: RDS_HOST=localhost"
    echo "  For Lambda deployment: RDS_HOST=pollflow-postgres...rds.amazonaws.com"
}

# ============================================================================
# Main Execution
# ============================================================================
main() {
    log_info "Stopping SSH tunnel..."
    
    get_rds_host
    
    local tunnel_pid
    tunnel_pid=$(get_tunnel_pid)
    
    if [ -z "$tunnel_pid" ]; then
        log_info "No active SSH tunnel found"
        exit 0
    fi
    
    kill_tunnel_process "$tunnel_pid"
    
    log_success "SSH tunnel closed successfully"
    show_env_reminder
}

main "$@"
