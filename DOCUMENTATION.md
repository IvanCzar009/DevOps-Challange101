# 📖 DevOps Challenge 101 - Detailed Documentation

## Table of Contents
- [🎯 Overview](#overview)
- [🏗️ Architecture Details](#architecture-details)
- [⚡ Quick Deployment](#quick-deployment)
- [🔧 Service Configuration](#service-configuration)
- [📊 Monitoring Setup](#monitoring-setup)
- [🛠️ Troubleshooting](#troubleshooting)
- [🔄 CI/CD Pipeline](#cicd-pipeline)
- [📈 Performance Tuning](#performance-tuning)

## 🎯 Overview

This project provides a complete DevOps automation solution that deploys:
- **Infrastructure**: AWS EC2 with Terraform
- **CI/CD**: Jenkins with automated pipeline creation
- **Code Quality**: SonarQube with project automation
- **Monitoring**: ELK Stack with real-time dashboards
- **Application**: React app on native Tomcat

## 🏗️ Architecture Details

### Network Configuration
```
Security Group: ELK-challenge101-sg
Ports:
├── 22    (SSH)
├── 80    (HTTP)
├── 443   (HTTPS)
├── 3000  (React Dev)
├── 5061  (Kibana)
├── 8080  (Tomcat)
├── 8081  (Jenkins)
├── 9000  (SonarQube)
├── 9200  (Elasticsearch)
└── 9600  (Logstash)
```

### Service Dependencies
```
ELK Stack → Jenkins → SonarQube → Tomcat → React App
    ↓           ↓          ↓          ↓         ↓
Monitoring  Pipeline   Quality   Runtime   Application
```

## ⚡ Quick Deployment

### Step 1: Prerequisites
```bash
# Verify AWS CLI
aws sts get-caller-identity

# Verify Terraform
terraform version

# Ensure SSH key exists
ls -la Pair06.pem
```

### Step 2: Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Plan deployment (optional)
terraform plan

# Deploy everything
terraform apply -auto-approve
```

### Step 3: Access Services
```bash
# Get service URLs
terraform output application_urls

# Get credentials
terraform output service_credentials
```

## 🔧 Service Configuration

### Jenkins Configuration
- **Location**: `/var/lib/jenkins`
- **Plugins**: Automatically installed (Git, SonarQube, Pipeline)
- **Pipeline**: Auto-created as `group6-react-app-pipeline`
- **Admin User**: `admin` / `admin123456`

### SonarQube Configuration
- **Database**: PostgreSQL (Docker)
- **Admin Password**: Auto-generated and saved to `/home/ec2-user/sonarqube-config.txt`
- **Project**: Auto-configured as `Group6-React-App`
- **Quality Gate**: Default with custom rules

### Tomcat Configuration
- **Version**: 10.1.15 (Native installation)
- **Java**: Amazon Corretto 11
- **Location**: `/home/ec2-user/apache-tomcat-10.1.15`
- **Manager App**: admin / admin123

### ELK Stack Configuration
- **Elasticsearch**: Single node, 512MB heap
- **Kibana**: Port 5061 (forwarded to 8090)
- **Logstash**: Configured for Tomcat logs
- **Filebeat**: Ships logs to Elasticsearch

## 📊 Monitoring Setup

### Automatic Dashboard Creation
The system automatically creates:
1. **Index Pattern**: `tomcat-logs-*`
2. **Visualizations**:
   - Request count over time (Line chart)
   - HTTP response codes (Pie chart)
   - Total log entries (Metric)
   - Recent activity (Table)
3. **Dashboard**: Complete monitoring view

### Manual Dashboard Setup
```bash
# SSH to server
ssh -i Pair06.pem ec2-user@<ELASTIC_IP>

# Run dashboard automation
./automate-kibana-dashboard.sh
```

### Log Shipping Flow
```
Tomcat Logs → Filebeat → Elasticsearch → Kibana
     ↓
Access & Error Logs
     ↓
Real-time Visualization
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify key pair exists
aws ec2 describe-key-pairs --key-names Pair06

# Check security groups
terraform plan
```

#### 2. Services Not Accessible
```bash
# Check security group rules
aws ec2 describe-security-groups --group-names ELK-challenge101-sg

# Verify instance status
terraform output instance_public_ip
```

#### 3. Jenkins Pipeline Fails
```bash
# SSH to server
ssh -i Pair06.pem ec2-user@<ELASTIC_IP>

# Check Jenkins logs
sudo journalctl -u jenkins -f

# Verify SonarQube connection
curl http://localhost:9000/api/system/status
```

#### 4. Kibana Dashboard Empty
```bash
# Check Elasticsearch indices
curl http://localhost:9200/_cat/indices

# Verify Filebeat status
sudo systemctl status filebeat

# Generate test traffic
for i in {1..50}; do curl http://localhost:8080/group6-react-app/; done
```

### Log Locations
```
Jenkins:     /var/log/jenkins/jenkins.log
SonarQube:   docker logs sonarqube
Tomcat:      /home/ec2-user/apache-tomcat-*/logs/catalina.out
ELK:         docker logs elasticsearch, docker logs kibana
Filebeat:    /opt/filebeat/logs/filebeat
```

## 🔄 CI/CD Pipeline

### Pipeline Stages
1. **Checkout**: Git repository clone
2. **Build**: `npm install && npm run build`
3. **Test**: `npm test` (if tests exist)
4. **SonarQube Analysis**: Code quality scan
5. **Deploy**: Copy build to Tomcat webapps
6. **Health Check**: Verify deployment success

### Pipeline Configuration
Located in `group6-react-app/Jenkinsfile`:
```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') { ... }
        stage('Build') { ... }
        stage('SonarQube Analysis') { ... }
        stage('Deploy') { ... }
        stage('Health Check') { ... }
    }
}
```

### Triggering Builds
- **Manual**: Jenkins dashboard → Build Now
- **Webhook**: Git push triggers (when configured)
- **Scheduled**: Cron expression in Jenkinsfile

## 📈 Performance Tuning

### Instance Optimization
- **Type**: t3.2xlarge (8 vCPU, 32GB RAM)
- **Storage**: 20GB GP3 encrypted
- **Network**: Enhanced networking enabled

### Service Tuning
```bash
# Elasticsearch heap size
export ES_JAVA_OPTS="-Xms512m -Xmx512m"

# Tomcat memory settings
export CATALINA_OPTS="-Xms1G -Xmx2G"

# Jenkins heap size
export JENKINS_JAVA_OPTIONS="-Xms1G -Xmx2G"
```

### Monitoring Performance
```bash
# System resources
htop
df -h
free -h

# Service status
systemctl status jenkins
docker stats
```

## 🔒 Security Considerations

### Network Security
- Minimal ports open in security groups
- SSH key-based authentication only
- No root login enabled

### Application Security
- Services run as non-root users
- Encrypted EBS volumes
- Auto-generated passwords for sensitive services

### Best Practices
1. Rotate credentials regularly
2. Monitor access logs
3. Keep services updated
4. Use HTTPS in production

## 🚀 Scaling Considerations

### Horizontal Scaling
- Use Application Load Balancer
- Multiple EC2 instances
- Shared EFS for Jenkins workspace

### Vertical Scaling
- Increase instance type
- Adjust service heap sizes
- Monitor resource utilization

## 📞 Getting Help

### Quick Commands
```bash
# Get all service URLs
terraform output

# Check service health
curl -I http://<IP>:8080/group6-react-app/
curl -I http://<IP>:8081/
curl -I http://<IP>:9000/

# Access server
ssh -i Pair06.pem ec2-user@<ELASTIC_IP>
```

### Support Resources
- GitHub Issues for bug reports
- Documentation in `/docs` directory
- Terraform output for current configuration

---

For more detailed information, refer to individual script comments and the main README.md file.