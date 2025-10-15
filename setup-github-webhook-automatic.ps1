# GitHub Webhook Auto-Setup Script
# This script automatically configures the GitHub webhook for Jenkins integration

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    [string]$RepoOwner = "IvanCzar009",
    [string]$RepoName = "DevOps-Challange101",
    [string]$JenkinsURL = "http://54.241.211.48:8081/github-webhook/"
)

Write-Host "🔧 GitHub Webhook Auto-Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Webhook configuration
$webhookConfig = @{
    name = "web"
    active = $true
    events = @("push")
    config = @{
        url = $JenkinsURL
        content_type = "json"
        insecure_ssl = "1"
    }
} | ConvertTo-Json -Depth 3

# GitHub API headers
$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
    "User-Agent" = "DevOps-Pipeline-Setup"
}

try {
    Write-Host "📡 Creating webhook for repository: $RepoOwner/$RepoName" -ForegroundColor Yellow
    Write-Host "🎯 Target Jenkins URL: $JenkinsURL" -ForegroundColor Yellow
    
    # GitHub API endpoint
    $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/hooks"
    
    # Create webhook
    $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $webhookConfig -ContentType "application/json"
    
    Write-Host "✅ SUCCESS! Webhook created successfully!" -ForegroundColor Green
    Write-Host "🆔 Webhook ID: $($response.id)" -ForegroundColor Green
    Write-Host "🔗 Webhook URL: $($response.config.url)" -ForegroundColor Green
    Write-Host "📅 Created: $($response.created_at)" -ForegroundColor Green
    
    Write-Host "`n🎉 WEBHOOK INTEGRATION COMPLETE!" -ForegroundColor Magenta
    Write-Host "Now push code to GitHub and Jenkins will trigger automatically!" -ForegroundColor Magenta
    
} catch {
    $errorMessage = $_.Exception.Message
    Write-Host "❌ ERROR: Failed to create webhook" -ForegroundColor Red
    Write-Host "Details: $errorMessage" -ForegroundColor Red
    
    if ($errorMessage -like "*401*") {
        Write-Host "`n💡 SOLUTION: Invalid GitHub token" -ForegroundColor Yellow
        Write-Host "1. Go to: https://github.com/settings/tokens" -ForegroundColor Yellow
        Write-Host "2. Generate a new token with 'repo' scope" -ForegroundColor Yellow
        Write-Host "3. Run: .\setup-github-webhook-automatic.ps1 -GitHubToken 'YOUR_TOKEN'" -ForegroundColor Yellow
    }
    elseif ($errorMessage -like "*422*") {
        Write-Host "`n💡 SOLUTION: Webhook might already exist" -ForegroundColor Yellow
        Write-Host "Check: https://github.com/$RepoOwner/$RepoName/settings/hooks" -ForegroundColor Yellow
    }
}

Write-Host "`n📋 MANUAL ALTERNATIVE:" -ForegroundColor Gray
Write-Host "If this script fails, set up manually at:" -ForegroundColor Gray
Write-Host "https://github.com/$RepoOwner/$RepoName/settings/hooks" -ForegroundColor Gray
Write-Host "Payload URL: $JenkinsURL" -ForegroundColor Gray