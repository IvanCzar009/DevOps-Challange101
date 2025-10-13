#!/bin/bash

echo "=== TRIGGERING JENKINS PIPELINE ==="

JENKINS_URL="http://localhost:8081"
JENKINS_USER="admin"
JENKINS_PASS="admin123456"
JOB_NAME="group6-auto-pipeline"

echo "[1/3] Getting CSRF crumb..."
CRUMB=$(curl -s "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" --user ${JENKINS_USER}:${JENKINS_PASS})
echo "CSRF Crumb: $CRUMB"

echo "[2/3] Triggering pipeline build..."
RESPONSE=$(curl -X POST "${JENKINS_URL}/job/${JOB_NAME}/build" \
    --user ${JENKINS_USER}:${JENKINS_PASS} \
    -H "$CRUMB" \
    -w "%{http_code}" \
    -s)

echo "HTTP Response: $RESPONSE"

echo "[3/3] Checking build status..."
sleep 3

# Get latest build number
BUILD_NUMBER=$(curl -s "${JENKINS_URL}/job/${JOB_NAME}/api/json" --user ${JENKINS_USER}:${JENKINS_PASS} | grep -o '"lastBuild":{"number":[0-9]*' | grep -o '[0-9]*$')

if [ -n "$BUILD_NUMBER" ]; then
    echo "✅ Build #${BUILD_NUMBER} started successfully!"
    echo ""
    echo "🚀 Pipeline Status:"
    echo "• Job URL: http://54.67.22.49:8081/job/${JOB_NAME}"
    echo "• Build Console: http://54.67.22.49:8081/job/${JOB_NAME}/${BUILD_NUMBER}/console"
    echo "• Build Progress: http://54.67.22.49:8081/job/${JOB_NAME}/${BUILD_NUMBER}/"
    echo ""
    echo "📋 Pipeline Stages:"
    echo "1. 🔄 Git Checkout from GitHub"
    echo "2. 🏗️  React App Build & Test"
    echo "3. 🔍 SonarQube Code Analysis"
    echo "4. 🚀 Deploy to Tomcat"
    echo "5. ✅ Health Checks"
    echo ""
    echo "🌐 Once deployed, access your app at:"
    echo "   http://54.67.22.49:8080/group6-react-app/"
    echo ""
    echo "⏱️  Build typically takes 3-5 minutes to complete."
else
    echo "❌ Failed to get build number. Check Jenkins manually."
fi

echo ""
echo "🎯 Monitor progress at: http://54.67.22.49:8081/job/${JOB_NAME}/lastBuild/console"