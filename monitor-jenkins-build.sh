#!/bin/bash

# Monitor Jenkins Build Progress
# Shows real-time build status and completion

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

echo -e "${BLUE}=== Monitoring Jenkins Pipeline Progress ===${NC}"

# Configuration
JENKINS_URL="http://localhost:8081"
JENKINS_USER="admin"
JENKINS_PASS="${JENKINS_ADMIN_PASSWORD:-admin123456}"
JOB_NAME="group6-react-app-pipeline"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

log "Monitoring Jenkins pipeline: $JOB_NAME"

# Function to check build status
check_build_status() {
    local BUILD_INFO=$(curl -s -u $JENKINS_USER:$JENKINS_PASS "$JENKINS_URL/job/$JOB_NAME/api/json" 2>/dev/null || echo "")
    
    if echo "$BUILD_INFO" | grep -q '"building":true'; then
        echo "BUILDING"
    elif echo "$BUILD_INFO" | grep -q '"inQueue":true'; then
        echo "QUEUED"
    elif echo "$BUILD_INFO" | grep -q '"lastBuild"'; then
        local LAST_BUILD=$(echo "$BUILD_INFO" | grep -o '"lastBuild":{"number":[0-9]*' | grep -o '[0-9]*')
        if [ ! -z "$LAST_BUILD" ]; then
            local BUILD_RESULT=$(curl -s -u $JENKINS_USER:$JENKINS_PASS "$JENKINS_URL/job/$JOB_NAME/$LAST_BUILD/api/json" 2>/dev/null | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
            echo "COMPLETED:$BUILD_RESULT:$LAST_BUILD"
        fi
    else
        echo "UNKNOWN"
    fi
}

# Monitor for up to 30 minutes
ATTEMPTS=0
MAX_ATTEMPTS=180  # 30 minutes with 10-second intervals

log "Starting build monitoring..."

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    STATUS=$(check_build_status)
    
    case $STATUS in
        "BUILDING")
            log "🔄 Build is currently running... (attempt $((ATTEMPTS + 1))/$MAX_ATTEMPTS)"
            ;;
        "QUEUED")
            log "⏳ Build is queued and waiting to start..."
            ;;
        "COMPLETED:SUCCESS:"*)
            BUILD_NUM=$(echo $STATUS | cut -d':' -f3)
            log "✅ Build #$BUILD_NUM completed successfully!"
            echo ""
            echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL! 🎉${NC}"
            echo ""
            echo "📊 Jenkins Pipeline: http://$PUBLIC_IP:8081/job/$JOB_NAME"
            echo "🌐 Your React App: http://$PUBLIC_IP:8080/group6-react-app"
            echo "🔍 SonarQube Report: http://$PUBLIC_IP:9000/dashboard?id=group6-react-app"
            echo ""
            exit 0
            ;;
        "COMPLETED:FAILURE:"*)
            BUILD_NUM=$(echo $STATUS | cut -d':' -f3)
            warn "❌ Build #$BUILD_NUM failed!"
            echo ""
            echo "💡 Check the build logs at:"
            echo "   http://$PUBLIC_IP:8081/job/$JOB_NAME/$BUILD_NUM/console"
            echo ""
            exit 1
            ;;
        "COMPLETED:ABORTED:"*)
            BUILD_NUM=$(echo $STATUS | cut -d':' -f3)
            warn "⚠️ Build #$BUILD_NUM was aborted"
            exit 1
            ;;
        *)
            log "ℹ️ Waiting for build to start..."
            ;;
    esac
    
    ATTEMPTS=$((ATTEMPTS + 1))
    sleep 10
done

warn "⏰ Build monitoring timed out after 30 minutes"
log "💡 Check Jenkins manually at: http://$PUBLIC_IP:8081/job/$JOB_NAME"

exit 0