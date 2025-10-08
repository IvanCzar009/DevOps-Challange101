# Variables
variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "devops-challenge-instance"
}

variable "key_name" {
  description = "AWS key pair name"
  type        = string
  default     = "Pair06"
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
  region = "us-east-1"
}

# Create Security Group
resource "aws_security_group" "instance_sg" {
  name        = "devops-challenge-sg"
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

  # Kibana - Updated to use port 5061
  ingress {
    from_port   = 5061
    to_port     = 5061
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

  # Transfer installation scripts to the instance
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = self.public_ip
      timeout     = "10m"
    }

    source      = "./sequential-install.sh"
    destination = "/tmp/sequential-install.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = self.public_ip
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
      host        = self.public_ip
      timeout     = "10m"
    }

    source      = "./install-gitlab.sh"
    destination = "/tmp/install-gitlab.sh"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = self.public_ip
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
      host        = self.public_ip
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
      host        = self.public_ip
      timeout     = "10m"
    }

    source      = "./deploy-react-app.sh"
    destination = "/tmp/deploy-react-app.sh"
  }

  # Transfer the entire React app directory
  provisioner "file" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = self.public_ip
      timeout     = "10m"
    }

    source      = "./group6-react-app/"
    destination = "/tmp/group6-react-app/"
  }

  # Run the sequential installation using your robust scripts
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = self.public_ip
      timeout     = "60m"
    }

    inline = [
      "echo '=== Starting Automated CI/CD Stack Deployment ==='",
      "echo 'Using robust sequential installation scripts with GitLab reconfigure'",
      "echo 'Starting at: $(date)'",
      "chmod +x /tmp/*.sh",
      "sudo /tmp/sequential-install.sh"
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

output "application_urls" {
  description = "URLs for accessing deployed applications"
  value = {
    react_app    = "http://${aws_eip.instance_eip.public_ip}:8080/group6-react-app/"
    gitlab       = "http://${aws_eip.instance_eip.public_ip}:8081"
    sonarqube    = "http://${aws_eip.instance_eip.public_ip}:9000"
    tomcat       = "http://${aws_eip.instance_eip.public_ip}:8080"
    kibana       = "http://${aws_eip.instance_eip.public_ip}:5061"
    elasticsearch = "http://${aws_eip.instance_eip.public_ip}:9200"
  }
}