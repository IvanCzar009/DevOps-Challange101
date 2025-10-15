# Jenkins Pipeline Setup Instructions
# Follow these steps to create and trigger your CI/CD pipeline

Write-Host "🚀 Jenkins CI/CD Pipeline Setup Guide" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Yellow

Write-Host "📋 Step-by-Step Instructions:" -ForegroundColor Cyan

Write-Host "
1. 🌐 Open Jenkins Dashboard:
   URL: http://54.241.211.48:8081
   Username: admin
   Password: admin123456

2. 🔧 Create New Pipeline Job:
   - Click 'New Item'
   - Enter name: 'group6-react-app-pipeline'
   - Select 'Pipeline'
   - Click 'OK'

3. ⚙️ Configure Pipeline:
   - Scroll to 'Pipeline' section
   - Definition: 'Pipeline script from SCM'
   - SCM: 'Git'
   - Repository URL: 'https://github.com/IvanCzar009/DevOps-Challange101.git'
   - Branch: 'terraform-optimized'
   - Script Path: 'Jenkinsfile-complete-cicd'

4. 🔗 Enable GitHub Webhook:
   - Check 'GitHub hook trigger for GITScm polling'
   - Save the configuration

5. 🏃‍♂️ Trigger Methods:

   METHOD 1 - Manual Trigger (Immediate):
   - Click 'Build Now' in Jenkins UI
   
   METHOD 2 - Git Push Trigger (Automatic):
   - Make any code change
   - git add .
   - git commit -m 'Trigger pipeline'
   - git push origin terraform-optimized
   
   METHOD 3 - Webhook Test:
   - Go to GitHub repository settings
   - Webhooks → Add webhook
   - URL: http://54.241.211.48:8081/github-webhook/
   - Content type: application/json
   - Events: Push and Pull requests

6. 📊 Monitor Pipeline:
   - Jenkins: http://54.241.211.48:8081/job/group6-react-app-pipeline/
   - SonarQube: http://54.241.211.48:9000/dashboard?id=group6-react-app
   - Kibana: http://54.241.211.48:8443
   - App: http://54.241.211.48:8080/group6-react-app/

" -ForegroundColor White

Write-Host "🎯 Quick Test - Trigger Pipeline Now:" -ForegroundColor Green
Write-Host "1. Open Jenkins: http://54.241.211.48:8081" -ForegroundColor Yellow
Write-Host "2. Login with admin/admin123456" -ForegroundColor Yellow
Write-Host "3. Create pipeline job with Jenkinsfile-complete-cicd" -ForegroundColor Yellow
Write-Host "4. Click 'Build Now' to start!" -ForegroundColor Yellow

Write-Host "
🔍 Pipeline Stages (Total ~15-20 minutes):
   1. 🚀 Pipeline Initialization (30s)
   2. 📥 Source Code Checkout (1-2min)
   3. 🔍 Environment Setup (3-5min)
   4. 🧪 Code Quality & Testing (5-10min)
   5. 📊 Quality Gate (2-3min)
   6. 🏗️ Build Application (2-4min)
   7. 🚀 Deploy to Tomcat (3-5min)
   8. 🔍 Post-Deployment Testing (2-3min)
" -ForegroundColor Cyan

Write-Host "✅ Pipeline files are ready in your repository!" -ForegroundColor Green
Write-Host "✅ All services are running and configured!" -ForegroundColor Green
Write-Host "✅ Just create the Jenkins job and trigger!" -ForegroundColor Green