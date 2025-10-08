#!/bin/bash

# CI/CD Stack Management Script - Start Services
# Usage: ./start-services.sh [service-name] or ./start-services.sh (for all services)

set -e

COMPOSE_FILE="docker-compose.yml"
LOG_FILE="/var/log/cicd-start.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_message "ERROR: Docker is not running. Please start Docker service."
        exit 1
    fi
}

# Function to check if docker-compose file exists
check_compose_file() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_message "ERROR: $COMPOSE_FILE not found in current directory."
        exit 1
    fi
}

# Function to start specific service
start_service() {
    local service=$1
    log_message "Starting $service service..."
    
    if docker-compose ps --services | grep -q "^$service$"; then
        docker-compose up -d $service
        log_message "$service service started successfully."
        
        # Wait for service to be healthy
        log_message "Waiting for $service to be healthy..."
        timeout=300
        counter=0
        
        while [ $counter -lt $timeout ]; do
            if docker-compose ps $service | grep -q "Up (healthy)\|Up [0-9]"; then
                log_message "$service is now healthy and ready!"
                break
            fi
            sleep 5
            counter=$((counter + 5))
            echo -n "."
        done
        
        if [ $counter -ge $timeout ]; then
            log_message "WARNING: $service health check timed out. Service may still be starting."
        fi
    else
        log_message "ERROR: Service '$service' not found in docker-compose.yml"
        exit 1
    fi
}

# Function to start all services
start_all_services() {
    log_message "Starting all CI/CD services..."
    
    # Start infrastructure services first
    log_message "Starting infrastructure services (PostgreSQL, Elasticsearch)..."
    docker-compose up -d postgresql elasticsearch
    
    # Wait for infrastructure to be ready
    sleep 30
    
    # Start application services
    log_message "Starting application services..."
    docker-compose up -d logstash kibana sonarqube tomcat
    
    # Wait for application services
    sleep 20
    
    # Start GitLab last (it takes the longest)
    log_message "Starting GitLab (this may take several minutes)..."
    docker-compose up -d gitlab
    
    log_message "All services started. Checking status..."
    docker-compose ps
}

# Function to display service URLs
show_service_urls() {
    local public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    
    echo ""
    echo "=========================================="
    echo "CI/CD Services Access Information"
    echo "=========================================="
    echo "GitLab:      http://$public_ip:8083"
    echo "SonarQube:   http://$public_ip:9000"
    echo "Tomcat:      http://$public_ip:8080"
    echo "Kibana:      http://$public_ip:5061"
    echo "Elasticsearch: http://$public_ip:9200"
    echo ""
    echo "Default Credentials:"
    echo "- Elasticsearch: elastic / changeme123"
    echo "- Tomcat Manager: admin / admin123"
    echo "- SonarQube: admin / admin (change on first login)"
    echo "- GitLab: root / (check initial_root_password)"
    echo ""
    echo "To get GitLab root password:"
    echo "docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password"
    echo "=========================================="
}

# Main script execution
main() {
    log_message "Starting CI/CD Stack Management..."
    
    # Check prerequisites
    check_docker
    check_compose_file
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        # No arguments - start all services
        start_all_services
        show_service_urls
    elif [ $# -eq 1 ]; then
        # One argument - start specific service
        start_service $1
        echo "Service $1 started successfully."
    else
        echo "Usage: $0 [service-name]"
        echo "Available services: postgresql, elasticsearch, logstash, kibana, sonarqube, tomcat, gitlab"
        exit 1
    fi
    
    log_message "CI/CD stack startup completed successfully."
}

# Run main function
main "$@"