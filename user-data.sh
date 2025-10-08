#!/bin/bash

# User Data Script for ELK-Terraform Instance
# This script runs on instance startup to prepare the system

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user-data script execution at $(date)"

# Update the system
echo "Updating system packages..."
yum update -y

# Install essential packages
echo "Installing essential packages..."
yum install -y \
    wget \
    curl \
    unzip \
    tar \
    git \
    htop \
    vim \
    nano \
    net-tools \
    telnet \
    nc \
    tree \
    which \
    yum-utils \
    device-mapper-persistent-data \
    lvm2

# Install Java 11 (required for Elasticsearch, Logstash, and SonarQube)
echo "Installing Java 11..."
yum install -y java-11-openjdk java-11-openjdk-devel

# Set JAVA_HOME
echo "Setting JAVA_HOME..."
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' >> /etc/environment
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /etc/environment
source /etc/environment

# Install Docker
echo "Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install Node.js 18 (for React app)
echo "Installing Node.js..."
curl -sL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Python 3 and pip (useful for various tools)
echo "Installing Python 3..."
yum install -y python3 python3-pip

# Create directories for applications
echo "Creating application directories..."
mkdir -p /opt/tomcat
mkdir -p /opt/gitlab
mkdir -p /opt/elk
mkdir -p /opt/sonarqube
mkdir -p /opt/vault
mkdir -p /opt/react-app
mkdir -p /opt/scripts

# Set permissions
chown -R ec2-user:ec2-user /opt/

# Create a systemd service for Tomcat (placeholder - will be configured by tomcat-install.sh)
echo "Preparing Tomcat service configuration..."
cat > /etc/systemd/system/tomcat.service << 'EOF'
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=ec2-user
Group=ec2-user
Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Configure firewall (if firewalld is running)
if systemctl is-active --quiet firewalld; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=8081/tcp
    firewall-cmd --permanent --add-port=8083/tcp
    firewall-cmd --permanent --add-port=9000/tcp
    firewall-cmd --permanent --add-port=9200/tcp
    firewall-cmd --permanent --add-port=5044/tcp
    firewall-cmd --permanent --add-port=5061/tcp
    firewall-cmd --reload
fi

# Increase system limits for Elasticsearch
echo "Configuring system limits for Elasticsearch..."
cat >> /etc/security/limits.conf << 'EOF'
# Elasticsearch limits
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
elasticsearch soft nofile 65536
elasticsearch hard nofile 65536
ec2-user soft memlock unlimited
ec2-user hard memlock unlimited
ec2-user soft nofile 65536
ec2-user hard nofile 65536
EOF

# Configure sysctl for Elasticsearch
cat >> /etc/sysctl.conf << 'EOF'
# Elasticsearch configuration
vm.max_map_count=262144
vm.swappiness=1
EOF
sysctl -p

# Create a welcome message
cat > /home/ec2-user/README.txt << 'EOF'
Welcome to your ELK-Terraform Instance!

This instance has been configured with:
- Java 11 OpenJDK
- Docker and Docker Compose
- Node.js 18
- Python 3
- Essential development tools

Application directories:
- /opt/tomcat - Apache Tomcat
- /opt/gitlab - GitLab
- /opt/elk - ELK Stack (Elasticsearch, Logstash, Kibana)
- /opt/sonarqube - SonarQube
- /opt/vault - HashiCorp Vault
- /opt/react-app - React Application

Logs:
- User data execution: /var/log/user-data.log
- Cloud init logs: /var/log/cloud-init.log

Next steps:
1. Run the installation scripts in /tmp/
2. Configure each service as needed
3. Access services via their respective ports

Happy coding!
EOF

chown ec2-user:ec2-user /home/ec2-user/README.txt

# Set hostname
hostnamectl set-hostname elk-terraform-instance

# Create a status file to indicate user-data completion
echo "User-data script completed successfully at $(date)" > /tmp/user-data-complete
chown ec2-user:ec2-user /tmp/user-data-complete

echo "User-data script execution completed at $(date)"

# Reboot to ensure all changes take effect (optional - uncomment if needed)
# echo "Rebooting instance to apply all changes..."
# reboot