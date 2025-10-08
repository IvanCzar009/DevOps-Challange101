# 🔌 CI/CD Stack - Complete Port Reference Guide

## 📋 **Port Overview Table**

| Tool | Service | Internal Port | External Port | Protocol | Purpose |
|------|---------|---------------|---------------|----------|---------|
| **GitLab** | Web Interface | 80 | **8081** | HTTP | GitLab Web UI |
| **GitLab** | HTTPS | 443 | **8443** | HTTPS | GitLab HTTPS (if enabled) |
| **GitLab** | SSH | 22 | **8022** | SSH | Git SSH access |
| **GitLab** | PostgreSQL | 5432 | **5432** | TCP | Database (internal) |
| **SonarQube** | Web Interface | 9000 | **9000** | HTTP | SonarQube Dashboard |
| **SonarQube** | PostgreSQL | 5432 | **5433** | TCP | Database (internal) |
| **Tomcat** | Web Server | 8080 | **8080** | HTTP | Tomcat & React App |
| **Elasticsearch** | API | 9200 | **9200** | HTTP | Elasticsearch API |
| **Kibana** | Web Interface | 5601 | **5061** | HTTP | Kibana Dashboard |
| **Logstash** | Beats Input | 5044 | **5044** | TCP | Log input |
| **Logstash** | Monitoring | 9600 | **9600** | HTTP | Logstash metrics |

---

## 🌐 **Public Access URLs**

### **Primary Services (Web Interfaces):**
```
GitLab:        http://YOUR_PUBLIC_IP:8081
SonarQube:     http://YOUR_PUBLIC_IP:9000
Tomcat:        http://YOUR_PUBLIC_IP:8080
React App:     http://YOUR_PUBLIC_IP:8080/group6-react-app/
Kibana:        http://YOUR_PUBLIC_IP:5061
Elasticsearch: http://YOUR_PUBLIC_IP:9200
```

### **Development/API Access:**
```
GitLab SSH:    ssh://git@YOUR_PUBLIC_IP:8022
Logstash:      YOUR_PUBLIC_IP:5044 (for log shipping)
Logstash API:  http://YOUR_PUBLIC_IP:9600
```

---

## 🔧 **Port Details by Tool**

### **1. GitLab (Multi-Service)**
```yaml
Container: gitlab-gitlab-1
Ports:
  - "8081:80"    # Main web interface
  - "8443:443"   # HTTPS (configured but not used)
  - "8022:22"    # Git SSH access

Container: gitlab-postgres-1  
Ports:
  - "5432:5432"  # PostgreSQL database
```

**Access:**
- **Web UI**: http://YOUR_IP:8081
- **Git Clone**: `git clone ssh://git@YOUR_IP:8022/username/repo.git`
- **Credentials**: root / admin123456

---

### **2. ELK Stack (3 Services)**
```yaml
# Elasticsearch
Container: elasticsearch
Ports:
  - "9200:9200"  # REST API

# Kibana  
Container: kibana
Ports:
  - "5061:5601"  # Web dashboard

# Logstash
Container: logstash
Ports:
  - "5044:5044"  # Beats protocol input
  - "9600:9600"  # Monitoring API
```

**Access:**
- **Kibana**: http://YOUR_IP:5061
- **Elasticsearch**: http://YOUR_IP:9200
- **Logstash Monitoring**: http://YOUR_IP:9600

---

### **3. SonarQube + Database**
```yaml
# SonarQube
Container: sonarqube-sonarqube-1
Ports:
  - "9000:9000"  # Web interface

# PostgreSQL
Container: sonarqube-postgres-1
Ports:
  - "5433:5432"  # Database (different port to avoid conflict)
```

**Access:**
- **SonarQube**: http://YOUR_IP:9000
- **Default Credentials**: admin / admin

---

### **4. Tomcat + React App**
```yaml
Container: tomcat-tomcat-1
Ports:
  - "8080:8080"  # Web server
```

**Access:**
- **Tomcat Manager**: http://YOUR_IP:8080
- **React App**: http://YOUR_IP:8080/group6-react-app/

---

## 🛡️ **AWS Security Group Configuration**

### **Required Inbound Rules:**
```
Port 22    (SSH)         - YOUR_IP/32
Port 80    (HTTP)        - 0.0.0.0/0
Port 443   (HTTPS)       - 0.0.0.0/0
Port 5044  (Logstash)    - YOUR_IP/32
Port 5061  (Kibana)      - YOUR_IP/32
Port 8080  (Tomcat)      - YOUR_IP/32
Port 8081  (GitLab)      - YOUR_IP/32
Port 8022  (GitLab SSH)  - YOUR_IP/32
Port 9000  (SonarQube)   - YOUR_IP/32
Port 9200  (Elasticsearch) - YOUR_IP/32
```

---

## 🔍 **Port Status Checking Commands**

### **Check if services are listening:**
```bash
# On the EC2 instance
sudo netstat -tlnp | grep -E ':(8080|8081|9000|5601|9200)'

# Check Docker port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Test connectivity from outside
curl -I http://YOUR_PUBLIC_IP:8081  # GitLab
curl -I http://YOUR_PUBLIC_IP:9000  # SonarQube
curl -I http://YOUR_PUBLIC_IP:5061  # Kibana
```

### **Troubleshooting port access:**
```bash
# Check AWS Security Group
aws ec2 describe-security-groups --group-ids YOUR_SG_ID

# Check local firewall (if enabled)
sudo iptables -L

# Test from inside the instance
curl http://localhost:8081  # Should work
curl http://localhost:9000  # Should work
```

---

## ⚠️ **Important Notes:**

1. **Database Ports**: 5432 and 5433 are for internal database access only
2. **Security**: Most ports are restricted to your IP for security
3. **GitLab SSH**: Use port 8022, not standard 22
4. **Cost Impact**: Each open port doesn't increase cost, but running services do
5. **Firewall**: Amazon Linux 2023 doesn't have firewall enabled by default

---

## 🎯 **Quick Access Summary:**

**Replace `YOUR_PUBLIC_IP` with: `54.176.13.124` (your current instance)**

```
GitLab:       http://54.176.13.124:8081
SonarQube:    http://54.176.13.124:9000  
React App:    http://54.176.13.124:8080/group6-react-app/
Kibana:       http://54.176.13.124:5061
```

All these should be accessible from your browser! 🚀