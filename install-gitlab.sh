#!/bin/bash
set -e

echo "=== Installing GitLab ==="
echo "Starting at: $(date)"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a service is responding
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=${3:-30}
    local attempt=0
    
    log "Waiting for $service_name to be ready at $url..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            log "$service_name is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        log "Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 20
    done
    log "ERROR: $service_name failed to start after $max_attempts attempts"
    return 1
}

# Check system resources
log "Checking system resources..."
free -h
df -h

# Create GitLab directory
log "Creating GitLab directory..."
mkdir -p /home/ec2-user/gitlab
cd /home/ec2-user/gitlab

# Create PostgreSQL and GitLab docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:13
    container_name: gitlab-postgres
    environment:
      POSTGRES_DB: gitlabhq_production
      POSTGRES_USER: gitlab
      POSTGRES_PASSWORD: gitlab_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - gitlab_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gitlab"]
      interval: 30s
      timeout: 10s
      retries: 5

  gitlab:
    image: gitlab/gitlab-ce:16.5.1-ce.0
    container_name: gitlab
    hostname: 'localhost'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://localhost:8081'
        gitlab_rails['db_adapter'] = 'postgresql'
        gitlab_rails['db_encoding'] = 'unicode'
        gitlab_rails['db_host'] = 'postgres'
        gitlab_rails['db_port'] = 5432
        gitlab_rails['db_database'] = 'gitlabhq_production'
        gitlab_rails['db_username'] = 'gitlab'
        gitlab_rails['db_password'] = 'gitlab_password'
        gitlab_rails['initial_root_password'] = 'admin123456'
        postgresql['enable'] = false
        nginx['listen_port'] = 80
        nginx['listen_https'] = false
        gitlab_ci_multi_runner['concurrent'] = 4
    ports:
      - "8081:80"
      - "8443:443"
      - "8022:22"
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
    networks:
      - gitlab_network
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost/-/health || exit 1"]
      interval: 60s
      timeout: 30s
      retries: 15
      start_period: 600s

volumes:
  postgres_data:
  gitlab_config:
  gitlab_logs:
  gitlab_data:

networks:
  gitlab_network:
    driver: bridge
EOF

log "Starting GitLab (this may take several minutes)..."
if ! docker-compose up -d; then
    log "ERROR: Failed to start GitLab containers"
    exit 1
fi

log "Waiting for PostgreSQL to be ready..."
sleep 60

# Wait for PostgreSQL to be healthy first
counter=0
max_attempts=10
while [ $counter -lt $max_attempts ]; do
    if docker-compose ps postgres | grep -q "healthy"; then
        log "PostgreSQL is healthy!"
        break
    fi
    counter=$((counter+1))
    log "Attempt $counter/$max_attempts - PostgreSQL still starting..."
    sleep 15
done

if [ $counter -eq $max_attempts ]; then
    log "ERROR: PostgreSQL failed to start"
    docker-compose logs postgres
    exit 1
fi

log "Waiting for GitLab to initialize (this can take 10-15 minutes)..."
log "GitLab is performing initial setup, please be patient..."

# Wait for GitLab to be healthy (extended timeout for initial setup)
counter=0
max_attempts=45  # 45 * 20 = 15 minutes
while [ $counter -lt $max_attempts ]; do
    # Check if GitLab container is healthy
    if docker-compose ps gitlab | grep -q "healthy"; then
        log "GitLab is healthy!"
        break
    fi
    
    # Show progress every 5 attempts
    if [ $((counter % 5)) -eq 0 ]; then
        log "GitLab initialization progress: $counter/$max_attempts attempts ($(($counter * 20 / 60)) minutes elapsed)"
        docker-compose ps
    fi
    
    counter=$((counter+1))
    sleep 20
done

if [ $counter -eq $max_attempts ]; then
    log "ERROR: GitLab failed to initialize after 15 minutes"
    log "Checking GitLab logs for errors..."
    docker-compose logs --tail=50 gitlab
    exit 1
fi

# Function to perform GitLab reconfiguration
gitlab_reconfigure() {
    log "=== Starting GitLab Reconfiguration ==="
    
    # Wait for GitLab container to be fully ready
    log "Ensuring GitLab container is ready for reconfiguration..."
    sleep 30
    
    # Perform gitlab-ctl reconfigure
    log "Running gitlab-ctl reconfigure (this may take a few minutes)..."
    if docker exec gitlab gitlab-ctl reconfigure; then
        log "✓ GitLab reconfigure completed successfully"
    else
        log "⚠ GitLab reconfigure had issues, checking status..."
        docker exec gitlab gitlab-ctl status
    fi
    
    # Restart GitLab services to ensure clean state
    log "Restarting GitLab services..."
    if docker exec gitlab gitlab-ctl restart; then
        log "✓ GitLab services restarted"
    else
        log "⚠ GitLab service restart had issues"
    fi
    
    # Wait for services to stabilize
    log "Waiting for GitLab services to stabilize..."
    sleep 60
    
    # Verify all GitLab services are running
    log "Checking GitLab service status..."
    docker exec gitlab gitlab-ctl status
    
    # Wait for web interface to be fully ready
    log "Waiting for GitLab web interface to be ready..."
    local attempts=0
    local max_attempts=20
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -s -f "http://localhost:8081" >/dev/null 2>&1; then
            log "✓ GitLab web interface is responding!"
            break
        elif curl -s "http://localhost:8081" | grep -q "GitLab\|sign_in\|302"; then
            log "✓ GitLab web interface is responding with redirect!"
            break
        fi
        
        attempts=$((attempts + 1))
        log "Attempt $attempts/$max_attempts - GitLab web interface not ready yet..."
        sleep 15
    done
    
    if [ $attempts -eq $max_attempts ]; then
        log "⚠ GitLab web interface verification timeout, but continuing..."
        log "GitLab may need additional time to fully initialize"
    fi
    
    log "=== GitLab Reconfiguration Complete ===''"
}

# Function to verify GitLab is fully operational
verify_gitlab_operational() {
    log "=== Verifying GitLab is Fully Operational ==="
    
    # Check container health
    if docker-compose ps gitlab | grep -q "healthy"; then
        log "✓ GitLab container is healthy"
    else
        log "⚠ GitLab container health status unclear"
        docker-compose ps gitlab
    fi
    
    # Check GitLab internal services
    log "Checking GitLab internal services..."
    docker exec gitlab gitlab-ctl status
    
    # Test web interface accessibility
    log "Testing GitLab web interface..."
    local web_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081" || echo "000")
    case $web_status in
        200|302)
            log "✓ GitLab web interface is accessible (HTTP $web_status)"
            ;;
        000)
            log "⚠ GitLab web interface connection failed"
            ;;
        *)
            log "⚠ GitLab web interface returned HTTP $web_status"
            ;;
    esac
    
    # Test GitLab API health endpoint
    log "Testing GitLab health endpoint..."
    local health_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081/-/health" || echo "000")
    if [ "$health_status" = "200" ]; then
        log "✓ GitLab health endpoint is responding"
    else
        log "⚠ GitLab health endpoint returned HTTP $health_status"
    fi
    
    log "=== GitLab Verification Complete ==="
}

# Execute GitLab reconfiguration
gitlab_reconfigure

# Verify GitLab is operational before proceeding
verify_gitlab_operational

# Final status check
log "Checking final GitLab status..."
docker-compose ps

# Summary
echo ""
echo "=== GitLab Installation and Configuration Complete ==="
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
echo "GitLab URL: http://$PUBLIC_IP:8081"
echo "Default credentials: root / admin123456"
echo ""
echo "GitLab Services Status:"
docker exec gitlab gitlab-ctl status | head -10
echo ""
echo "⚠ Note: GitLab may need additional 5-10 minutes for full web interface availability"
echo "   If web interface is not immediately accessible, please wait and try again"
echo ""