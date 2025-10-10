#!/bin/bash

# Pre-Integration Validation Script
# Run this to ensure your infrastructure is ready for GitHub integration

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[CHECK] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Pre-Integration Validation              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
info "Public IP: $PUBLIC_IP"

ERRORS=0

# Check Jenkins
log "Checking Jenkins..."
if curl -s http://localhost:8081 > /dev/null 2>&1; then
    log "✅ Jenkins is running"
    
    # Check if job exists
    if curl -s -u admin:admin123456 http://localhost:8081/job/group6-react-app-pipeline/api/json > /dev/null 2>&1; then
        log "✅ Jenkins job 'group6-react-app-pipeline' exists"
    else
        error "❌ Jenkins job 'group6-react-app-pipeline' does not exist"
        ERRORS=$((ERRORS + 1))
    fi
else
    error "❌ Jenkins is not accessible"
    ERRORS=$((ERRORS + 1))
fi

# Check SonarQube
log "Checking SonarQube..."
if curl -s http://localhost:9000 > /dev/null 2>&1; then
    log "✅ SonarQube is running"
else
    error "❌ SonarQube is not accessible"
    ERRORS=$((ERRORS + 1))
fi

# Check Tomcat
log "Checking Tomcat..."
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    log "✅ Tomcat is running"
    
    # Check React app
    if curl -s http://localhost:8080/group6-react-app > /dev/null 2>&1; then
        log "✅ React app is deployed"
    else
        warn "⚠️  React app might not be deployed yet"
    fi
else
    error "❌ Tomcat is not accessible"
    ERRORS=$((ERRORS + 1))
fi

# Check Kibana
log "Checking Kibana..."
if curl -s http://localhost:8443 > /dev/null 2>&1; then
    log "✅ Kibana is running on port 8443"
elif curl -s http://localhost:5061 > /dev/null 2>&1; then
    warn "⚠️  Kibana is running on old port 5061 (should be 8443)"
else
    error "❌ Kibana is not accessible"
    ERRORS=$((ERRORS + 1))
fi

# Check ELK Stack
log "Checking ELK Stack..."
if curl -s http://localhost:9200 > /dev/null 2>&1; then
    log "✅ Elasticsearch is running"
else
    warn "⚠️  Elasticsearch might not be accessible"
fi

# Check Docker containers
log "Checking Docker containers..."
CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(sonarqube|postgres|kibana|elasticsearch|logstash)" || echo "")
if [ ! -z "$CONTAINERS" ]; then
    log "✅ Docker containers are running:"
    echo "$CONTAINERS"
else
    warn "⚠️  Some Docker containers might not be running"
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    log "🎉 All checks passed! Ready for GitHub integration."
    echo ""
    info "Next steps:"
    info "1. Set your GitHub token: export GITHUB_TOKEN='your_token'"
    info "2. Run: ./setup-github-integration.sh"
else
    error "❌ $ERRORS error(s) found. Please fix before running GitHub integration."
    echo ""
    info "Troubleshooting:"
    info "1. Check if Terraform deployment completed successfully"
    info "2. Wait a few minutes for all services to start"
    info "3. Check logs: docker logs <container_name>"
fi

echo ""
info "Service URLs:"
info "  Jenkins: http://$PUBLIC_IP:8081"
info "  SonarQube: http://$PUBLIC_IP:9000"
info "  React App: http://$PUBLIC_IP:8080/group6-react-app"
info "  Kibana: http://$PUBLIC_IP:8443"