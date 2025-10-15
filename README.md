# 🚀 DevOps Challenge 101 - Complete CI/CD Automation

[![Terraform](https://img.shields.io/badge/Terraform-v1.0+-623CE4?logo=terraform&logoColor=white)](https://terraform.io)
[![AWS](https://img.shields.io/badge/AWS-EC2-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com)
[![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D33833?logo=jenkins&logoColor=white)](https://jenkins.io)
[![SonarQube](https://img.shields.io/badge/SonarQube-Code%20Quality-4E9BCD?logo=sonarqube&logoColor=white)](https://sonarqube.org)
[![ELK Stack](https://img.shields.io/badge/ELK-Stack-005571?logo=elastic&logoColor=white)](https://elastic.co)
[![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)](https://reactjs.org)

> **Complete Infrastructure as Code (IaC) solution for automated deployment of a full DevOps stack with CI/CD pipeline, monitoring, and log analytics.**

## 🌟 Features

### 🏗️ **Infrastructure**
- **One-Command Deployment** with Terraform
- **AWS EC2** with Elastic IP and optimized security groups
- **Auto-scaling** t3.2xlarge instance with 20GB encrypted storage
- **Complete automation** from infrastructure to application deployment

### 🔄 **CI/CD Pipeline**
- **Jenkins** with automated pipeline creation
- **SonarQube** integration for code quality analysis
- **Automated testing** and deployment workflows
- **Git webhook** integration for continuous deployment

### 📊 **Monitoring & Analytics**
- **ELK Stack** (Elasticsearch, Logstash, Kibana) for log analytics
- **Real-time monitoring** of application logs
- **Automated dashboard** creation for Tomcat access logs
- **Traffic analysis** and performance metrics

### 🖥️ **Applications**
- **React 18** application with modern build pipeline
- **Apache Tomcat 10.1.15** with native installation
- **Java 11 Amazon Corretto** runtime
- **Hot redeployment** capabilities

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS EC2 (t3.2xlarge)                   │
├─────────────────────────────────────────────────────────────┤
│  📱 React App (8080)     🔧 Jenkins (8081)                │
│  📊 SonarQube (9000)     🔍 Kibana (8090)                 │
│  🔎 Elasticsearch (9200) 📈 Logstash (9600)               │
│  🖥️  Tomcat Native       📋 Filebeat (Log Shipping)       │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform v1.0+ installed
- SSH key pair (`Pair06.pem`) in the project directory

### One-Command Deployment
```bash
# Clone the repository
git clone https://github.com/IvanCzar009/DevOps-Challange101.git
cd DevOps-Challange101

# Deploy complete stack
terraform init
terraform apply -auto-approve
```

### Access Your Services
After deployment (5-10 minutes), access your services:

| Service | URL | Credentials |
|---------|-----|-------------|
| 🖥️ **React App** | `http://<ELASTIC_IP>:8080/group6-react-app/` | Public |
| 🔧 **Jenkins** | `http://<ELASTIC_IP>:8081` | admin / admin123456 |
| 📊 **SonarQube** | `http://<ELASTIC_IP>:9000` | admin / auto-generated |
| 🔍 **Kibana** | `http://<ELASTIC_IP>:8090` | No auth required |
| 🔎 **Elasticsearch** | `http://<ELASTIC_IP>:9200` | No auth required |

## 📋 Project Structure

```
DevOps-Challange101/
├── 🏗️ Infrastructure
│   ├── main.tf                          # Main Terraform configuration
│   ├── sequential-install-jenkins.sh    # Main installation orchestrator
│   └── install-elk.sh                   # ELK Stack installer
├── 🔧 CI/CD Automation
│   ├── install-jenkins.sh               # Jenkins setup & configuration
│   ├── automate-jenkins-pipeline.sh     # Pipeline automation
│   ├── install-sonarqube.sh            # SonarQube installation
│   └── automate-sonarqube-project.sh   # Project automation
├── 🖥️ Application Deployment
│   ├── install-tomcat.sh               # Tomcat native installation
│   ├── install-react-app.sh            # React app setup
│   ├── deploy-react-app.sh             # Enhanced deployment script
│   └── group6-react-app/               # React application source
├── 📊 Monitoring & Analytics
│   ├── automate-kibana-dashboard.sh    # Dashboard automation
│   └── setup-kibana-dashboard.sh       # Manual dashboard setup
└── 🔧 Utilities
    ├── monitor-jenkins-build.sh        # Build monitoring
    └── configure-sonarqube.sh          # SonarQube configuration
```

## 🛠️ Key Automation Scripts

### 🔄 Jenkins Pipeline Automation
Automatically creates a complete CI/CD pipeline with:
- Source code checkout
- Node.js build process
- SonarQube code quality analysis
- Automated deployment to Tomcat
- Health checks and notifications

### 📊 Kibana Dashboard Automation
Creates real-time dashboards showing:
- Request volume over time
- HTTP response code distribution
- Top accessed pages
- Error rate monitoring

### 🔧 SonarQube Project Setup
Automatically configures:
- Quality gates and profiles
- Project-specific rules
- Integration with Jenkins pipeline
- Automated reporting

## 📈 Monitoring & Observability

### ELK Stack Features
- **Real-time log ingestion** from Tomcat access logs
- **Automated index patterns** and dashboard creation
- **Traffic analysis** with geographic and temporal insights
- **Error tracking** and alerting capabilities

### Application Monitoring
- **Health checks** for all services
- **Performance metrics** collection
- **Automated service restart** on failures
- **Log aggregation** across all components

## 🔒 Security Features

- **Encrypted EBS volumes** for data protection
- **Security groups** with minimal required access
- **Automated credential management**
- **Service isolation** and network segmentation

## 🚀 Advanced Features

### Hot Redeployment
```bash
# Automated redeployment script
./deploy-react-app.sh
```

### Service Management
```bash
# Check all service status
./check-app-status.sh

# Monitor Jenkins builds
./monitor-jenkins-build.sh
```

### Log Analysis
- **Filebeat** for log shipping
- **Logstash** for log processing
- **Kibana** for visualization
- **Automated traffic generation** for testing

## 🔧 Customization

### Environment Variables
Edit `main.tf` to customize:
```hcl
variable "instance_name" {
  default = "your-custom-name"
}

variable "jenkins_password" {
  default = "your-secure-password"
}
```

### Application Configuration
Modify `group6-react-app/` for your React application:
- Update `package.json` dependencies
- Modify `Jenkinsfile` for custom pipeline steps
- Adjust `deploy-react-app.sh` for deployment requirements

## 📚 Documentation

### Service Access
- **Jenkins Pipeline**: Auto-created at `/job/group6-react-app-pipeline`
- **SonarQube Project**: Auto-configured as `Group6-React-App`
- **Kibana Dashboards**: Auto-generated for Tomcat logs
- **Elasticsearch Indices**: `tomcat-logs-*` pattern

### Troubleshooting
```bash
# Check service status
terraform output

# Access server for debugging
ssh -i Pair06.pem ec2-user@<ELASTIC_IP>

# View service logs
docker logs elasticsearch
docker logs kibana
tail -f /home/ec2-user/apache-tomcat-*/logs/catalina.out
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Terraform** for Infrastructure as Code
- **Jenkins** for CI/CD automation
- **Elastic Stack** for monitoring and analytics
- **Apache Tomcat** for application hosting
- **React** for modern frontend development

## 📞 Support

For questions and support:
- 📧 **Email**: [Your Email]
- 🐛 **Issues**: [GitHub Issues](https://github.com/IvanCzar009/DevOps-Challange101/issues)
- 📖 **Documentation**: Check the `/docs` directory

---

⭐ **Star this repository** if you find it helpful!

🔗 **Repository**: https://github.com/IvanCzar009/DevOps-Challange101

Built with ❤️ for the DevOps community#   A u t o m a t i c   W e b h o o k   T e s t   -   1 0 / 1 5 / 2 0 2 5   1 5 : 0 3 : 0 8  
 