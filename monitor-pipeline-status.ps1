# DevOps Pipeline Monitoring Guide
Write-Host "=== DEVOPS PIPELINE MONITORING GUIDE ===" -ForegroundColor Magenta

Write-Host ""
Write-Host "🎯 HOW TO KNOW IF YOUR PIPELINE IS WORKING:" -ForegroundColor Green
Write-Host ""

Write-Host "📊 METHOD 1: JENKINS WEB DASHBOARD" -ForegroundColor Cyan
Write-Host "   🌐 Go to: http://54.67.22.49:8081/" -ForegroundColor White
Write-Host "   ✅ Green ball = Success" -ForegroundColor Green
Write-Host "   🔴 Red ball = Failure" -ForegroundColor Red
Write-Host "   🟡 Yellow ball = Unstable" -ForegroundColor Yellow
Write-Host "   🔵 Blue ball = Running" -ForegroundColor Blue
Write-Host ""

Write-Host "📊 METHOD 2: BUILD HISTORY" -ForegroundColor Cyan
Write-Host "   🌐 Go to: http://54.67.22.49:8081/job/group6-auto-pipeline/buildHistory" -ForegroundColor White
Write-Host "   📈 Shows all builds with timestamps" -ForegroundColor White
Write-Host "   🔍 Click any build number to see details" -ForegroundColor White
Write-Host ""

Write-Host "📊 METHOD 3: CONSOLE OUTPUT" -ForegroundColor Cyan
Write-Host "   🌐 Go to: http://54.67.22.49:8081/job/group6-auto-pipeline/lastBuild/console" -ForegroundColor White
Write-Host "   📝 Shows real-time build output" -ForegroundColor White
Write-Host "   🐛 Shows errors and debug information" -ForegroundColor White
Write-Host ""

Write-Host "📊 METHOD 4: POWERSHELL API CHECK" -ForegroundColor Cyan
Write-Host "   💻 Run this command:" -ForegroundColor White
Write-Host '   $status = Invoke-RestMethod -Uri "http://54.67.22.49:8081/job/group6-auto-pipeline/api/json"' -ForegroundColor Green
Write-Host '   Write-Host "Status: $($status.color) | Last Build: #$($status.lastBuild.number)"' -ForegroundColor Green
Write-Host ""

Write-Host "📊 METHOD 5: AUTOMATED MONITORING SCRIPT" -ForegroundColor Cyan
Write-Host "   🤖 I'll create a monitoring script for you!" -ForegroundColor White
Write-Host ""

# Current Status Check
Write-Host "🔍 CURRENT PIPELINE STATUS CHECK:" -ForegroundColor Yellow
Write-Host ""

try {
    $jobStatus = Invoke-RestMethod -Uri "http://54.67.22.49:8081/job/group6-auto-pipeline/api/json" -Method Get
    
    Write-Host "📋 Pipeline Information:" -ForegroundColor Cyan
    Write-Host "   Job Name: $($jobStatus.name)" -ForegroundColor White
    Write-Host "   Last Build: #$($jobStatus.lastBuild.number)" -ForegroundColor White
    Write-Host "   Build Status: $($jobStatus.color)" -ForegroundColor White
    Write-Host "   Buildable: $($jobStatus.buildable)" -ForegroundColor White
    Write-Host ""
    
    # Determine status color
    switch ($jobStatus.color) {
        "blue" { 
            Write-Host "✅ STATUS: SUCCESS - Pipeline is working!" -ForegroundColor Green 
        }
        "red" { 
            Write-Host "❌ STATUS: FAILURE - Pipeline needs attention!" -ForegroundColor Red 
            Write-Host "🔧 Checking what's wrong..." -ForegroundColor Yellow
        }
        "yellow" { 
            Write-Host "⚠️ STATUS: UNSTABLE - Pipeline has warnings!" -ForegroundColor Yellow 
        }
        "blue_anime" { 
            Write-Host "🔵 STATUS: RUNNING - Pipeline is currently building!" -ForegroundColor Blue 
        }
        default { 
            Write-Host "❓ STATUS: UNKNOWN - Check Jenkins dashboard" -ForegroundColor Magenta 
        }
    }
    
    Write-Host ""
    
    # Check recent builds
    Write-Host "📈 RECENT BUILD HISTORY:" -ForegroundColor Cyan
    $buildHistory = Invoke-RestMethod -Uri "http://54.67.22.49:8081/job/group6-auto-pipeline/api/json?tree=builds[number,result]" -Method Get
    $buildHistory.builds | Select-Object -First 5 | ForEach-Object {
        $status = switch ($_.result) {
            "SUCCESS" { "✅" }
            "FAILURE" { "❌" }
            "UNSTABLE" { "⚠️" }
            $null { "🔵" }
            default { "❓" }
        }
        Write-Host "   Build #$($_.number): $status $($_.result)" -ForegroundColor White
    }
    
} catch {
    Write-Host "❌ ERROR: Cannot connect to Jenkins!" -ForegroundColor Red
    Write-Host "🔧 Check if Jenkins is running: http://54.67.22.49:8081/" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 KEY INDICATORS OF WORKING PIPELINE:" -ForegroundColor Green
Write-Host ""
Write-Host "✅ WORKING SIGNS:" -ForegroundColor Green
Write-Host "   • Green/Blue status in Jenkins" -ForegroundColor White
Write-Host "   • Build numbers incrementing" -ForegroundColor White
Write-Host "   • Console shows 'SUCCESS' messages" -ForegroundColor White
Write-Host "   • New builds trigger on Git push" -ForegroundColor White
Write-Host "   • Application deployed successfully" -ForegroundColor White
Write-Host ""
Write-Host "❌ PROBLEM SIGNS:" -ForegroundColor Red
Write-Host "   • Red status in Jenkins" -ForegroundColor White
Write-Host "   • Console shows error messages" -ForegroundColor White
Write-Host "   • Build stuck on same number" -ForegroundColor White
Write-Host "   • No builds after Git push" -ForegroundColor White
Write-Host "   • 'sudo: command not found' errors" -ForegroundColor White
Write-Host ""

Write-Host "🔧 TROUBLESHOOTING STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 📱 Check Jenkins Dashboard:" -ForegroundColor Cyan
Write-Host "   http://54.67.22.49:8081/" -ForegroundColor Green
Write-Host ""
Write-Host "2. 📝 Check Console Output:" -ForegroundColor Cyan
Write-Host "   http://54.67.22.49:8081/job/group6-auto-pipeline/lastBuild/console" -ForegroundColor Green
Write-Host ""
Write-Host "3. 📊 Check Build History:" -ForegroundColor Cyan
Write-Host "   http://54.67.22.49:8081/job/group6-auto-pipeline/buildHistory" -ForegroundColor Green
Write-Host ""
Write-Host "4. 🔄 Manual Trigger Test:" -ForegroundColor Cyan
Write-Host "   Click 'Build Now' in Jenkins dashboard" -ForegroundColor Green
Write-Host ""
Write-Host "5. 📝 GitHub Push Test:" -ForegroundColor Cyan
Write-Host "   Make any small change and push to trigger pipeline" -ForegroundColor Green
Write-Host ""

Write-Host "🚀 QUICK MONITORING COMMANDS:" -ForegroundColor Magenta
Write-Host ""
Write-Host "# Check pipeline status" -ForegroundColor Green
Write-Host '$status = Invoke-RestMethod -Uri "http://54.67.22.49:8081/job/group6-auto-pipeline/api/json"' -ForegroundColor Cyan
Write-Host 'Write-Host "Status: $($status.color)"' -ForegroundColor Cyan
Write-Host ""
Write-Host "# Check last build result" -ForegroundColor Green  
Write-Host '$lastBuild = Invoke-RestMethod -Uri "http://54.67.22.49:8081/job/group6-auto-pipeline/lastBuild/api/json"' -ForegroundColor Cyan
Write-Host 'Write-Host "Build #$($lastBuild.number): $($lastBuild.result)"' -ForegroundColor Cyan
Write-Host ""
Write-Host "# Get console output" -ForegroundColor Green
Write-Host '$console = Invoke-RestMethod -Uri "http://54.67.22.49:8081/job/group6-auto-pipeline/lastBuild/consoleText"' -ForegroundColor Cyan
Write-Host '$console.Split("`n") | Select-Object -Last 10' -ForegroundColor Cyan

Write-Host ""
Write-Host "💡 CURRENT ISSUE DETECTED:" -ForegroundColor Red
Write-Host "   The pipeline is failing due to 'sudo: command not found'" -ForegroundColor Yellow
Write-Host "   This means the job config needs to be updated with the new DevOps pipeline" -ForegroundColor Yellow
Write-Host ""
Write-Host "🔧 SOLUTION:" -ForegroundColor Green
Write-Host "   Let me fix the pipeline configuration now!" -ForegroundColor Green