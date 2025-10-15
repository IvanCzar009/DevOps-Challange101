#!/bin/bash

echo "=========================================="
echo "🔗 AUTOMATIC GITHUB WEBHOOK SETUP"
echo "=========================================="
echo "⏰ Timestamp: $(date)"
echo ""

# Repository configuration
REPO_OWNER="IvanCzar009"
REPO_NAME="DevOps-Challange101"
JENKINS_URL="http://54.241.211.48:8081"
WEBHOOK_URL="${JENKINS_URL}/github-webhook/"

echo "📋 Configuration:"
echo "   Repository: ${REPO_OWNER}/${REPO_NAME}"
echo "   Jenkins URL: ${JENKINS_URL}"
echo "   Webhook URL: ${WEBHOOK_URL}"
echo ""

# GitHub webhook configuration
WEBHOOK_CONFIG='{
  "name": "web",
  "active": true,
  "events": ["push"],
  "config": {
    "url": "'${WEBHOOK_URL}'",
    "content_type": "json",
    "insecure_ssl": "1"
  }
}'

echo "🔍 Checking existing webhooks..."
echo "Note: You'll need a GitHub Personal Access Token for this operation"
echo ""

# Check if webhook already exists
echo "=== MANUAL SETUP INSTRUCTIONS ==="
echo ""
echo "Since automatic setup requires GitHub authentication, please follow these steps:"
echo ""
echo "1. 🌐 Go to: https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/hooks"
echo "2. 🔘 Click 'Add webhook'"
echo "3. 📝 Fill in the form:"
echo "   - Payload URL: ${WEBHOOK_URL}"
echo "   - Content type: application/json"
echo "   - Secret: (leave empty)"
echo "   - SSL verification: Disable (for testing)"
echo "   - Events: Just the push event"
echo "   - Active: ✅ Checked"
echo "4. 💾 Click 'Add webhook'"
echo ""

echo "=== ALTERNATIVE: AUTOMATED SETUP ==="
echo ""
echo "If you have a GitHub Personal Access Token, you can run:"
echo "curl -X POST \\"
echo "  -H 'Authorization: token YOUR_GITHUB_TOKEN' \\"
echo "  -H 'Accept: application/vnd.github.v3+json' \\"
echo "  'https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/hooks' \\"
echo "  -d '${WEBHOOK_CONFIG}'"
echo ""

echo "=== TESTING THE WEBHOOK ==="
echo ""
echo "After setting up the webhook, test it with:"
echo "1. Make a small change to any file in the repository"
echo "2. Commit and push to the 'terraform-optimized' branch"
echo "3. Check Jenkins at: ${JENKINS_URL}/job/group6-react-app-pipeline/"
echo "4. The build should trigger automatically within 1-2 minutes"
echo ""

echo "🎯 Current Jenkins Job Status:"
curl -s "${JENKINS_URL}/job/group6-react-app-pipeline/api/json" | grep -o '"color":"[^"]*"' || echo "   Job status check requires authentication"

echo ""
echo "✅ Webhook setup guide completed!"
echo "=========================================="