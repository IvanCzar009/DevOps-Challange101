# Complete CI/CD Pipeline Setup with GitHub Integration
# This script configures GitHub webhook integration with Jenkins

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo,
    
    [string]$JenkinsUrl = "http://54.241.211.48:8081",
    [string]$JenkinsUser = "admin",
    [string]$JenkinsPassword = "admin123456"
)

Write-Host "🚀 Setting up Complete CI/CD Pipeline Integration" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Yellow

# Step 1: Configure GitHub Webhook
Write-Host "📡 Step 1: Configuring GitHub Webhook..." -ForegroundColor Cyan

$webhookUrl = "$JenkinsUrl/github-webhook/"
$webhookPayload = @{
    name = "web"
    active = $true
    events = @("push", "pull_request")
    config = @{
        url = $webhookUrl
        content_type = "json"
        insecure_ssl = "1"
    }
} | ConvertTo-Json -Depth 3

$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
    "Content-Type" = "application/json"
}

try {
    $webhookResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/hooks" -Method POST -Body $webhookPayload -Headers $headers
    Write-Host "✅ GitHub webhook configured successfully!" -ForegroundColor Green
    Write-Host "   Webhook ID: $($webhookResponse.id)" -ForegroundColor Gray
} catch {
    if ($_.Exception.Response.StatusCode -eq 422) {
        Write-Host "⚠️ Webhook already exists, updating..." -ForegroundColor Yellow
        # Get existing webhooks and update
        $existingHooks = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/hooks" -Headers $headers
        $existingWebhook = $existingHooks | Where-Object { $_.config.url -eq $webhookUrl }
        if ($existingWebhook) {
            $updateResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$GitHubRepo/hooks/$($existingWebhook.id)" -Method PATCH -Body $webhookPayload -Headers $headers
            Write-Host "✅ Webhook updated successfully!" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Failed to configure webhook: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Step 2: Configure Jenkins GitHub Integration
Write-Host "🔧 Step 2: Configuring Jenkins GitHub Integration..." -ForegroundColor Cyan

# Jenkins API configuration
$jenkinsAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${JenkinsUser}:${JenkinsPassword}"))
$jenkinsHeaders = @{
    "Authorization" = "Basic $jenkinsAuth"
    "Content-Type" = "application/xml"
}

# Create GitHub credentials in Jenkins
$credentialsXml = @"
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
    <scope>GLOBAL</scope>
    <id>github-token</id>
    <description>GitHub Personal Access Token</description>
    <username>github-user</username>
    <password>$GitHubToken</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
"@

try {
    Invoke-RestMethod -Uri "$JenkinsUrl/credentials/store/system/domain/_/createCredentials" -Method POST -Body $credentialsXml -Headers $jenkinsHeaders
    Write-Host "✅ GitHub credentials added to Jenkins!" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Credentials may already exist in Jenkins" -ForegroundColor Yellow
}

# Step 3: Configure Global Tools in Jenkins
Write-Host "🛠️ Step 3: Configuring Jenkins Global Tools..." -ForegroundColor Cyan

$globalToolsConfig = @"
<?xml version='1.1' encoding='UTF-8'?>
<hudson.tools.ToolLocationNodeProperty>
    <locations>
        <hudson.tools.ToolLocation>
            <type>hudson.plugins.sonar.SonarRunnerInstallation</type>
            <name>SonarQube Scanner</name>
            <home>/var/jenkins_home/tools/sonar-scanner</home>
        </hudson.tools.ToolLocation>
    </locations>
</hudson.tools.ToolLocationNodeProperty>
"@

Write-Host "🎯 Step 4: Pipeline Configuration Summary" -ForegroundColor Cyan
Write-Host "GitHub Repository: $GitHubRepo" -ForegroundColor Gray
Write-Host "Jenkins URL: $JenkinsUrl" -ForegroundColor Gray
Write-Host "Webhook URL: $webhookUrl" -ForegroundColor Gray
Write-Host "SonarQube URL: http://54.241.211.48:9000" -ForegroundColor Gray
Write-Host "Tomcat URL: http://54.241.211.48:8080" -ForegroundColor Gray

Write-Host "✅ GitHub CI/CD Integration Setup Complete!" -ForegroundColor Green
Write-Host "Next: Create Jenkinsfile and configure pipeline stages" -ForegroundColor Yellow