#!/bin/bash

# GitHub Integration Script for Jenkins Pipeline
# Connects existing Jenkins job to GitHub repository and sets up webhooks
# Run this AFTER terraform apply completes successfully

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 GitHub Integration Setup                     ║${NC}"
echo -e "${BLUE}║           Connecting Jenkins to GitHub Repository            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"

# Configuration
JENKINS_URL="http://localhost:8081"
JENKINS_USER="admin"
JENKINS_PASS="${JENKINS_ADMIN_PASSWORD:-admin123456}"
JOB_NAME="group6-react-app-pipeline"

# GitHub Configuration (you can modify these or pass as environment variables)
GITHUB_REPO="${GITHUB_REPO:-IvanCzar009/DevOps-Challange101}"
GITHUB_BRANCH="${GITHUB_BRANCH:-terraform-optimized}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
JENKINSFILE_PATH="${JENKINSFILE_PATH:-group6-react-app/Jenkinsfile}"

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
WEBHOOK_URL="http://${PUBLIC_IP}:8081/github-webhook/"

info "Configuration:"
info "  GitHub Repository: $GITHUB_REPO"
info "  GitHub Branch: $GITHUB_BRANCH"
info "  Jenkins Job: $JOB_NAME"
info "  Jenkins URL: $JENKINS_URL"
info "  Webhook URL: $WEBHOOK_URL"
info "  Public IP: $PUBLIC_IP"

# Validate GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    error "GitHub token is required!"
    echo ""
    echo "Please set your GitHub Personal Access Token:"
    echo "  export GITHUB_TOKEN='your_github_token_here'"
    echo ""
    echo "Token requirements:"
    echo "  ✓ repo (Full control of private repositories)"
    echo "  ✓ admin:repo_hook (Admin access to repository hooks)"
    echo ""
    echo "Create token at: https://github.com/settings/tokens"
    exit 1
fi

# Validate GitHub token format
if [[ ! $GITHUB_TOKEN =~ ^gh[pousr]_[A-Za-z0-9_]{36,}$ ]]; then
    warn "GitHub token format might be incorrect"
    warn "Expected format: ghp_... or gho_... or ghu_... or ghs_..."
fi

# Function to wait for Jenkins
wait_for_jenkins() {
    log "Waiting for Jenkins to be ready..."
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -s -u $JENKINS_USER:$JENKINS_PASS --max-time 10 $JENKINS_URL/api/json > /dev/null 2>&1; then
            success "✅ Jenkins is ready and accessible"
            return 0
        fi
        
        attempts=$((attempts + 1))
        info "Jenkins readiness check: attempt $attempts/$max_attempts"
        sleep 10
    done
    
    error "❌ Jenkins failed to become ready after $max_attempts attempts"
    return 1
}

# Function to check if job exists
check_job_exists() {
    log "Checking if Jenkins job '$JOB_NAME' exists..."
    
    if curl -s -u $JENKINS_USER:$JENKINS_PASS $JENKINS_URL/job/$JOB_NAME/api/json > /dev/null 2>&1; then
        success "✅ Jenkins job '$JOB_NAME' exists"
        return 0
    else
        error "❌ Jenkins job '$JOB_NAME' does not exist"
        echo ""
        echo "Please ensure your Terraform deployment completed successfully."
        echo "The automate-jenkins-pipeline.sh script should have created this job."
        return 1
    fi
}

# Function to install required Jenkins plugins
install_jenkins_plugins() {
    log "Installing required Jenkins plugins..."
    
    # Download Jenkins CLI
    if [ ! -f "/tmp/jenkins-cli.jar" ]; then
        curl -s $JENKINS_URL/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar
    fi
    
    # List of required plugins
    local plugins=(
        "github"
        "github-branch-source"
        "pipeline-github-lib"
        "github-pullrequest"
        "pipeline-stage-view"
        "workflow-cps"
        "workflow-job"
        "workflow-aggregator"
        "git"
        "credentials"
        "plain-credentials"
    )
    
    info "Installing plugins: ${plugins[*]}"
    
    # Install plugins using Jenkins CLI
    for plugin in "${plugins[@]}"; do
        info "Installing plugin: $plugin"
        java -jar /tmp/jenkins-cli.jar -s $JENKINS_URL -auth $JENKINS_USER:$JENKINS_PASS install-plugin $plugin || warn "Plugin $plugin might already be installed"
    done
    
    log "Restarting Jenkins to activate plugins..."
    java -jar /tmp/jenkins-cli.jar -s $JENKINS_URL -auth $JENKINS_USER:$JENKINS_PASS safe-restart
    
    # Wait for Jenkins to come back up
    sleep 30
    wait_for_jenkins
}

# Function to create GitHub credentials in Jenkins
create_github_credentials() {
    log "Creating GitHub credentials in Jenkins..."
    
    # Create credentials XML
    cat > /tmp/github-credentials.xml << EOF
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>github-token</id>
  <description>GitHub Personal Access Token for Repository Access</description>
  <username>$(echo $GITHUB_REPO | cut -d'/' -f1)</username>
  <password>$GITHUB_TOKEN</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF

    # Create credentials using Jenkins CLI
    java -jar /tmp/jenkins-cli.jar -s $JENKINS_URL -auth $JENKINS_USER:$JENKINS_PASS create-credentials-by-xml system::system::jenkins _ < /tmp/github-credentials.xml
    
    success "✅ GitHub credentials created in Jenkins"
    rm -f /tmp/github-credentials.xml
}

# Function to update Jenkins job configuration
update_job_configuration() {
    log "Updating Jenkins job configuration to use GitHub..."
    
    # Get current job configuration
    curl -s -u $JENKINS_USER:$JENKINS_PASS $JENKINS_URL/job/$JOB_NAME/config.xml > /tmp/current-job-config.xml
    
    # Create new job configuration with GitHub SCM
    cat > /tmp/updated-job-config.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>GitHub-Integrated CI/CD Pipeline for Group6 React Application</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <jenkins.model.BuildDiscarderProperty>
      <strategy class="hudson.tasks.LogRotator">
        <daysToKeep>30</daysToKeep>
        <numToKeep>10</numToKeep>
        <artifactDaysToKeep>-1</artifactDaysToKeep>
        <artifactNumToKeep>-1</artifactNumToKeep>
      </strategy>
    </jenkins.model.BuildDiscarderProperty>
    <com.coravy.hudson.plugins.github.GithubProjectProperty plugin="github">
      <projectUrl>https://github.com/$GITHUB_REPO</projectUrl>
      <displayName></displayName>
    </com.coravy.hudson.plugins.github.GithubProjectProperty>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <com.cloudbees.jenkins.GitHubPushTrigger plugin="github">
          <spec></spec>
        </com.cloudbees.jenkins.GitHubPushTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/$GITHUB_REPO.git</url>
          <credentialsId>github-token</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/$GITHUB_BRANCH</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="empty-list"/>
      <extensions/>
    </scm>
    <scriptPath>$JENKINSFILE_PATH</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

    # Update job configuration
    curl -s -X POST -u $JENKINS_USER:$JENKINS_PASS \
        -H "Content-Type: application/xml" \
        --data-binary @/tmp/updated-job-config.xml \
        $JENKINS_URL/job/$JOB_NAME/config.xml
    
    success "✅ Jenkins job updated to use GitHub SCM"
    rm -f /tmp/current-job-config.xml /tmp/updated-job-config.xml
}

# Function to create GitHub webhook
create_github_webhook() {
    log "Creating GitHub webhook..."
    
    # Create webhook payload
    local webhook_payload=$(cat << EOF
{
  "name": "web",
  "active": true,
  "events": ["push", "pull_request"],
  "config": {
    "url": "$WEBHOOK_URL",
    "content_type": "json",
    "insecure_ssl": "0"
  }
}
EOF
)
    
    # Create webhook using GitHub API
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$webhook_payload" \
        "https://api.github.com/repos/$GITHUB_REPO/hooks")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [ "$http_code" -eq 201 ]; then
        success "✅ GitHub webhook created successfully"
        echo "   Webhook URL: $WEBHOOK_URL"
    elif [ "$http_code" -eq 422 ] && echo "$response_body" | grep -q "already exists"; then
        warn "⚠️  GitHub webhook already exists - skipping creation"
    else
        error "❌ Failed to create GitHub webhook (HTTP $http_code)"
        echo "Response: $response_body"
        return 1
    fi
}

# Function to test GitHub connectivity
test_github_connectivity() {
    log "Testing GitHub repository connectivity..."
    
    local response=$(curl -s -w "%{http_code}" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_REPO")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" -eq 200 ]; then
        success "✅ GitHub repository accessible"
        return 0
    else
        error "❌ Cannot access GitHub repository (HTTP $http_code)"
        echo "Please check:"
        echo "  - Repository exists: https://github.com/$GITHUB_REPO"
        echo "  - Token has access to the repository"
        echo "  - Repository is not private (or token has private repo access)"
        return 1
    fi
}

# Function to trigger test build
trigger_test_build() {
    log "Triggering test build from GitHub..."
    
    # Trigger build
    curl -s -X POST -u $JENKINS_USER:$JENKINS_PASS $JENKINS_URL/job/$JOB_NAME/build
    
    success "✅ Test build triggered"
    info "Monitor the build at: http://$PUBLIC_IP:8081/job/$JOB_NAME"
    
    # Wait a moment and check build status
    sleep 10
    
    local build_info=$(curl -s -u $JENKINS_USER:$JENKINS_PASS $JENKINS_URL/job/$JOB_NAME/lastBuild/api/json 2>/dev/null || echo "{}")
    local build_number=$(echo "$build_info" | grep -o '"number":[0-9]*' | cut -d':' -f2)
    
    if [ ! -z "$build_number" ]; then
        info "Build #$build_number started"
        info "Build URL: http://$PUBLIC_IP:8081/job/$JOB_NAME/$build_number"
    fi
}

# Function to display final status
display_final_status() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Integration Complete!                     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    success "🎉 GitHub Integration Setup Complete!"
    echo ""
    info "📋 Summary:"
    info "  ✅ Jenkins connected to GitHub repository"
    info "  ✅ Webhook configured for automatic builds"
    info "  ✅ Pipeline updated to use GitHub SCM"
    info "  ✅ Test build triggered"
    echo ""
    info "🔗 Important URLs:"
    info "  Jenkins Dashboard: http://$PUBLIC_IP:8081"
    info "  Pipeline Job: http://$PUBLIC_IP:8081/job/$JOB_NAME"
    info "  GitHub Repository: https://github.com/$GITHUB_REPO"
    info "  SonarQube: http://$PUBLIC_IP:9000"
    info "  React App: http://$PUBLIC_IP:8080/group6-react-app"
    echo ""
    info "🚀 Next Steps:"
    info "  1. Push code to GitHub to trigger automatic builds"
    info "  2. Monitor builds in Jenkins dashboard"
    info "  3. Check SonarQube for code analysis results"
    echo ""
    warn "💡 Tips:"
    warn "  - Webhook events: push, pull_request"
    warn "  - Builds will trigger on branch: $GITHUB_BRANCH"
    warn "  - Jenkinsfile location: $JENKINSFILE_PATH"
}

# Main execution flow
main() {
    log "Starting GitHub integration setup..."
    
    # Step 1: Basic validation
    wait_for_jenkins || exit 1
    check_job_exists || exit 1
    test_github_connectivity || exit 1
    
    # Step 2: Install required plugins
    install_jenkins_plugins || exit 1
    
    # Step 3: Create GitHub credentials
    create_github_credentials || exit 1
    
    # Step 4: Update job configuration
    update_job_configuration || exit 1
    
    # Step 5: Create GitHub webhook
    create_github_webhook || exit 1
    
    # Step 6: Trigger test build
    trigger_test_build || exit 1
    
    # Step 7: Display final status
    display_final_status
    
    success "🎯 GitHub integration setup completed successfully!"
}

# Handle script interruption
trap 'error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"