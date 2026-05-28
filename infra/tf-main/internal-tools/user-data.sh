#!/bin/bash
# ============================================================================
# Internal Tools Observability Stack Setup
# ============================================================================
# Automated deployment of Grafana, Loki, Prometheus, Promtail, Node Exporter
# on EC2 instance via Terraform user-data
#
# Sets up complete observability infrastructure with:
# - Docker and Docker Compose installation
# - All service configurations (embedded)
# - Automatic stack startup
# ============================================================================

set -euo pipefail

# Redirect all output to log file
exec > >(tee /var/log/user-data.log)
exec 2>&1

# ============================================================================
# Configuration
# ============================================================================
readonly CLUSTER_NAME="${cluster_name}"
readonly GRAFANA_SECRET_ID="${grafana_secret_id}"
readonly AWS_REGION="${aws_region}"
readonly OBSERVABILITY_DIR="/opt/observability"
readonly CONFIG_DIR="$${OBSERVABILITY_DIR}/config"
readonly DOCKER_COMPOSE_VERSION="2.32.4"

# ============================================================================
# Logging Functions
# ============================================================================
log_section() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_warning() {
    echo "[WARNING] $1"
}

# ============================================================================
# System Setup Functions
# ============================================================================
install_system_packages() {
    log_section "Installing System Packages"
    
    apt-get update
    apt-get upgrade -y
    
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        unzip \
        jq
    
    log_success "System packages installed"
}

install_aws_cli() {
    log_section "Installing AWS CLI v2"
    
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    
    log_success "AWS CLI v2 installed: $(aws --version)"
}

install_docker() {
    log_section "Installing Docker"
    
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    
    log_success "Docker installed and configured"
}

install_docker_compose() {
    log_section "Installing Docker Compose"
    
    local compose_url="https://github.com/docker/compose/releases/download/v$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    
    curl -L "$compose_url" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log_success "Docker Compose v$${DOCKER_COMPOSE_VERSION} installed"
}

create_directory_structure() {
    log_section "Creating Directory Structure"
    
    mkdir -p "$${OBSERVABILITY_DIR}"
    mkdir -p "$${CONFIG_DIR}"/{prometheus,loki,promtail,grafana/provisioning/{datasources,dashboards}}
    
    log_success "Directory structure created"
}

fetch_grafana_password() {
    log_section "Fetching Grafana Admin Password"
    
    log_info "Region: $${AWS_REGION}"
    
    local password
    password=$(aws secretsmanager get-secret-value \
        --secret-id "$${GRAFANA_SECRET_ID}" \
        --region "$${AWS_REGION}" \
        --query SecretString \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$password" ]; then
        echo "GRAFANA_ADMIN_PASSWORD=$password" > "$${OBSERVABILITY_DIR}/.env"
        chmod 600 "$${OBSERVABILITY_DIR}/.env"
        log_success "Grafana password retrieved from Secrets Manager"
    else
        log_warning "Could not fetch password from Secrets Manager, using fallback"
        echo "GRAFANA_ADMIN_PASSWORD=pollflow2026" > "$${OBSERVABILITY_DIR}/.env"
    fi
}

# ============================================================================
# Configuration File Creation Functions
# ============================================================================

# ============================================================================
# Configuration File Creation Functions
# ============================================================================
create_docker_compose_config() {
    log_info "Creating docker-compose.yml"
    
    cat > "$${OBSERVABILITY_DIR}/docker-compose.yml" <<'EOFDC'
version: "3.8"

networks:
  monitoring:
    driver: bridge

volumes:
  grafana-data:
  prometheus-data:
  loki-data:

services:
  grafana:
    image: grafana/grafana:11.4.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=$${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    env_file:
      - .env
    volumes:
      - grafana-data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning
    networks:
      - monitoring
    depends_on:
      - prometheus
      - loki

  prometheus:
    image: prom/prometheus:v3.1.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    volumes:
      - prometheus-data:/prometheus
      - ./config/prometheus:/etc/prometheus
    networks:
      - monitoring

  loki:
    image: grafana/loki:3.3.2
    container_name: loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - loki-data:/loki
      - ./config/loki:/etc/loki
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:3.3.2
    container_name: promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - ./config/promtail:/etc/promtail
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring
    depends_on:
      - loki

  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'
    networks:
      - monitoring
EOFDC
}

create_prometheus_config() {
    log_info "Creating Prometheus configuration"
    
    cat > "$${CONFIG_DIR}/prometheus/prometheus.yml" <<'EOFPROM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'pollflow'
    environment: 'production'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'prometheus'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          service: 'internal-tools-host'
EOFPROM
}

create_loki_config() {
    log_info "Creating Loki configuration"
    
    cat > "$${CONFIG_DIR}/loki/local-config.yaml" <<'EOFLOKI'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  retention_period: 30d
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
EOFLOKI
}

create_promtail_config() {
    log_info "Creating Promtail configuration"
    
    cat > "$${CONFIG_DIR}/promtail/config.yml" <<'EOFPROMTAIL'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: internal-tools
          __path__: /var/log/*log

  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
EOFPROMTAIL
}

create_grafana_datasource_config() {
    log_info "Creating Grafana datasource configuration"
    
    cat > "$${CONFIG_DIR}/grafana/provisioning/datasources/datasources.yml" <<'EOFGDS'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
    jsonData:
      maxLines: 1000
EOFGDS
}

create_grafana_dashboard_config() {
    log_info "Creating Grafana dashboard provisioning configuration"
    
    cat > "$${CONFIG_DIR}/grafana/provisioning/dashboards/dashboards.yml" <<'EOFGDB'
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOFGDB
}

create_all_configs() {
    log_section "Creating Service Configurations"
    
    create_docker_compose_config
    create_prometheus_config
    create_loki_config
    create_promtail_config
    create_grafana_datasource_config
    create_grafana_dashboard_config
    
    log_success "All configurations created"
}

# ============================================================================
# Docker Stack Management
# ============================================================================
setup_permissions() {
    log_info "Setting directory permissions"
    chown -R ubuntu:ubuntu "$${OBSERVABILITY_DIR}"
}

pull_docker_images() {
    log_section "Pulling Docker Images"
    
    cd "$${OBSERVABILITY_DIR}"
    docker-compose pull
    
    log_success "Docker images pulled"
}

start_observability_stack() {
    log_section "Starting Observability Stack"
    
    cd "$${OBSERVABILITY_DIR}"
    docker-compose up -d
    
    log_info "Waiting for services to initialize..."
    sleep 30
    
    log_success "Observability stack started"
}

# ============================================================================
# Health Check Helper
# ============================================================================
wait_for_service() {
    local service_name="$1"
    local health_url="$2"
    local max_retries="$3"
    
    local retries=0
    while [ $retries -lt $max_retries ]; do
        if curl --max-time 5 -sf "$health_url" > /dev/null 2>&1; then
            log_info "✓ $service_name is healthy"
            return 0
        fi
        ((retries++))
        if [ $retries -lt $max_retries ]; then
            log_info "Waiting for $service_name... (attempt $retries/$max_retries)"
        else
            log_error "$service_name health check failed after $((max_retries * 2)) seconds"
            return 1
        fi
        sleep 2
    done
}

verify_services() {
    log_section "Verifying Service Status"
    
    cd "$${OBSERVABILITY_DIR}"
    
    # Check container status
    log_info "Checking container status..."
    docker-compose ps
    
    # Verify all containers are running (not just created/exited)
    local expected_containers=("grafana" "prometheus" "loki" "promtail" "node-exporter")
    for container in "$${expected_containers[@]}"; do
        if ! docker ps --filter "name=$container" --filter "status=running" --format "{{.Names}}" | grep -q "^$container$"; then
            log_error "Container $container is not running"
            return 1
        fi
        log_info "✓ $container is running"
    done
    
    # Health check: wait for services to be responsive
    log_info "Performing health checks..."
    
    # Check Grafana (may take a moment to start)
    wait_for_service "Grafana" "http://localhost:3000/api/health" 30 || return 1
    
    # Check Prometheus (with retries)
    wait_for_service "Prometheus" "http://localhost:9090/-/healthy" 60 || return 1
    
    # Check Loki (with retries - can take longer to initialize)
    wait_for_service "Loki" "http://localhost:3100/ready" 60 || return 1
    
    log_success "All services verified and healthy"
}

write_completion_marker() {
    touch "$${OBSERVABILITY_DIR}/instance-ready"
    echo "Internal tools instance setup complete" > /var/log/user-data-complete.log
    
    log_success "Completion marker written"
}

# ============================================================================
# Main Execution
# ============================================================================
main() {
    log_section "Internal Tools Setup - Starting"
    log_info "Cluster: $${CLUSTER_NAME}"
    log_info "Start time: $(date)"
    
    # System setup
    install_system_packages
    install_aws_cli
    install_docker
    install_docker_compose
    
    # Environment setup
    create_directory_structure
    fetch_grafana_password
    
    # Configuration
    create_all_configs
    setup_permissions
    
    # Stack deployment
    pull_docker_images
    start_observability_stack
    
    # Verification
    verify_services
    write_completion_marker
    
    log_section "Internal Tools Setup - Complete"
    log_info "End time: $(date)"
    log_info "Docker: $(docker --version)"
    log_info "Docker Compose: $(docker-compose --version)"
}

# Run main function
main
