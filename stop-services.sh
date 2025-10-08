#!/bin/bash

# CI/CD Stack Management Script - Stop Services
# Usage: ./stop-services.sh [service-name] or ./stop-services.sh (for all services)

set -e

COMPOSE_FILE="docker-compose.yml"
LOG_FILE="/var/log/cicd-stop.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to check if docker-compose file exists
check_compose_file() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_message "ERROR: $COMPOSE_FILE not found in current directory."
        exit 1
    fi
}

# Function to stop specific service
stop_service() {
    local service=$1
    log_message "Stopping $service service..."
    
    if docker-compose ps --services | grep -q "^$service$"; then
        docker-compose stop $service
        log_message "$service service stopped successfully."
    else
        log_message "ERROR: Service '$service' not found in docker-compose.yml"
        exit 1
    fi
}

# Function to stop all services gracefully
stop_all_services() {
    log_message "Stopping all CI/CD services gracefully..."
    
    # Stop services in reverse order (application services first)
    log_message "Stopping GitLab..."
    docker-compose stop gitlab
    
    log_message "Stopping application services..."
    docker-compose stop tomcat sonarqube kibana logstash
    
    # Stop infrastructure services last
    log_message "Stopping infrastructure services..."
    docker-compose stop elasticsearch postgresql
    
    log_message "All services stopped successfully."
}

# Function to remove all containers (cleanup)
cleanup_services() {
    log_message "Stopping and removing all containers..."
    docker-compose down
    
    # Optional: Remove unused volumes (uncomment if needed)
    # log_message "Removing unused volumes..."
    # docker volume prune -f
    
    log_message "Cleanup completed."
}

# Function to show current service status
show_status() {
    echo "Current CI/CD Services Status:"
    echo "=============================="
    docker-compose ps
    echo ""
    
    # Show resource usage
    echo "Docker Resource Usage:"
    echo "====================="
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
}

# Main script execution
main() {
    log_message "Starting CI/CD Stack Stop Process..."
    
    # Check prerequisites
    check_compose_file
    
    # Parse arguments
    case "${1:-}" in
        "")
            # No arguments - stop all services
            stop_all_services
            ;;
        "cleanup")
            # Cleanup - stop and remove containers
            cleanup_services
            ;;
        "status")
            # Show status
            show_status
            exit 0
            ;;
        *)
            # Stop specific service
            stop_service $1
            ;;
    esac
    
    log_message "CI/CD stack stop process completed successfully."
}

# Display usage if help requested
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [service-name|cleanup|status]"
    echo ""
    echo "Options:"
    echo "  (no args)     Stop all services gracefully"
    echo "  service-name  Stop specific service"
    echo "  cleanup       Stop and remove all containers"
    echo "  status        Show current service status"
    echo ""
    echo "Available services: postgresql, elasticsearch, logstash, kibana, sonarqube, tomcat, gitlab"
    exit 0
fi

# Run main function
main "$@"