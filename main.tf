# Variables
variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "devops-challenge101-instance"
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
  default     = "Pair06"
}

variable "sonarqube_password" {
  description = "SonarQube admin password (leave empty for auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "jenkins_password" {
  description = "Jenkins admin password (leave empty for default)"
  type        = string
  default     = "admin123456"
  sensitive   = true
}

# AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

# Create Security Group
resource "aws_security_group" "instance_sg" {
  name        = "ELK-challenge101-sg"
  description      = "Allow inbound traffic for CI/CD tools"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Elasticsearch
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kibana - Updated to use port 8443
  ingress {
    from_port   = 8443
    to_port     = 8443
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

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # React App
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Logstash API
  ingress {
    from_port   = 9600
    to_port     = 9600
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
  ami                    = "ami-0945610b37068d87a"
  instance_type          = "t3.2xlarge"
  key_name              = var.key_name
  security_groups       = [aws_security_group.instance_sg.name]
  associate_public_ip_address = false  # We'll use Elastic IP instead
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
}

# Create Elastic IP after instance is created
resource "aws_eip" "instance_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.instance_name}-eip"
  }

  depends_on = [aws_instance.main_instance]
}

# Associate Elastic IP with instance
resource "aws_eip_association" "instance_eip_association" {
  instance_id   = aws_instance.main_instance.id
  allocation_id = aws_eip.instance_eip.id

  depends_on = [aws_instance.main_instance, aws_eip.instance_eip]
}

# Add provisioners to the instance after Elastic IP is ready
resource "null_resource" "instance_provisioning" {
  # Triggers to ensure provisioning runs when needed
  triggers = {
    instance_id = aws_instance.main_instance.id
    elastic_ip  = aws_eip.instance_eip.public_ip
  }

  # Ensure this runs after Elastic IP is associated
  depends_on = [aws_eip_association.instance_eip_association]

  # Wait for instance to be ready
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    inline = [
      "echo 'Instance is ready, waiting for system initialization...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo '.'; sleep 2; done",
      "echo 'Cloud-init completed, system is ready'"
    ]
  }

  # Transfer installation scripts to the instance
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./sequential-install-jenkins.sh"
    destination = "/tmp/sequential-install-jenkins.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./install-elk.sh"
    destination = "/tmp/install-elk.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./install-jenkins.sh"
    destination = "/tmp/install-jenkins.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./install-sonarqube.sh"
    destination = "/tmp/install-sonarqube.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./install-tomcat.sh"
    destination = "/tmp/install-tomcat.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./install-react-app.sh"
    destination = "/tmp/install-react-app.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./deploy-react-app.sh"
    destination = "/tmp/deploy-react-app.sh"
  }

  # Transfer your group6-react-app
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./group6-react-app"
    destination = "/tmp/"
  }

  # Transfer configuration scripts
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./configure-sonarqube.sh"
    destination = "/tmp/configure-sonarqube.sh"
  }

  # Transfer automation scripts for Jenkins and SonarQube
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./automate-jenkins-pipeline.sh"
    destination = "/tmp/automate-jenkins-pipeline.sh"  
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./automate-sonarqube-project.sh"
    destination = "/tmp/automate-sonarqube-project.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    source      = "./monitor-jenkins-build.sh"
    destination = "/tmp/monitor-jenkins-build.sh"
  }

  # Run the sequential installation using Jenkins-based solution
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "60m"
    }

    inline = [
      "echo '=== Starting Complete CI/CD Stack Deployment ==='",
      "echo 'Deploying: ELK Stack → Jenkins → SonarQube → Tomcat → React App'",
      "echo 'Starting at: $(date)'",
      "echo 'This will deploy the complete working solution in one command'",
      "chmod +x /tmp/*.sh",
      "echo 'Scripts permissions set'",
      "# Fix vm.max_map_count for SonarQube/Elasticsearch",
      "echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p",
      "echo 'System parameters configured'",
      "# Run the complete Jenkins-based installation with explicit timeout",
      "echo 'Starting sequential installation...'",
      "timeout 3600 /tmp/sequential-install-jenkins.sh",
      "INSTALL_EXIT_CODE=$?",
      "if [ $INSTALL_EXIT_CODE -eq 0 ]; then",
      "  echo '✅ Installation completed successfully'",
      "elif [ $INSTALL_EXIT_CODE -eq 124 ]; then",
      "  echo '⚠️ Installation timed out after 1 hour'",
      "  exit 1",
      "else",
      "  echo '❌ Installation failed with exit code: $INSTALL_EXIT_CODE'",
      "  exit $INSTALL_EXIT_CODE",
      "fi",
      "echo 'Provisioning completed at: $(date)'"
    ]
  }
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

output "application_urls" {
  description = "URLs for accessing deployed applications"
  value = {
    group6_react_app     = "http://${aws_eip.instance_eip.public_ip}:8080/group6-react-app/"
    react_dashboard      = "http://${aws_eip.instance_eip.public_ip}:3000"
    jenkins_dashboard    = "http://${aws_eip.instance_eip.public_ip}:8081"
    jenkins_pipeline     = "http://${aws_eip.instance_eip.public_ip}:8081/job/group6-react-app-pipeline"
    sonarqube_dashboard  = "http://${aws_eip.instance_eip.public_ip}:9000"
    sonarqube_project    = "http://${aws_eip.instance_eip.public_ip}:9000/dashboard?id=group6-react-app"
    tomcat               = "http://${aws_eip.instance_eip.public_ip}:8080"
    kibana               = "http://${aws_eip.instance_eip.public_ip}:8443"
    elasticsearch        = "http://${aws_eip.instance_eip.public_ip}:9200"
    logstash             = "http://${aws_eip.instance_eip.public_ip}:9600"
  }
}

output "service_credentials" {
  description = "Service credentials and configuration info"
  value = {
    jenkins_admin          = "admin"
    jenkins_password       = var.jenkins_password
    jenkins_pipeline       = "group6-react-app-pipeline (auto-created)"
    sonarqube_admin        = "admin"
    sonarqube_note         = "Password auto-generated and saved on server"
    sonarqube_project      = "Group6-React-App (auto-configured)"
    tomcat_admin           = "admin"
    tomcat_password        = "admin123"
    credentials_location   = "SSH to server and check /home/ec2-user/sonarqube-config.txt"
    automation_note        = "Jenkins pipeline and SonarQube project fully automated"
  }
  sensitive = true
}

output "credentials_access_command" {
  description = "Command to retrieve SonarQube credentials"
  value = "ssh -i ${var.key_name}.pem ec2-user@${aws_eip.instance_eip.public_ip} 'cat /home/ec2-user/sonarqube-config.txt'"
  sensitive = true
}

output "jenkins_pipeline_info" {
  description = "Jenkins pipeline access information"
  value = {
    pipeline_url         = "http://${aws_eip.instance_eip.public_ip}:8081/job/group6-react-app-pipeline"
    build_trigger_url    = "http://${aws_eip.instance_eip.public_ip}:8081/job/group6-react-app-pipeline/build"
    pipeline_name        = "group6-react-app-pipeline"
    auto_created         = "Yes - Fully automated via Terraform"
    features_included    = "Build, Test, SonarQube Analysis, Deploy to Tomcat, Health Check"
  }
}
