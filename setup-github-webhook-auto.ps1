# Automatic GitHub Webhook Setup Script
# This script will set up the webhook automatically using GitHub API

Write-Host "===========================================" -ForegroundColor Green
Write-Host "🔗 AUTOMATIC GITHUB WEBHOOK SETUP" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host "⏰ Timestamp: $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

# Configuration
$repoOwner = "IvanCzar009"
$repoName = "DevOps-Challange101"
$jenkinsUrl = "http://54.241.211.48:8081"
$webhookUrl = "$jenkinsUrl/github-webhook/"
$githubApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/hooks"

Write-Host "📋 Configuration:" -ForegroundColor Cyan
Write-Host "   Repository: $repoOwner/$repoName" -ForegroundColor White
Write-Host "   Jenkins URL: $jenkinsUrl" -ForegroundColor White
Write-Host "   Webhook URL: $webhookUrl" -ForegroundColor White
Write-Host ""

# Try to set up webhook without authentication first (public repo)
$webhookPayload = @{
    name = "web"
    active = $true
    events = @("push")
    config = @{
        url = $webhookUrl
        content_type = "json"
        insecure_ssl = "1"
    }
} | ConvertTo-Json -Depth 3

Write-Host "🔍 Attempting automatic webhook setup..." -ForegroundColor Yellow

try {
    # Check existing webhooks first
    Write-Host "Checking existing webhooks..." -ForegroundColor Gray
    $existingHooks = Invoke-RestMethod -Uri $githubApiUrl -Method GET -ErrorAction Stop
    
    # Check if webhook already exists
    $existingWebhook = $existingHooks | Where-Object { $_.config.url -eq $webhookUrl }
    
    if ($existingWebhook) {
        Write-Host "✅ Webhook already exists!" -ForegroundColor Green
        Write-Host "   Webhook ID: $($existingWebhook.id)" -ForegroundColor White
        Write-Host "   URL: $($existingWebhook.config.url)" -ForegroundColor White
        Write-Host "   Active: $($existingWebhook.active)" -ForegroundColor White
    } else {
        Write-Host "🔧 Creating new webhook..." -ForegroundColor Yellow
        
        # Create new webhook
        $newWebhook = Invoke-RestMethod -Uri $githubApiUrl -Method POST -Body $webhookPayload -ContentType "application/json" -ErrorAction Stop
        
        Write-Host "✅ Webhook created successfully!" -ForegroundColor Green
        Write-Host "   Webhook ID: $($newWebhook.id)" -ForegroundColor White
        Write-Host "   URL: $($newWebhook.config.url)" -ForegroundColor White
        Write-Host "   Events: $($newWebhook.events -join ', ')" -ForegroundColor White
    }
}
catch {
    Write-Host "⚠️ Automatic setup failed. This might require authentication." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "=== MANUAL SETUP INSTRUCTIONS ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please follow these steps manually:" -ForegroundColor White
    Write-Host "1. 🌐 Go to: https://github.com/$repoOwner/$repoName/settings/hooks" -ForegroundColor Cyan
    Write-Host "2. 🔘 Click 'Add webhook'" -ForegroundColor Cyan
    Write-Host "3. 📝 Fill in the form:" -ForegroundColor Cyan
    Write-Host "   - Payload URL: $webhookUrl" -ForegroundColor White
    Write-Host "   - Content type: application/json" -ForegroundColor White
    Write-Host "   - Secret: (leave empty)" -ForegroundColor White
    Write-Host "   - SSL verification: Disable (for testing)" -ForegroundColor White
    Write-Host "   - Events: Just the push event" -ForegroundColor White
    Write-Host "   - Active: ✅ Checked" -ForegroundColor White
    Write-Host "4. 💾 Click 'Add webhook'" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "=== TESTING THE WEBHOOK ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "After setting up the webhook, test it with:" -ForegroundColor White
Write-Host "1. Make a small change to any file in the repository" -ForegroundColor Cyan
Write-Host "2. Commit and push to the 'terraform-optimized' branch" -ForegroundColor Cyan
Write-Host "3. Check Jenkins at: $jenkinsUrl/job/group6-react-app-pipeline/" -ForegroundColor Cyan
Write-Host "4. The build should trigger automatically within 1-2 minutes" -ForegroundColor Cyan
Write-Host ""

Write-Host "🎯 Testing Jenkins connectivity..." -ForegroundColor Yellow
try {
    $jenkinsResponse = Invoke-WebRequest -Uri "$jenkinsUrl/job/group6-react-app-pipeline/" -UseBasicParsing -TimeoutSec 10
    if ($jenkinsResponse.StatusCode -eq 200) {
        Write-Host "✅ Jenkins is accessible and job exists!" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Could not connect to Jenkins. Please verify the service is running." -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Webhook setup process completed!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green