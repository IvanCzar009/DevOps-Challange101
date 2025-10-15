#!/bin/bash

echo "=========================================="
echo "🔗 GITHUB WEBHOOK TEST & SETUP"
echo "=========================================="
echo "⏰ Timestamp: $(date)"
echo ""

# Configuration
REPO_URL="https://github.com/IvanCzar009/DevOps-Challange101"
JENKINS_URL="http://54.241.211.48:8081"
WEBHOOK_URL="${JENKINS_URL}/github-webhook/"
JOB_URL="${JENKINS_URL}/job/group6-react-app-pipeline/"

echo "📋 Current Configuration:"
echo "   Repository: ${REPO_URL}"
echo "   Jenkins Job: ${JOB_URL}"
echo "   Webhook URL: ${WEBHOOK_URL}"
echo ""

echo "=== STEP 1: MANUAL WEBHOOK SETUP ==="
echo ""
echo "🌐 Open this URL in your browser:"
echo "   ${REPO_URL}/settings/hooks"
echo ""
echo "📝 Click 'Add webhook' and use these settings:"
echo "   • Payload URL: ${WEBHOOK_URL}"
echo "   • Content type: application/json"
echo "   • Secret: (leave empty)"
echo "   • SSL verification: Disable (for testing)"
echo "   • Events: Just the push event"
echo "   • Active: ✅ Checked"
echo ""

echo "=== STEP 2: TEST THE WEBHOOK ==="
echo ""
echo "After setting up the webhook, I'll create a test file to trigger the pipeline..."

# Create a test file with timestamp
TEST_FILE="webhook-test-$(date +%Y%m%d-%H%M%S).txt"
echo "🧪 Webhook integration test - $(date)" > "${TEST_FILE}"
echo "✅ Jenkins job: group6-react-app-pipeline" >> "${TEST_FILE}"
echo "🔗 Repository: DevOps-Challange101" >> "${TEST_FILE}"
echo "🌿 Branch: terraform-optimized" >> "${TEST_FILE}"
echo "🚀 Pipeline triggered automatically via GitHub webhook" >> "${TEST_FILE}"

echo "📄 Created test file: ${TEST_FILE}"
echo ""

# Add the file to git
echo "📦 Adding test file to git..."
git add "${TEST_FILE}"

# Show git status
echo ""
echo "📊 Git status:"
git status --short

echo ""
echo "=== STEP 3: COMMIT AND PUSH ==="
echo ""
echo "📝 Creating commit..."
git commit -m "🧪 Test webhook integration - $(date +%Y-%m-%d_%H:%M:%S)

This commit tests the GitHub webhook integration with Jenkins.
- Auto-trigger: Jenkins job should start automatically
- Pipeline: group6-react-app-pipeline
- Branch: terraform-optimized
- Webhook URL: ${WEBHOOK_URL}"

echo ""
echo "🚀 Pushing to terraform-optimized branch..."
git push origin terraform-optimized

echo ""
echo "=== STEP 4: VERIFY PIPELINE EXECUTION ==="
echo ""
echo "✅ Commit pushed successfully!"
echo ""
echo "🔍 Check these URLs to verify the webhook is working:"
echo "   • Jenkins Job: ${JOB_URL}"
echo "   • Build History: ${JOB_URL}builds"
echo "   • Console Output: ${JOB_URL}lastBuild/console"
echo ""
echo "⏱️ The pipeline should start within 1-2 minutes."
echo "💡 Look for a new build number in the Jenkins dashboard."
echo ""

echo "=== TROUBLESHOOTING ==="
echo ""
echo "If the pipeline doesn't trigger automatically:"
echo "1. ✅ Verify webhook was created at: ${REPO_URL}/settings/hooks"
echo "2. 🔧 Check webhook delivery status for errors"
echo "3. 🔍 Verify Jenkins job configuration includes GitHub trigger"
echo "4. 🌐 Test webhook URL directly: ${WEBHOOK_URL}"
echo ""

echo "✅ Webhook test completed!"
echo "=========================================="