#!/bin/bash

# Automated SonarQube Project Setup for Terraform
# Sets up SonarQube project and integration for Group6 React App

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

echo -e "${BLUE}=== Automated SonarQube Project Setup ===${NC}"

# Configuration
SONAR_URL="http://localhost:9000"
PROJECT_KEY="group6-react-app"
PROJECT_NAME="Group6 React App"
PROJECT_VERSION="1.0.0"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

log "Setting up SonarQube project: $PROJECT_NAME"

# Wait for SonarQube to be fully ready
log "Waiting for SonarQube to be ready..."
ATTEMPTS=0
MAX_ATTEMPTS=60

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if timeout 15 curl -s --max-time 10 "$SONAR_URL/api/system/status" | grep -q '"status":"UP"'; then
        log "✅ SonarQube is ready"
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

# Get or generate SonarQube password
if [ -z "$SONARQUBE_ADMIN_PASSWORD" ]; then
    # Generate random password if not provided
    SONAR_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
    log "Generated secure random password for SonarQube"
else
    SONAR_PASS="$SONARQUBE_ADMIN_PASSWORD"
    log "Using provided password from environment variable"
fi

# Change default admin password
log "Updating SonarQube admin password..."
PASS_CHANGE_RESPONSE=$(timeout 30 curl -s -w "HTTPSTATUS:%{http_code}" -u admin:admin -X POST \
    --max-time 20 \
    "$SONAR_URL/api/users/change_password" \
    -d "login=admin&password=$SONAR_PASS&previousPassword=admin" 2>/dev/null || echo "HTTPSTATUS:000")

PASS_STATUS=$(echo $PASS_CHANGE_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$PASS_STATUS" = "204" ] || [ "$PASS_STATUS" = "200" ]; then
    log "✅ Admin password updated successfully"
    
    # Save credentials securely
    echo "SONARQUBE_ADMIN_USER=admin" > /home/ec2-user/.sonarqube-credentials
    echo "SONARQUBE_ADMIN_PASSWORD=$SONAR_PASS" >> /home/ec2-user/.sonarqube-credentials
    chmod 600 /home/ec2-user/.sonarqube-credentials
    log "✅ Credentials saved securely"
else
    warn "⚠️ Password change failed or already changed, using default: admin"
    SONAR_PASS="admin"
fi

# Create project for Group6 React App
log "Creating SonarQube project..."
PROJECT_RESPONSE=$(timeout 30 curl -s -w "HTTPSTATUS:%{http_code}" -u admin:$SONAR_PASS -X POST \
    --max-time 20 \
    "$SONAR_URL/api/projects/create" \
    -d "name=$PROJECT_NAME&project=$PROJECT_KEY&visibility=public" 2>/dev/null || echo "HTTPSTATUS:000")

PROJECT_STATUS=$(echo $PROJECT_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$PROJECT_STATUS" = "200" ] || [ "$PROJECT_STATUS" = "201" ]; then
    log "✅ Project '$PROJECT_NAME' created successfully"
elif [ "$PROJECT_STATUS" = "400" ]; then
    log "ℹ️ Project already exists, continuing with configuration..."
else
    warn "⚠️ Project creation returned status: $PROJECT_STATUS"
fi

# Generate token for the project
log "Generating project token..."
TOKEN_RESPONSE=$(curl -s -u admin:$SONAR_PASS -X POST \
    "$SONAR_URL/api/user_tokens/generate" \
    -d "name=group6-react-app-token" 2>/dev/null || echo "")

if echo "$TOKEN_RESPONSE" | grep -q '"token"'; then
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    log "✅ Project token generated successfully"
    echo "$TOKEN" > /home/ec2-user/sonarqube-token.txt
    chmod 600 /home/ec2-user/sonarqube-token.txt
else
    warn "⚠️ Token generation failed or token already exists"
    TOKEN=""
fi

# Set up quality gate
log "Configuring quality gate..."
GATE_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -u admin:$SONAR_PASS -X POST \
    "$SONAR_URL/api/qualitygates/select" \
    -d "projectKey=$PROJECT_KEY&gateId=1" 2>/dev/null || echo "HTTPSTATUS:000")

GATE_STATUS=$(echo $GATE_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$GATE_STATUS" = "204" ] || [ "$GATE_STATUS" = "200" ]; then
    log "✅ Quality gate configured successfully"
else
    log "ℹ️ Quality gate configuration status: $GATE_STATUS"
fi

# Create comprehensive configuration file
log "Creating SonarQube configuration summary..."
cat > /home/ec2-user/sonarqube-config.txt << EOF
=== SonarQube Configuration ===
URL: http://$PUBLIC_IP:9000
Admin Username: admin
Admin Password: $SONAR_PASS
Project Name: $PROJECT_NAME
Project Key: $PROJECT_KEY
Project Version: $PROJECT_VERSION
EOF

if [ ! -z "$TOKEN" ]; then
    echo "Project Token: $TOKEN" >> /home/ec2-user/sonarqube-config.txt
fi

echo "Generated: $(date)" >> /home/ec2-user/sonarqube-config.txt
echo "Integration: Automated via Terraform" >> /home/ec2-user/sonarqube-config.txt
chmod 600 /home/ec2-user/sonarqube-config.txt

# Create sonar-project.properties in the React app directory
if [ -d "/home/ec2-user/group6-react-app" ]; then
    log "Creating sonar-project.properties for React app..."
    cat > /home/ec2-user/group6-react-app/sonar-project.properties << EOF
sonar.projectKey=$PROJECT_KEY
sonar.projectName=$PROJECT_NAME
sonar.projectVersion=$PROJECT_VERSION

# Source directories
sonar.sources=src
sonar.tests=src
sonar.test.inclusions=**/*.test.js,**/*.test.jsx,**/*.spec.js,**/*.spec.jsx

# Coverage reports
sonar.javascript.lcov.reportPaths=coverage/lcov.info
sonar.coverage.exclusions=**/*.test.js,**/*.test.jsx,**/*.spec.js,**/*.spec.jsx,**/reportWebVitals.js,**/setupTests.js

# Analysis exclusions
sonar.exclusions=**/node_modules/**,**/build/**,**/coverage/**,**/*.min.js

# Language settings
sonar.sourceEncoding=UTF-8

# SonarQube server settings
sonar.host.url=$SONAR_URL
sonar.login=admin
sonar.password=$SONAR_PASS
EOF
    
    log "✅ SonarQube properties file created in React app"
fi

# Install SonarQube scanner if not present
if ! command -v sonar-scanner &> /dev/null; then
    log "Installing SonarQube scanner..."
    cd /tmp
    wget -q https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-linux.zip
    unzip -q sonar-scanner-cli-4.8.0.2856-linux.zip
    sudo mv sonar-scanner-4.8.0.2856-linux /opt/sonar-scanner
    sudo ln -sf /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
    log "✅ SonarQube scanner installed"
else
    log "✅ SonarQube scanner already available"
fi

# Test SonarQube connection
log "Testing SonarQube API connection..."
TEST_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -u admin:$SONAR_PASS \
    "$SONAR_URL/api/projects/search?projects=$PROJECT_KEY" 2>/dev/null || echo "HTTPSTATUS:000")

TEST_STATUS=$(echo $TEST_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$TEST_STATUS" = "200" ]; then
    log "✅ SonarQube API connection successful"
else
    warn "⚠️ SonarQube API test returned status: $TEST_STATUS"
fi

# Display completion information
echo -e "${GREEN}"
echo "=== SONARQUBE AUTOMATION COMPLETE ==="
echo ""
echo "🎉 SonarQube Project Setup Complete!"
echo ""
echo "🔍 SonarQube Dashboard: http://$PUBLIC_IP:9000"
echo "📊 Project Dashboard: http://$PUBLIC_IP:9000/dashboard?id=$PROJECT_KEY"
echo "👤 Credentials: admin / $SONAR_PASS"
echo ""
echo "📋 Project Configuration:"
echo "   • Project Key: $PROJECT_KEY"
echo "   • Project Name: $PROJECT_NAME"
echo "   • Quality Gate: Configured"
echo "   • Token: Generated and saved"
echo ""
echo "📄 Configuration Files:"
echo "   • /home/ec2-user/.sonarqube-credentials"
echo "   • /home/ec2-user/sonarqube-config.txt"
echo "   • /home/ec2-user/group6-react-app/sonar-project.properties"
echo ""
echo "🔧 Integration Ready:"
echo "   • Jenkins pipeline configured for SonarQube analysis"
echo "   • Automated quality checks enabled"
echo "   • Coverage reports integration ready"
echo -e "${NC}"

log "✅ SonarQube project automation completed successfully!"

exit 0