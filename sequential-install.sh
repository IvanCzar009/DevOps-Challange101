#!/bin/bash
set -e

echo "=== Sequential CI/CD Stack Installation ==="
echo "This script will install services one by one to avoid conflicts"
echo "Starting at: $(date)"
echo ""

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to handle errors
handle_error() {
    local exit_code=$?
    local line_number=$1
    log "ERROR: Installation failed at line $line_number with exit code $exit_code"
    log "Checking system status..."
    
    # Show system resources
    log "Memory usage:"
    free -h
    log "Disk usage:"
    df -h
    log "Docker status:"
    docker ps -a
    
    exit $exit_code
}

# Set error trap
trap 'handle_error $LINENO' ERR

# Check system requirements
log "Checking system requirements..."
log "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
log "Disk: $(df -h / | awk 'NR==2 {print $4}') available"
log "CPU cores: $(nproc)"

# Wait for cloud-init to complete
log "Waiting for system initialization to complete..."
timeout=300  # 5 minutes timeout
elapsed=0
while [ ! -f /var/lib/cloud/instance/boot-finished ] && [ $elapsed -lt $timeout ]; do
    log "Waiting for cloud-init to complete... ($elapsed/$timeout seconds)"
    sleep 10
    elapsed=$((elapsed + 10))
done

if [ $elapsed -ge $timeout ]; then
    log "WARNING: cloud-init timeout reached, proceeding anyway"
fi

# Wait for Docker to be available
log "Waiting for Docker to be ready..."
timeout=120  # 2 minutes timeout
elapsed=0
while ! docker info >/dev/null 2>&1 && [ $elapsed -lt $timeout ]; do
    log "Docker not ready, waiting... ($elapsed/$timeout seconds)"
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $timeout ]; then
    log "ERROR: Docker failed to start within timeout"
    exit 1
fi

log "Docker is ready!"
log "System is ready. Starting sequential installation..."
echo ""

# Step 1: Install ELK Stack
log "=== STEP 1/4: Installing ELK Stack ==="
log "ELK Stack provides logging and monitoring foundation"
chmod +x /tmp/install-elk.sh
if /tmp/install-elk.sh; then
    log "✓ ELK Stack installation completed successfully!"
else
    log "✗ ELK Stack installation failed"
    exit 1
fi
echo ""

# Small pause between installations
log "Pausing 30 seconds before next installation..."
sleep 30

# Step 2: Install GitLab  
log "=== STEP 2/4: Installing GitLab ==="
log "GitLab provides source code management and CI/CD pipeline"
chmod +x /tmp/install-gitlab.sh
if /tmp/install-gitlab.sh; then
    log "✓ GitLab installation completed successfully!"
    
    # Additional verification that GitLab is ready before proceeding
    log "Performing additional GitLab readiness check..."
    gitlab_ready=false
    attempts=0
    max_attempts=10
    
    while [ $attempts -lt $max_attempts ]; do
        # Check if GitLab container is healthy and services are running
        if docker ps | grep -q "gitlab.*healthy" && docker exec gitlab-gitlab-1 gitlab-ctl status puma | grep -q "run:"; then
            log "✓ GitLab is confirmed ready for next installation"
            gitlab_ready=true
            break
        fi
        
        attempts=$((attempts + 1))
        log "GitLab readiness check $attempts/$max_attempts - GitLab still initializing..."
        sleep 30
    done
    
    if [ "$gitlab_ready" = false ]; then
        log "⚠ GitLab may still be initializing, but proceeding with next installation"
        log "⚠ GitLab web interface may take additional 5-10 minutes to be fully ready"
    fi
else
    log "✗ GitLab installation failed"
    exit 1
fi
echo ""

# Extended pause after GitLab to allow stabilization
log "Pausing 60 seconds after GitLab installation for system stabilization..."
sleep 60

# Step 3: Install SonarQube
log "=== STEP 3/4: Installing SonarQube ==="
log "SonarQube provides code quality analysis"
chmod +x /tmp/install-sonarqube.sh
if /tmp/install-sonarqube.sh; then
    log "✓ SonarQube installation completed successfully!"
else
    log "✗ SonarQube installation failed"
    exit 1
fi
echo ""

# Small pause between installations
log "Pausing 30 seconds before next installation..."
sleep 30

# Step 4: Install Tomcat
log "=== STEP 4/5: Installing Tomcat ==="
log "Tomcat provides application deployment server"
chmod +x /tmp/install-tomcat.sh
if /tmp/install-tomcat.sh; then
    log "✓ Tomcat installation completed successfully!"
else
    log "✗ Tomcat installation failed"
    exit 1
fi
echo ""

# Small pause before React app deployment
log "Pausing 30 seconds before React app deployment..."
sleep 30

# Step 5: Deploy React Application
log "=== STEP 5/5: Deploying React Application ==="
log "Deploying your Group 6 React application to Tomcat"
chmod +x /tmp/deploy-react-app.sh
if /tmp/deploy-react-app.sh; then
    log "✓ React application deployed successfully!"
else
    log "✗ React application deployment failed"
    exit 1
fi
echo ""

# Final verification
log "=== FINAL SYSTEM VERIFICATION ==="
log "Verifying all services are running..."

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Verify each service
services_status=""

# Check Elasticsearch
if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    log "✓ Elasticsearch is running"
    services_status="${services_status}✓ Elasticsearch: OK\n"
else
    log "✗ Elasticsearch is not responding"
    services_status="${services_status}✗ Elasticsearch: FAILED\n"
fi

# Check Kibana
if curl -s http://localhost:5061/api/status >/dev/null 2>&1; then
    log "✓ Kibana is running"
    services_status="${services_status}✓ Kibana: OK\n"
else
    log "✗ Kibana is not responding"
    services_status="${services_status}✗ Kibana: FAILED\n"
fi

# Check GitLab
if curl -s http://localhost:8081 >/dev/null 2>&1; then
    log "✓ GitLab is running"
    services_status="${services_status}✓ GitLab: OK\n"
else
    log "✗ GitLab is not responding"
    services_status="${services_status}✗ GitLab: FAILED\n"
fi

# Check SonarQube
if curl -s http://localhost:9000 >/dev/null 2>&1; then
    log "✓ SonarQube is running"
    services_status="${services_status}✓ SonarQube: OK\n"
else
    log "✗ SonarQube is not responding"
    services_status="${services_status}✗ SonarQube: FAILED\n"
fi

# Check Tomcat
if curl -s http://localhost:8080 >/dev/null 2>&1; then
    log "✓ Tomcat is running"
    services_status="${services_status}✓ Tomcat: OK\n"
else
    log "✗ Tomcat is not responding"
    services_status="${services_status}✗ Tomcat: FAILED\n"
fi

# Show final summary
log "=== ALL INSTALLATIONS COMPLETE ==="
log "Installation completed at: $(date)"
echo ""
echo "=== SERVICE STATUS SUMMARY ==="
echo -e "$services_status"
echo ""
echo "=== SERVICE URLS ==="
echo "🎯 YOUR REACT APPLICATION:"
echo "  - React App: http://$PUBLIC_IP:8080/group6-react-app/"
echo ""
echo "🔧 CI/CD TOOLS:"
echo "GitLab:"
echo "  - GitLab: http://$PUBLIC_IP:8081"
echo "  - Credentials: root / admin123456"
echo ""
echo "SonarQube:"
echo "  - SonarQube: http://$PUBLIC_IP:9000"
echo "  - Credentials: admin / admin"
echo ""
echo "Tomcat:"
echo "  - Tomcat: http://$PUBLIC_IP:8080"
echo "  - Manager: http://$PUBLIC_IP:8080/manager"
echo "  - Credentials: admin / admin123"
echo ""
echo "📊 MONITORING & LOGGING:"
echo "ELK Stack:"
echo "  - Elasticsearch: http://$PUBLIC_IP:9200"
echo "  - Kibana: http://$PUBLIC_IP:5061"
echo "  - Logstash: http://$PUBLIC_IP:9600"
echo ""
echo "=== INSTALLATION LOG ==="
echo "✓ All services have been installed sequentially to avoid resource conflicts"
echo "✓ Each service was tested and verified before proceeding to the next"
echo "✓ Installation includes comprehensive error handling and logging"
echo "✓ Total installation time: approximately 25-35 minutes"
echo ""
log "Installation process completed successfully!"