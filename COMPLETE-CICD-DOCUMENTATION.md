# Complete CI/CD Pipeline Documentation
## GitHub → Jenkins → SonarQube → Tomcat → ELK Stack Integration

### 🎯 Overview
This document describes a complete CI/CD pipeline that integrates:
- **GitHub**: Source code repository and webhook triggers
- **Jenkins**: Continuous Integration and Deployment orchestration
- **SonarQube**: Code quality analysis and quality gates
- **Tomcat**: Application deployment server
- **ELK Stack**: Pipeline monitoring, logging, and metrics

### 🏗️ Architecture Diagram
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   GitHub    │───▶│   Jenkins   │───▶│  SonarQube  │───▶│   Tomcat    │───▶│ ELK Stack   │
│ Repository  │    │   Pipeline  │    │   Quality   │    │ Application │    │ Monitoring  │
│ + Webhooks  │    │             │    │   Gates     │    │   Server    │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼                   ▼
   Code Push          Build & Test         Code Analysis      Deploy App         Log & Monitor
   Webhook Trigger    Unit Tests          Quality Gates      Health Checks      Performance Metrics
```

### 🚀 Service URLs
- **Jenkins**: http://54.241.211.48:8081
- **SonarQube**: http://54.241.211.48:9000
- **Elasticsearch**: http://54.241.211.48:9200
- **Kibana**: http://54.241.211.48:8443
- **Logstash**: http://54.241.211.48:9600
- **Tomcat**: http://54.241.211.48:8080
- **React App**: http://54.241.211.48:8080/group6-react-app/

### 🔐 Service Credentials
- **Jenkins**: admin / admin123456
- **SonarQube**: admin / admin (or check /home/ec2-user/.sonarqube-credentials)
- **Tomcat Manager**: admin / admin123

## 📋 Pipeline Stages

### 1. 🚀 Pipeline Initialization
- **Purpose**: Set up environment variables and initialize pipeline
- **Actions**:
  - Configure build timestamps
  - Set application name and URLs
  - Send pipeline start event to ELK stack
- **Duration**: ~30 seconds

### 2. 📥 Source Code Checkout
- **Purpose**: Retrieve latest code from GitHub repository
- **Actions**:
  - Clean workspace
  - Checkout specified branch (main/feature)
  - Log git commit information
  - Send checkout status to ELK
- **Triggers**: GitHub webhook on push/pull request
- **Duration**: ~1-2 minutes

### 3. 🔍 Environment Setup & Dependency Installation
- **Purpose**: Prepare build environment
- **Parallel Tasks**:
  - Install Node.js dependencies (`npm ci`)
  - Setup build tools and directories
  - Verify Java and Docker installations
- **Duration**: ~3-5 minutes

### 4. 🧪 Code Quality & Testing
- **Purpose**: Comprehensive code analysis and testing
- **Parallel Tasks**:

  #### 4a. Static Code Analysis (SonarQube)
  - Run SonarQube scanner
  - Analyze code quality, security, maintainability
  - Generate coverage reports
  
  #### 4b. Unit Testing
  - Execute Jest test suite
  - Generate code coverage reports
  - Publish test results and coverage
  
  #### 4c. Security Scanning
  - Run `npm audit` for vulnerability detection
  - Generate security reports
  
- **Duration**: ~5-10 minutes

### 5. 📊 Quality Gate
- **Purpose**: Enforce quality standards before deployment
- **Actions**:
  - Wait for SonarQube quality gate results
  - Fail pipeline if quality gate fails
  - Send quality metrics to ELK
- **Fail Conditions**:
  - Code coverage below threshold
  - Security vulnerabilities found
  - Code smells exceed limit
- **Duration**: ~2-3 minutes

### 6. 🏗️ Build Application
- **Purpose**: Create production-ready application bundle
- **Actions**:
  - Run `npm run build`
  - Create deployment package (tar.gz)
  - Generate build metadata
  - Archive build artifacts
- **Duration**: ~2-4 minutes

### 7. 🚀 Deploy to Tomcat
- **Purpose**: Deploy application to production server
- **Actions**:
  - Stop Tomcat gracefully
  - Backup existing deployment
  - Deploy new application version
  - Start Tomcat and verify deployment
  - Send deployment status to ELK
- **Duration**: ~3-5 minutes

### 8. 🔍 Post-Deployment Testing
- **Purpose**: Verify successful deployment
- **Parallel Tasks**:

  #### 8a. Health Checks
  - Test main application endpoint
  - Verify API endpoints
  - Check static resource loading
  
  #### 8b. Performance Testing
  - Run load tests (10 concurrent requests)
  - Measure average response time
  - Calculate success rate
  
- **Duration**: ~2-3 minutes

## 🔧 Configuration Files

### GitHub Integration
- **File**: `setup-github-cicd.ps1`
- **Purpose**: Configure GitHub webhooks and Jenkins credentials
- **Usage**: 
  ```powershell
  .\setup-github-cicd.ps1 -GitHubToken "your_token" -GitHubRepo "IvanCzar009/DevOps-Challange101"
  ```

### Jenkins Pipeline
- **File**: `Jenkinsfile-complete-cicd`
- **Purpose**: Complete pipeline definition with all stages
- **Features**:
  - Parallel execution for efficiency
  - Error handling and rollback
  - ELK integration for monitoring
  - Email notifications

### SonarQube Configuration
- **File**: `group6-react-app/sonar-project.properties`
- **Purpose**: Code quality analysis settings
- **Key Settings**:
  - Project key and name
  - Source and test directories
  - Coverage report paths
  - Quality gate configuration

### Tomcat Deployment
- **File**: `deploy-to-tomcat.sh`
- **Purpose**: Automated deployment script
- **Features**:
  - Graceful deployment with backup
  - Health checks and smoke tests
  - Performance testing
  - Rollback capability

### ELK Monitoring
- **File**: `logstash-cicd-pipeline.conf`
- **Purpose**: Log processing and metric collection
- **File**: `kibana-cicd-dashboard.json`
- **Purpose**: Pipeline monitoring dashboard

## 📊 Monitoring and Metrics

### Kibana Dashboard Components
1. **Build Success Rate**: Pie chart showing pass/fail ratio
2. **Pipeline Timeline**: Timeline view of all executions
3. **Stage Performance**: Performance breakdown by stage
4. **Quality Trends**: Code quality metrics over time
5. **Deployment Status**: Success/failure tracking
6. **Recent Builds**: Latest pipeline executions table

### Key Metrics Tracked
- **Build Metrics**:
  - Total builds, success rate, failure rate
  - Average build duration per stage
  - Build frequency and trends

- **Quality Metrics**:
  - Code coverage percentage
  - Quality gate pass/fail rates
  - Security vulnerabilities found
  - Code smell trends

- **Deployment Metrics**:
  - Deployment success rate
  - Average deployment time
  - Rollback frequency
  - Application response times

- **Performance Metrics**:
  - Average response time
  - Request success rate
  - Resource utilization
  - Error rates

## 🔄 Workflow Examples

### Standard Development Flow
1. Developer pushes code to feature branch
2. GitHub webhook triggers Jenkins pipeline
3. Pipeline runs all stages automatically
4. If successful, application is deployed to Tomcat
5. Metrics are collected in ELK stack
6. Team is notified of success/failure

### Quality Gate Failure
1. Pipeline reaches quality gate stage
2. SonarQube reports quality issues
3. Pipeline fails and stops deployment
4. Developer receives notification with quality report
5. Developer fixes issues and pushes again
6. Pipeline retries automatically

### Deployment Rollback
1. Deployment completes but health checks fail
2. Automatic rollback is triggered
3. Previous version is restored from backup
4. Team is notified of rollback
5. Investigation begins using ELK logs

## 🛠️ Setup Instructions

### 1. GitHub Configuration
```bash
# Set up webhook
curl -X POST "https://api.github.com/repos/IvanCzar009/DevOps-Challange101/hooks" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -d '{
    "name": "web",
    "active": true,
    "events": ["push", "pull_request"],
    "config": {
      "url": "http://54.241.211.48:8081/github-webhook/",
      "content_type": "json"
    }
  }'
```

### 2. Jenkins Pipeline Setup
1. Create new Pipeline job in Jenkins
2. Configure GitHub repository URL
3. Set pipeline script path to `Jenkinsfile-complete-cicd`
4. Enable GitHub webhook trigger
5. Configure credentials for SonarQube and Tomcat

### 3. SonarQube Integration
1. Create project in SonarQube with key `group6-react-app`
2. Generate project token
3. Configure quality gate with desired thresholds
4. Add SonarQube server to Jenkins global configuration

### 4. ELK Stack Configuration
1. Import Kibana dashboard from `kibana-cicd-dashboard.json`
2. Configure Logstash with `logstash-cicd-pipeline.conf`
3. Create Elasticsearch index template for `cicd-pipeline-*`
4. Set up index lifecycle policies for log retention

## 🚨 Troubleshooting

### Common Issues

#### Pipeline Fails at Quality Gate
- **Cause**: Code quality below threshold
- **Solution**: Check SonarQube report, fix issues, push again
- **Prevention**: Run SonarQube locally before pushing

#### Deployment Timeout
- **Cause**: Tomcat not responding, resource constraints
- **Solution**: Check Tomcat logs, restart if needed
- **Prevention**: Monitor resource usage, increase timeouts

#### ELK Not Receiving Data
- **Cause**: Logstash configuration issues, network problems
- **Solution**: Check Logstash logs, verify Elasticsearch connectivity
- **Prevention**: Set up monitoring alerts for ELK health

#### GitHub Webhook Not Triggering
- **Cause**: Webhook configuration, network connectivity
- **Solution**: Re-configure webhook, check Jenkins logs
- **Prevention**: Test webhook manually, monitor GitHub delivery

### Log Locations
- **Jenkins**: `/var/jenkins_home/logs/`
- **Tomcat**: `/home/ec2-user/apache-tomcat-10.1.15/logs/`
- **Elasticsearch**: Docker container logs
- **Logstash**: Docker container logs

## 📈 Performance Optimization

### Pipeline Optimization
- Use parallel stages where possible
- Cache dependencies (npm cache, Docker layers)
- Optimize test execution time
- Use pipeline libraries for reusable code

### Resource Optimization
- Monitor CPU and memory usage
- Scale infrastructure based on build frequency
- Use build agents for distributed builds
- Implement smart triggering (skip builds for docs-only changes)

## 🔒 Security Best Practices

### Credentials Management
- Use Jenkins credentials store
- Rotate tokens regularly
- Limit credential scope
- Monitor credential usage

### Code Security
- Enable security scanning in pipeline
- Set up dependency vulnerability checks
- Use signed commits
- Implement branch protection rules

### Infrastructure Security
- Use HTTPS for all communications
- Implement network segmentation
- Regular security updates
- Monitor access logs

## 📚 Additional Resources
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [SonarQube Quality Gates](https://docs.sonarqube.org/latest/user-guide/quality-gates/)
- [ELK Stack Monitoring](https://www.elastic.co/guide/en/kibana/current/dashboard.html)
- [Tomcat Deployment Guide](https://tomcat.apache.org/tomcat-10.1-doc/deployer-howto.html)

---

**Last Updated**: October 15, 2025  
**Version**: 1.0  
**Maintained by**: DevOps Team