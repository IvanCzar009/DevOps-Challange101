#!/bin/bash

# SonarQube Automatic Configuration Script
# Configures SonarQube after installation with API calls

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

echo -e "${BLUE}=== Configuring SonarQube Automatically ===${NC}"

# Wait for SonarQube to be fully ready
log "Waiting for SonarQube to be ready..."
ATTEMPTS=0
MAX_ATTEMPTS=60

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if curl -s -u admin:admin http://localhost:9000/api/system/status | grep -q '"status":"UP"'; then
        log "✅ SonarQube is ready for configuration"
        break
    fi
    
    ATTEMPTS=$((ATTEMPTS + 1))
    log "SonarQube readiness check: attempt $ATTEMPTS/$MAX_ATTEMPTS"
    sleep 10
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    error "❌ SonarQube failed to become ready"
    exit 1
fi

# Generate or use environment variable for password
if [ -z "$SONARQUBE_ADMIN_PASSWORD" ]; then
    # Generate random 16-character password
    SONAR_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
    log "Generated secure random password: $SONAR_PASS"
else
    SONAR_PASS="$SONARQUBE_ADMIN_PASSWORD"
    log "Using provided password from environment variable"
fi

# Change default admin password
log "Updating admin password..."
curl -s -u admin:admin -X POST \
  "http://localhost:9000/api/users/change_password" \
  -d "login=admin&password=$SONAR_PASS&previousPassword=admin" > /dev/null

if [ $? -eq 0 ]; then
    log "✅ Admin password updated successfully"
    # Save credentials securely
    echo "SONARQUBE_ADMIN_USER=admin" > /home/ec2-user/.sonarqube-credentials
    echo "SONARQUBE_ADMIN_PASSWORD=$SONAR_PASS" >> /home/ec2-user/.sonarqube-credentials
    chmod 600 /home/ec2-user/.sonarqube-credentials
    log "✅ Credentials saved to /home/ec2-user/.sonarqube-credentials"
else
    warn "⚠️ Password change failed, using default: admin"
    SONAR_PASS="admin"
fi

# Create project for Group6 React App
log "Creating project for Group6 React App..."
curl -s -u admin:$SONAR_PASS -X POST \
  "http://localhost:9000/api/projects/create" \
  -d "name=Group6-React-App&project=group6-react-app&visibility=public" > /dev/null

if [ $? -eq 0 ]; then
    log "✅ Group6 React App project created"
else
    warn "⚠️ Project creation failed (may already exist)"
fi

# Generate token for the project
log "Generating project token..."
TOKEN_RESPONSE=$(curl -s -u admin:$SONAR_PASS -X POST \
  "http://localhost:9000/api/user_tokens/generate" \
  -d "name=group6-react-app-token")

if echo "$TOKEN_RESPONSE" | grep -q '"token"'; then
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    log "✅ Project token generated: $TOKEN"
    echo "SonarQube Token: $TOKEN" > /home/ec2-user/sonarqube-token.txt
else
    warn "⚠️ Token generation failed"
fi

# Set up quality gate
log "Configuring quality gate..."
curl -s -u admin:$SONAR_PASS -X POST \
  "http://localhost:9000/api/qualitygates/select" \
  -d "projectKey=group6-react-app&gateId=1" > /dev/null

log "✅ Quality gate configured"

# Display configuration summary
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create comprehensive credentials file
cat > /home/ec2-user/sonarqube-config.txt << EOF
=== SonarQube Configuration ===
URL: http://$PUBLIC_IP:9000
Admin Username: admin
Admin Password: $SONAR_PASS
Project Name: Group6-React-App
Project Key: group6-react-app
EOF

if [ ! -z "$TOKEN" ]; then
    echo "Project Token: $TOKEN" >> /home/ec2-user/sonarqube-config.txt
fi

echo "Generated: $(date)" >> /home/ec2-user/sonarqube-config.txt
chmod 600 /home/ec2-user/sonarqube-config.txt

echo -e "${GREEN}"
echo "=== SonarQube Configuration Complete ==="
echo "URL: http://$PUBLIC_IP:9000"
echo "Admin Login: admin"
echo "Admin Password: $SONAR_PASS"
echo "Project: Group6-React-App"
echo "Project Key: group6-react-app"
if [ ! -z "$TOKEN" ]; then
    echo "Project Token: $TOKEN"
fi
echo ""
echo "📄 All credentials saved to:"
echo "   • /home/ec2-user/.sonarqube-credentials"
echo "   • /home/ec2-user/sonarqube-config.txt"
echo "   • /home/ec2-user/sonarqube-token.txt"
echo -e "${NC}"

log "✅ SonarQube is fully configured and ready!"

exit 0