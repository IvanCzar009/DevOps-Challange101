#!/bin/bash

# Jenkins Installation Script
# Replaces GitLab with Jenkins CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

log "Starting Jenkins installation..."

# Create Jenkins directory
mkdir -p /home/ec2-user/jenkins
cd /home/ec2-user/jenkins

# Create docker-compose.yml for Jenkins
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  jenkins:
    image: jenkins/jenkins:2.414.1-lts
    container_name: jenkins
    restart: unless-stopped
    ports:
      - "8081:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
      - JENKINS_ADMIN_ID=admin
      - JENKINS_ADMIN_PASSWORD=admin123456
    networks:
      - jenkins_network

volumes:
  jenkins_home:

networks:
  jenkins_network:
    driver: bridge
EOF

log "Starting Jenkins container..."
docker-compose up -d

# Wait for Jenkins to start
log "Waiting for Jenkins to initialize..."
sleep 60

# Check if Jenkins is running
if docker ps | grep -q jenkins; then
    log "✅ Jenkins container is running"
else
    error "❌ Jenkins container failed to start"
    exit 1
fi

# Wait for Jenkins web interface
log "Waiting for Jenkins web interface to be ready..."
ATTEMPTS=0
MAX_ATTEMPTS=30

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:8081/login > /dev/null 2>&1; then
        log "✅ Jenkins web interface is ready!"
        break
    fi
    
    ATTEMPTS=$((ATTEMPTS + 1))
    log "Jenkins web interface check: attempt $ATTEMPTS/$MAX_ATTEMPTS"
    sleep 10
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    error "❌ Jenkins web interface failed to become ready"
    exit 1
fi

# Get Jenkins initial admin password
if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; then
    JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
    log "Jenkins Initial Admin Password: $JENKINS_PASSWORD"
else
    log "Using default admin credentials: admin/admin123456"
fi

# Display Jenkins information
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

log "=== JENKINS INSTALLATION COMPLETE ==="
echo "Jenkins Web Interface: http://$PUBLIC_IP:8081"
echo "Default Credentials: admin/admin123456"
echo "Or use initial admin password displayed above"
echo ""
log "✅ Jenkins is ready for CI/CD pipelines!"

exit 0