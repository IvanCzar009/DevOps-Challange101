# Configure AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "ELK-Terraform"
}

variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = "Pair06"
}

# Create Security Group
resource "aws_security_group" "instance_sg" {
  name        = "ELK-Terraform-security-group-v4"
  description = "Security group for ELK stack and CI/CD tools"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tomcat
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # GitLab
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-security-group"
  }
}

# Create EC2 Instance
resource "aws_instance" "main_instance" {
  ami                    = "ami-038bba9a164eb3dc1"
  instance_type          = "t3.2xlarge"
  key_name              = var.key_name
  security_groups       = [aws_security_group.instance_sg.name]
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    
    # Install Node.js 18
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs
    
    # Install Java (required for jar command)
    yum install -y java-11-openjdk-devel
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Install git
    yum install -y git
  EOF
  )

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = var.instance_name
  }

  # Wait for instance to be ready
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = self.public_ip
      timeout     = "10m"
    }

    inline = [
      "echo 'Instance is ready, waiting for system initialization...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo '.'; sleep 2; done",
      "echo 'Cloud-init completed, system is ready'"
    ]
  }

  # Run the complete installation directly (no file transfers needed)
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = self.public_ip
      timeout     = "45m"
    }

    inline = [
      "echo '=== Starting Complete CI/CD Stack Deployment ==='",
      "echo 'Starting at: $(date)'",
      "log() { echo \"[$(date '+%Y-%m-%d %H:%M:%S')] \\$1\"; }",
      "log 'System ready. Starting deployment...'",
      "log '=== STEP 1/5: Installing ELK Stack ==='",
      "mkdir -p /home/ec2-user/elk-stack && cd /home/ec2-user/elk-stack",
      "mkdir -p elk-config",
      "cat > docker-compose.yml << 'ELKEOF'",
      "version: '3.8'",
      "services:",
      "  elasticsearch:",
      "    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.4",
      "    container_name: elasticsearch",
      "    environment:",
      "      - node.name=elasticsearch",
      "      - cluster.name=docker-cluster",
      "      - discovery.type=single-node",
      "      - ES_JAVA_OPTS=-Xms1g -Xmx1g",
      "      - xpack.security.enabled=false",
      "    ports:",
      "      - 9200:9200",
      "    volumes:",
      "      - elasticsearch_data:/usr/share/elasticsearch/data",
      "    networks:",
      "      - elk_network",
      "  kibana:",
      "    image: docker.elastic.co/kibana/kibana:8.10.4",
      "    container_name: kibana",
      "    ports:",
      "      - 5061:5601",
      "    environment:",
      "      ELASTICSEARCH_HOSTS: http://elasticsearch:9200",
      "    networks:",
      "      - elk_network",
      "    depends_on:",
      "      - elasticsearch",
      "volumes:",
      "  elasticsearch_data:",
      "networks:",
      "  elk_network:",
      "    driver: bridge",
      "ELKEOF",
      "log 'Starting ELK Stack...'",
      "docker-compose up -d",
      "sleep 60",
      "log 'ELK Stack started'",
      "log '=== STEP 2/5: Installing GitLab ==='",
      "mkdir -p /home/ec2-user/gitlab && cd /home/ec2-user/gitlab",
      "cat > docker-compose.yml << 'GITLABEOF'",
      "version: '3.8'",
      "services:",
      "  postgres:",
      "    image: postgres:13",
      "    environment:",
      "      POSTGRES_DB: gitlabhq_production",
      "      POSTGRES_USER: gitlab",
      "      POSTGRES_PASSWORD: gitlab_password",
      "    volumes:",
      "      - postgres_data:/var/lib/postgresql/data",
      "  gitlab:",
      "    image: gitlab/gitlab-ce:16.5.1-ce.0",
      "    environment:",
      "      GITLAB_OMNIBUS_CONFIG: |",
      "        external_url 'http://localhost:8081'",
      "        gitlab_rails['initial_root_password'] = 'admin123456'",
      "        postgresql['enable'] = false",
      "        gitlab_rails['db_host'] = 'postgres'",
      "        gitlab_rails['db_password'] = 'gitlab_password'",
      "    ports:",
      "      - 8081:80",
      "    volumes:",
      "      - gitlab_data:/var/opt/gitlab",
      "    depends_on:",
      "      - postgres",
      "volumes:",
      "  postgres_data:",
      "  gitlab_data:",
      "GITLABEOF",
      "log 'Starting GitLab (this takes 10-15 minutes)...'",
      "docker-compose up -d",
      "sleep 300",
      "log 'GitLab started'",
      "log '=== STEP 3/5: Installing SonarQube ==='",
      "mkdir -p /home/ec2-user/sonarqube && cd /home/ec2-user/sonarqube",
      "cat > docker-compose.yml << 'SONAREOF'",
      "version: '3.8'",
      "services:",
      "  sonarqube:",
      "    image: sonarqube:10.2-community",
      "    ports:",
      "      - 9000:9000",
      "    volumes:",
      "      - sonarqube_data:/opt/sonarqube/data",
      "volumes:",
      "  sonarqube_data:",
      "SONAREOF",
      "log 'Starting SonarQube...'",
      "docker-compose up -d",
      "sleep 120",
      "log 'SonarQube started'",
      "log '=== STEP 4/5: Installing Tomcat ==='",
      "mkdir -p /home/ec2-user/tomcat && cd /home/ec2-user/tomcat",
      "cat > docker-compose.yml << 'TOMCATEOF'",
      "version: '3.8'",
      "services:",
      "  tomcat:",
      "    image: tomcat:10.1-jdk11",
      "    ports:",
      "      - 8080:8080",
      "    volumes:",
      "      - tomcat_webapps:/usr/local/tomcat/webapps",
      "volumes:",
      "  tomcat_webapps:",
      "TOMCATEOF",
      "log 'Starting Tomcat...'",
      "docker-compose up -d",
      "sleep 30",
      "log 'Tomcat started'",
      "log '=== STEP 5/5: Deploying React Application ==='",
      "mkdir -p /home/ec2-user/react-app && cd /home/ec2-user/react-app",
      "mkdir -p public src",
      "cat > package.json << 'REACTEOF'",
      "{",
      "  \"name\": \"group6-react-app\",",
      "  \"version\": \"1.0.0\",",
      "  \"dependencies\": {",
      "    \"react\": \"^18.2.0\",",
      "    \"react-dom\": \"^18.2.0\",",
      "    \"react-scripts\": \"5.0.1\"",
      "  },",
      "  \"scripts\": {",
      "    \"build\": \"react-scripts build\"",
      "  }",
      "}",
      "REACTEOF",
      "cat > public/index.html << 'HTMLEOF'",
      "<!DOCTYPE html>",
      "<html><head><title>Group 6 React App</title></head>",
      "<body><div id=\"root\"></div></body></html>",
      "HTMLEOF",
      "cat > src/index.js << 'JSEOF'",
      "import React from 'react';",
      "import ReactDOM from 'react-dom/client';",
      "const App = () => (",
      "  React.createElement('div', {style: {textAlign: 'center', padding: '50px'}}, [",
      "    React.createElement('h1', {key: 'h1'}, 'Group 6 React Application'),",
      "    React.createElement('p', {key: 'p'}, 'Successfully deployed via CI/CD Pipeline!')",
      "  ])",
      ");",
      "const root = ReactDOM.createRoot(document.getElementById('root'));",
      "root.render(React.createElement(App));",
      "JSEOF",
      "log 'Building React application...'",
      "npm install --silent",
      "npm run build",
      "cd build",
      "jar -cvf ../group6-react-app.war * > /dev/null 2>&1",
      "cd ..",
      "docker cp group6-react-app.war tomcat:/usr/local/tomcat/webapps/",
      "sleep 20",
      "log 'React application deployed'",
      "PUBLIC_IP=\\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",
      "log '=== DEPLOYMENT COMPLETE ==='",
      "echo 'YOUR REACT APPLICATION:'",
      "echo \"  - React App: http://\\$PUBLIC_IP:8080/group6-react-app/\"",
      "echo 'CI/CD TOOLS:'",
      "echo \"  - GitLab: http://\\$PUBLIC_IP:8081\"",
      "echo \"  - SonarQube: http://\\$PUBLIC_IP:9000\"",
      "echo \"  - Tomcat: http://\\$PUBLIC_IP:8080\"",
      "echo \"  - Kibana: http://\\$PUBLIC_IP:5061\"",
      "log 'All services deployed successfully!'"
    ]
  }
}

# Create Elastic IP
resource "aws_eip" "instance_eip" {
  instance = aws_instance.main_instance.id
  domain   = "vpc"

  tags = {
    Name = "${var.instance_name}-eip"
  }

  depends_on = [aws_instance.main_instance]
}

# Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main_instance.id
}

output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.main_instance.public_ip
}

output "elastic_ip" {
  description = "Elastic IP address"
  value       = aws_eip.instance_eip.public_ip
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_eip.instance_eip.public_ip}"
}