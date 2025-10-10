# GitHub Integration Setup Guide

## Overview
This script connects your existing Jenkins pipeline to your GitHub repository and sets up automatic webhooks for CI/CD automation.

## Prerequisites
1. ✅ Terraform deployment completed successfully
2. ✅ Jenkins, SonarQube, and React app are running
3. ✅ GitHub Personal Access Token with required permissions

## Step 1: Create GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select these scopes:
   - ✅ **repo** (Full control of private repositories)
   - ✅ **admin:repo_hook** (Admin access to repository hooks)
4. Copy the token (starts with `ghp_`)

## Step 2: Set Environment Variables

### Windows PowerShell:
```powershell
$env:GITHUB_TOKEN = "your_github_token_here"
$env:GITHUB_REPO = "IvanCzar009/DevOps-Challange101"
$env:GITHUB_BRANCH = "terraform-optimized"
```

### Linux/WSL:
```bash
export GITHUB_TOKEN="your_github_token_here"
export GITHUB_REPO="IvanCzar009/DevOps-Challange101"
export GITHUB_BRANCH="terraform-optimized"
```

## Step 3: Run the Integration Script

```bash
# SSH to your EC2 instance
ssh -i Pair06.pem ec2-user@YOUR_PUBLIC_IP

# Copy the script to your instance
scp -i Pair06.pem setup-github-integration.sh ec2-user@YOUR_PUBLIC_IP:/tmp/

# Run the script
chmod +x /tmp/setup-github-integration.sh
GITHUB_TOKEN="your_token" /tmp/setup-github-integration.sh
```

## What the Script Does

1. 🔌 **Installs Jenkins Plugins**: GitHub, Git, Pipeline plugins
2. 🔑 **Creates GitHub Credentials**: Stores your token securely in Jenkins
3. 🔄 **Updates Pipeline Job**: Changes from local files to GitHub SCM
4. 🪝 **Creates Webhook**: Sets up automatic build triggers
5. 🚀 **Tests Integration**: Triggers a test build from GitHub

## Expected Results

After successful execution:
- ✅ Jenkins pipeline connects to your GitHub repository
- ✅ Pushes to GitHub automatically trigger builds
- ✅ SonarQube receives analysis data from builds
- ✅ Webhook configured for push and pull request events

## Verification Steps

1. **Check Jenkins Job**: http://YOUR_IP:8081/job/group6-react-app-pipeline
2. **Verify GitHub Webhook**: GitHub repo → Settings → Webhooks
3. **Test Auto-Build**: Push a commit to your repository
4. **Check SonarQube**: http://YOUR_IP:9000 (should show analysis data)

## Troubleshooting

### Common Issues:

**❌ "GitHub token is required"**
- Ensure `GITHUB_TOKEN` environment variable is set

**❌ "Cannot access GitHub repository"**
- Check repository exists: https://github.com/IvanCzar009/DevOps-Challange101
- Verify token has access to the repository
- Ensure repository is public or token has private repo access

**❌ "Jenkins job does not exist"**
- Ensure your Terraform deployment completed successfully
- The `automate-jenkins-pipeline.sh` should have created the job

**❌ "Webhook already exists"**
- This is normal - the script will skip webhook creation
- Check GitHub repo → Settings → Webhooks to verify

### Debug Commands:

```bash
# Check Jenkins job exists
curl -u admin:admin123456 http://localhost:8081/job/group6-react-app-pipeline/api/json

# Check GitHub connectivity
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/repos/IvanCzar009/DevOps-Challange101

# Check webhook
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/repos/IvanCzar009/DevOps-Challange101/hooks
```

## Configuration Options

You can customize these variables:

```bash
export GITHUB_REPO="YourUsername/YourRepository"
export GITHUB_BRANCH="main"  # or your preferred branch
export JENKINSFILE_PATH="path/to/your/Jenkinsfile"
```

## Success Indicators

✅ **Script Output**: "🎯 GitHub integration setup completed successfully!"
✅ **Jenkins Dashboard**: Shows GitHub repository in job configuration
✅ **GitHub Webhooks**: Webhook appears in repository settings
✅ **Automatic Builds**: Pushes trigger Jenkins builds
✅ **SonarQube Data**: Analysis results appear after builds

## Next Steps After Integration

1. 🔄 **Test the Pipeline**: Push a commit to trigger automatic build
2. 📊 **Monitor SonarQube**: Check for code analysis results
3. 🚀 **Deploy Changes**: Verify React app updates automatically
4. 🔍 **Check Logs**: Use Kibana dashboard for application monitoring

---

**Need Help?** Check the script output for detailed error messages and follow the troubleshooting steps above.