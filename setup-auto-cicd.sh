#!/bin/bash

# GitHub Webhook Setup for Jenkins Auto-trigger
# This script sets up automatic CI/CD pipeline triggering

echo "=== Setting up GitHub Webhook Integration ==="

# Jenkins server details
JENKINS_URL="http://54.67.22.49:8081"
JENKINS_USER="admin"
JENKINS_PASS="admin123456"
JOB_NAME="group6-react-app-pipeline"

# GitHub repository details
GITHUB_REPO="https://github.com/IvanCzar009/DevOps-Challange101.git"
GITHUB_BRANCH="terraform-optimized"

echo "[1/5] Creating Jenkins job with Git integration..."

# Get CSRF crumb
CRUMB=$(curl -s "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" --user $JENKINS_USER:$JENKINS_PASS)
echo "CSRF Crumb: $CRUMB"

# Create job configuration XML
cat > /tmp/jenkins-job-config.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Auto-triggered CI/CD Pipeline for Group6 React App</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.SCMTrigger>
          <spec>H/5 * * * *</spec>
          <ignorePostCommitHooks>false</ignorePostCommitHooks>
        </hudson.triggers.SCMTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/IvanCzar009/DevOps-Challange101.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/terraform-optimized</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

echo "[2/5] Creating Jenkins job via API..."

# Create the job
curl -X POST "$JENKINS_URL/createItem?name=$JOB_NAME" \
  --user $JENKINS_USER:$JENKINS_PASS \
  -H "$CRUMB" \
  -H "Content-Type: text/xml" \
  --data-binary @/tmp/jenkins-job-config.xml

echo "[3/5] Configuring Git polling..."

# Enable Git polling for the job
curl -X POST "$JENKINS_URL/job/$JOB_NAME/polling" \
  --user $JENKINS_USER:$JENKINS_PASS \
  -H "$CRUMB"

echo "[4/5] Setting up webhook endpoint..."

# Jenkins webhook URL for GitHub
WEBHOOK_URL="$JENKINS_URL/github-webhook/"

echo "
=== WEBHOOK SETUP COMPLETE ===

🔗 Jenkins Job: $JENKINS_URL/job/$JOB_NAME
🎯 Webhook URL: $WEBHOOK_URL

📋 GitHub Webhook Configuration:
1. Go to your GitHub repository: https://github.com/IvanCzar009/DevOps-Challange101
2. Click Settings → Webhooks → Add webhook
3. Payload URL: $WEBHOOK_URL
4. Content type: application/json
5. Events: Just the push event
6. Active: ✓ checked

🚀 Auto-trigger Features:
✅ Automatic build on Git push
✅ Polls repository every 5 minutes
✅ Full CI/CD pipeline execution
✅ Automatic deployment to Tomcat

🎉 Your pipeline will now trigger automatically when you push code!
"

echo "[5/5] Testing initial build..."

# Trigger initial build
curl -X POST "$JENKINS_URL/job/$JOB_NAME/build" \
  --user $JENKINS_USER:$JENKINS_PASS \
  -H "$CRUMB"

echo "✅ Setup complete! Check Jenkins dashboard for build status."