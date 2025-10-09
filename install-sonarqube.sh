#!/bin/bash
set -e

echo "=== Installing SonarQube ==="
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
        sleep 10
    done
    log "ERROR: $service_name failed to start after $max_attempts attempts"
    return 1
}

# Create SonarQube directory
log "Creating SonarQube directory..."
mkdir -p /home/ec2-user/sonarqube
cd /home/ec2-user/sonarqube

# Create SonarQube docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  sonarqube-postgres:
    image: postgres:13
    container_name: sonarqube-postgres
    environment:
      POSTGRES_DB: sonarqube
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar_password
    volumes:
      - sonar_postgres_data:/var/lib/postgresql/data
    networks:
      - sonar_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar"]
      interval: 30s
      timeout: 10s
      retries: 5

  sonarqube:
    image: sonarqube:10.2-community
    container_name: sonarqube
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-postgres:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar_password
    ports:
      - "9000:9000"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    networks:
      - sonar_network
    depends_on:
      sonarqube-postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9000/api/system/status || exit 1"]
      interval: 60s
      timeout: 30s
      retries: 10
      start_period: 300s

volumes:
  sonar_postgres_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:

networks:
  sonar_network:
    driver: bridge
EOF

log "Starting SonarQube..."
if ! docker-compose up -d; then
    log "ERROR: Failed to start SonarQube containers"
    exit 1
fi

log "Waiting for PostgreSQL to be ready..."
sleep 30

# Wait for PostgreSQL to be healthy first
counter=0
max_attempts=10
while [ $counter -lt $max_attempts ]; do
    if docker-compose ps sonarqube-postgres | grep -q "healthy"; then
        log "SonarQube PostgreSQL is healthy!"
        break
    fi
    counter=$((counter+1))
    log "Attempt $counter/$max_attempts - PostgreSQL still starting..."
    sleep 10
done

if [ $counter -eq $max_attempts ]; then
    log "ERROR: SonarQube PostgreSQL failed to start"
    docker-compose logs sonarqube-postgres
    exit 1
fi

log "Waiting for SonarQube to be ready (this can take 3-5 minutes)..."
counter=0
max_attempts=20  # 20 * 15 = 5 minutes
while [ $counter -lt $max_attempts ]; do
    # Check if SonarQube API is responding
    if curl -s http://localhost:9000/api/system/status | grep -q "UP"; then
        log "SonarQube is ready!"
        break
    fi
    
    # Show progress every 3 attempts
    if [ $((counter % 3)) -eq 0 ]; then
        log "SonarQube startup progress: $counter/$max_attempts attempts ($(($counter * 15 / 60)) minutes elapsed)"
        # Check if container is still running
        if ! docker-compose ps sonarqube | grep -q "Up"; then
            log "ERROR: SonarQube container is not running"
            docker-compose logs --tail=20 sonarqube
            exit 1
        fi
    fi
    
    counter=$((counter+1))
    sleep 15
done

if [ $counter -eq $max_attempts ]; then
    log "ERROR: SonarQube failed to start after 5 minutes"
    log "Checking SonarQube logs for errors..."
    docker-compose logs --tail=50 sonarqube
    exit 1
fi

# Check final status
log "Checking SonarQube final status..."
docker-compose ps

# Run automatic configuration
log "Starting automatic SonarQube configuration..."
if [ -f "/tmp/configure-sonarqube.sh" ]; then
    chmod +x /tmp/configure-sonarqube.sh
    /tmp/configure-sonarqube.sh
else
    warn "Automatic configuration script not found, skipping..."
fi

echo ""
echo "=== SonarQube Installation Complete ==="
echo "SonarQube: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "Admin credentials: admin / admin123 (or admin/admin if auto-config failed)"
echo "Project: Group6-React-App already created and configured"
echo ""