#!/bin/bash

# Automated Jenkins Job Creation Script
# This script creates the CI/CD pipeline job in Jenkins via API

set -euo pipefail

# Configuration
JENKINS_URL="http://54.241.211.48:8081"
JENKINS_USER="admin"
JENKINS_PASS="admin123456"
JOB_NAME="group6-react-app-pipeline"
GITHUB_REPO="https://github.com/IvanCzar009/DevOps-Challange101.git"
BRANCH="terraform-optimized"
JENKINSFILE_PATH="Jenkinsfile-complete-cicd"

echo "🚀 Creating Jenkins Pipeline Job Automatically..."
echo "=============================================="

# Function to get Jenkins crumb for CSRF protection
get_jenkins_crumb() {
    local crumb=$(curl -s -u "${JENKINS_USER}:${JENKINS_PASS}" \
        "${JENKINS_URL}/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)")
    echo "$crumb"
}

# Function to check if Jenkins is accessible
check_jenkins() {
    echo "🔍 Checking Jenkins accessibility..."
    if curl -s -f -u "${JENKINS_USER}:${JENKINS_PASS}" "${JENKINS_URL}/api/json" >/dev/null; then
        echo "✅ Jenkins is accessible"
        return 0
    else
        echo "❌ Jenkins is not accessible"
        return 1
    fi
}

# Function to create pipeline job
create_pipeline_job() {
    echo "📋 Creating pipeline job: ${JOB_NAME}"
    
    # Get CSRF crumb
    local crumb=$(get_jenkins_crumb)
    echo "🔑 CSRF Crumb: ${crumb}"
    
    # Create job configuration XML
    local job_config=$(cat << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <actions/>
  <description>Complete CI/CD Pipeline for Group6 React App - GitHub → Jenkins → SonarQube → Tomcat → ELK</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <com.cloudbees.jenkins.GitHubPushTrigger plugin="github@1.34.1">
          <spec></spec>
        </com.cloudbees.jenkins.GitHubPushTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.90">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.8.3">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${GITHUB_REPO}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/${BRANCH}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>${JENKINSFILE_PATH}</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
)

    # Create the job
    local response=$(curl -s -w "%{http_code}" -u "${JENKINS_USER}:${JENKINS_PASS}" \
        -H "${crumb}" \
        -H "Content-Type: application/xml" \
        -X POST \
        --data-raw "${job_config}" \
        "${JENKINS_URL}/createItem?name=${JOB_NAME}")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        echo "✅ Pipeline job created successfully!"
        return 0
    elif [ "$http_code" = "400" ]; then
        echo "⚠️ Job already exists, updating configuration..."
        # Update existing job
        curl -s -u "${JENKINS_USER}:${JENKINS_PASS}" \
            -H "${crumb}" \
            -H "Content-Type: application/xml" \
            -X POST \
            --data-raw "${job_config}" \
            "${JENKINS_URL}/job/${JOB_NAME}/config.xml"
        echo "✅ Job configuration updated!"
        return 0
    else
        echo "❌ Failed to create job. HTTP Code: ${http_code}"
        echo "Response: ${response}"
        return 1
    fi
}

# Function to trigger the first build
trigger_build() {
    echo "🚀 Triggering first pipeline build..."
    local crumb=$(get_jenkins_crumb)
    
    local response=$(curl -s -w "%{http_code}" -u "${JENKINS_USER}:${JENKINS_PASS}" \
        -H "${crumb}" \
        -X POST \
        "${JENKINS_URL}/job/${JOB_NAME}/build")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "201" ]; then
        echo "✅ Build triggered successfully!"
        echo "📊 Monitor progress at: ${JENKINS_URL}/job/${JOB_NAME}/"
    else
        echo "⚠️ Build trigger response: ${http_code}"
    fi
}

# Function to install required plugins
install_plugins() {
    echo "🔌 Installing required Jenkins plugins..."
    local crumb=$(get_jenkins_crumb)
    
    local plugins=(
        "workflow-aggregator"
        "git"
        "github"
        "sonar"
        "nodejs"
        "build-timeout"
        "credentials-binding"
        "timestamper"
        "ws-cleanup"
        "pipeline-stage-view"
    )
    
    for plugin in "${plugins[@]}"; do
        echo "📦 Installing plugin: ${plugin}"
        curl -s -u "${JENKINS_USER}:${JENKINS_PASS}" \
            -H "${crumb}" \
            -X POST \
            "${JENKINS_URL}/pluginManager/installNecessaryPlugins" \
            -d "plugin.${plugin}.default=on" >/dev/null || echo "⚠️ Plugin ${plugin} installation queued"
    done
    
    echo "✅ Plugin installation initiated"
}

# Main execution
main() {
    echo "🎯 Jenkins CI/CD Pipeline Setup Starting..."
    
    if ! check_jenkins; then
        echo "❌ Cannot connect to Jenkins. Please check:"
        echo "   - Jenkins is running: ${JENKINS_URL}"
        echo "   - Credentials are correct: ${JENKINS_USER}/${JENKINS_PASS}"
        exit 1
    fi
    
    # Install plugins (optional, may require restart)
    install_plugins
    
    # Create the pipeline job
    if create_pipeline_job; then
        echo ""
        echo "🎉 SUCCESS! Pipeline job created!"
        echo ""
        echo "📋 Job Details:"
        echo "   Name: ${JOB_NAME}"
        echo "   Repository: ${GITHUB_REPO}"
        echo "   Branch: ${BRANCH}"
        echo "   Jenkinsfile: ${JENKINSFILE_PATH}"
        echo ""
        echo "🔗 Access URLs:"
        echo "   Jenkins Job: ${JENKINS_URL}/job/${JOB_NAME}/"
        echo "   Build Now: ${JENKINS_URL}/job/${JOB_NAME}/build"
        echo "   Console Output: ${JENKINS_URL}/job/${JOB_NAME}/lastBuild/console"
        echo ""
        
        # Trigger first build
        trigger_build
        
        echo ""
        echo "📊 Complete CI/CD Pipeline URLs:"
        echo "   🔧 Jenkins: ${JENKINS_URL}"
        echo "   🔍 SonarQube: http://54.241.211.48:9000"
        echo "   🚀 Tomcat: http://54.241.211.48:8080"
        echo "   📈 Kibana: http://54.241.211.48:8443"
        echo "   🎯 Final App: http://54.241.211.48:8080/group6-react-app/"
        echo ""
        echo "✅ Your CI/CD pipeline is ready to use!"
        
    else
        echo "❌ Failed to create pipeline job"
        exit 1
    fi
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi