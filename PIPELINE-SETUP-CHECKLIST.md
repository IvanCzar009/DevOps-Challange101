# Jenkins Pipeline Setup Checklist

## ✅ STEP-BY-STEP CHECKLIST

### Phase 1: Install Pipeline Plugin
- [ ] Open http://54.241.211.48:8081
- [ ] Login with admin / admin123456  
- [ ] Click "Manage Jenkins"
- [ ] Click "Manage Plugins"
- [ ] Click "Available" tab
- [ ] Search for "workflow-aggregator"
- [ ] Check "Pipeline" plugin
- [ ] Click "Install without restart"
- [ ] Wait for installation (2-3 minutes)
- [ ] Restart Jenkins if prompted

### Phase 2: Verify Plugin Installation
- [ ] Go to Jenkins main page
- [ ] Click "New Item"
- [ ] Confirm "Pipeline" option is visible
- [ ] If not visible, restart Jenkins manually

### Phase 3: Create Pipeline Job
- [ ] Click "New Item"
- [ ] Enter name: `group6-react-app-pipeline`
- [ ] Select "Pipeline"
- [ ] Click "OK"

### Phase 4: Configure Pipeline
- [ ] Build Triggers: Check "GitHub hook trigger for GITScm polling"
- [ ] Pipeline Definition: "Pipeline script from SCM"
- [ ] SCM: "Git"  
- [ ] Repository URL: `https://github.com/IvanCzar009/DevOps-Challange101.git`
- [ ] Branch: `*/terraform-optimized`
- [ ] Script Path: `Jenkinsfile-complete-cicd`
- [ ] Click "Save"

### Phase 5: Test Pipeline
- [ ] Click "Build Now"
- [ ] Monitor build progress
- [ ] Check build logs for any issues
- [ ] Verify deployment success

## 🎯 Expected Result
After completing this checklist:
- ✅ Jenkins will have Pipeline capability
- ✅ Your CI/CD pipeline will be active
- ✅ GitHub pushes will trigger builds automatically
- ✅ Complete integration with SonarQube, Tomcat, and ELK

## 🚨 If You Still Don't See Pipeline Option
Try this additional step:
1. Go to "Manage Jenkins" → "Manage Plugins"
2. Click "Installed" tab
3. Look for "Pipeline" or "workflow-aggregator"
4. If not found, the installation didn't work
5. Try installing again or restart Jenkins

## 📞 Status Check
You can verify everything is working by checking:
- Jenkins: http://54.241.211.48:8081/job/group6-react-app-pipeline/
- SonarQube: http://54.241.211.48:9000
- Application: http://54.241.211.48:8080/group6-react-app/