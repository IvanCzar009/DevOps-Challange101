# Variables
variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "ELK-challenge101-instance"
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

# Generate random suffix for unique naming
resource "random_id" "sg_suffix" {
  byte_length = 4
}

# Create Security Group
resource "aws_security_group" "instance_sg" {
  name        = "ELK-${random_id.sg_suffix.hex}"
  description = "Allow inbound traffic for CI/CD tools"

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Elasticsearch
  ingress {
    description = "Elasticsearch"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kibana - Updated to use port 8443
  ingress {
    description = "Kibana"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tomcat
  ingress {
    description = "Tomcat"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube
  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # React App
  ingress {
    description = "React"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins
  ingress {
    description = "Jenkins"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Logstash API
  ingress {
    description = "Logstash"
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
      "echo 'Cloud-init completed, system is ready'",
      "echo 'Creating and configuring /tmp directory...'",
      "sudo mkdir -p /tmp",
      "sudo chmod 1777 /tmp",
      "sudo chown root:root /tmp",
      "ls -la /tmp",
      "echo 'Ready for file transfers'"
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
    destination = "/home/ec2-user/sequential-install-jenkins.sh"
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
    destination = "/home/ec2-user/install-elk.sh"
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
    destination = "/home/ec2-user/install-jenkins.sh"
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
    destination = "/home/ec2-user/install-sonarqube.sh"
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
    destination = "/home/ec2-user/install-tomcat.sh"
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
    destination = "/home/ec2-user/install-react-app.sh"
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
    destination = "/home/ec2-user/deploy-react-app.sh"
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
    destination = "/home/ec2-user/"
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
    destination = "/home/ec2-user/configure-sonarqube.sh"
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
    destination = "/home/ec2-user/automate-jenkins-pipeline.sh"  
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
    destination = "/home/ec2-user/automate-sonarqube-project.sh"
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
    destination = "/home/ec2-user/monitor-jenkins-build.sh"
  }

  # Verify all files are transferred and set permissions
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./Pair06.pem")
      host        = aws_eip.instance_eip.public_ip
      timeout     = "10m"
    }

    inline = [
      "echo 'Verifying file transfers...'",
      "ls -la /home/ec2-user/*.sh",
      "echo 'Setting execute permissions on all scripts...'",
      "chmod +x /home/ec2-user/*.sh",
      "echo 'Verification complete. Files ready for execution:'"
    ]
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
      "echo 'Copying files from home directory to /tmp for script compatibility...'",
      "sudo mkdir -p /tmp",
      "sudo chmod 1777 /tmp",
      "cp /home/ec2-user/*.sh /tmp/ 2>/dev/null || echo 'Some files may not have copied'",
      "cp -r /home/ec2-user/group6-react-app /tmp/ 2>/dev/null || echo 'React app directory copy may have failed'",
      "echo 'Converting line endings for all scripts...'",
      "for script in /tmp/*.sh; do",
      "  if [ -f \"$script\" ]; then",
      "    sed -i 's/\\r$//' \"$script\"",
      "    chmod +x \"$script\"",
      "    echo \"Converted: $script\"",
      "  fi",
      "done",
      "ls -la /tmp/*.sh || echo 'No .sh files found in /tmp'",
      "echo 'Files copied, converted, and permissions set'",
      "# Fix vm.max_map_count for SonarQube/Elasticsearch",
      "echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p",
      "echo 'System parameters configured'",
      "# Check if sequential-install-jenkins.sh exists",
      "if [ -f '/tmp/sequential-install-jenkins.sh' ]; then",
      "  echo 'sequential-install-jenkins.sh found, proceeding with installation...'",
      "  echo 'Starting sequential installation...'",
      "/tmp/sequential-install-jenkins.sh",
      "  INSTALL_EXIT_CODE=$?",
      "  if [ $INSTALL_EXIT_CODE -eq 0 ]; then",
      "    echo '✅ Installation completed successfully'",
      "  else",
      "    echo '❌ Installation failed with exit code: $INSTALL_EXIT_CODE'",
      "    exit $INSTALL_EXIT_CODE",
      "  fi",
      "else",
      "  echo '❌ Error: /tmp/sequential-install-jenkins.sh not found!'",
      "  echo 'Available files in /tmp:'",
      "  ls -la /tmp/",
      "  echo 'Available files in home directory:'",
      "  ls -la /home/ec2-user/",
      "  exit 1",
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
