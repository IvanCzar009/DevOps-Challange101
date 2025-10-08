#!/bin/bash

# CI/CD Stack Logs Management Script
# Usage: ./logs.sh [service-name] [options]

COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show logs for specific service
show_service_logs() {
    local service=$1
    local lines=${2:-50}
    local follow=${3:-false}
    
    print_colored $BLUE "=== $service Logs (last $lines lines) ==="
    
    if ! docker-compose ps --services | grep -q "^$service$"; then
        print_colored $RED "ERROR: Service '$service' not found."
        return 1
    fi
    
    if [ "$follow" = true ]; then
        print_colored $YELLOW "Following logs for $service (Press Ctrl+C to stop)..."
        docker-compose logs -f --tail=$lines $service
    else
        docker-compose logs --tail=$lines $service
    fi
}

# Function to show logs for all services
show_all_logs() {
    local lines=${1:-20}
    
    services=("postgresql" "elasticsearch" "logstash" "kibana" "sonarqube" "tomcat" "gitlab")
    
    for service in "${services[@]}"; do
        if docker-compose ps $service | grep -q "Up"; then
            print_colored $BLUE "\n=== $service Logs (last $lines lines) ==="
            docker-compose logs --tail=$lines $service
            echo ""
        fi
    done
}

# Function to show error logs only
show_error_logs() {
    local service=${1:-""}
    
    print_colored $RED "=== Error Logs ==="
    
    if [ -n "$service" ]; then
        # Show errors for specific service
        docker-compose logs $service | grep -i -E "(error|exception|failed|fatal|critical)"
    else
        # Show errors for all services
        services=("postgresql" "elasticsearch" "logstash" "kibana" "sonarqube" "tomcat" "gitlab")
        
        for svc in "${services[@]}"; do
            if docker-compose ps $svc | grep -q "Up"; then
                local errors=$(docker-compose logs $svc | grep -i -E "(error|exception|failed|fatal|critical)")
                if [ -n "$errors" ]; then
                    print_colored $YELLOW "\n--- $svc Errors ---"
                    echo "$errors"
                fi
            fi
        done
    fi
}

# Function to export logs to files
export_logs() {
    local export_dir="logs-export-$(date +%Y%m%d-%H%M%S)"
    mkdir -p $export_dir
    
    print_colored $BLUE "Exporting logs to $export_dir/"
    
    services=("postgresql" "elasticsearch" "logstash" "kibana" "sonarqube" "tomcat" "gitlab")
    
    for service in "${services[@]}"; do
        if docker-compose ps $service | grep -q "Up"; then
            print_colored $GREEN "Exporting $service logs..."
            docker-compose logs $service > "$export_dir/$service.log"
        fi
    done
    
    # Create summary file
    cat > "$export_dir/README.txt" << EOF
CI/CD Stack Logs Export
Generated: $(date)

This directory contains logs from all running CI/CD services:

Services:
$(docker-compose ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}")

System Info:
- Docker Version: $(docker --version)
- Docker Compose Version: $(docker-compose --version)
- Export Time: $(date)

To view logs:
- Use 'less servicename.log' to view individual service logs
- Use 'grep -i error *.log' to find all errors across services
- Use 'tail -f servicename.log' to follow live logs

EOF
    
    print_colored $GREEN "Logs exported successfully to $export_dir/"
    ls -la $export_dir/
}

# Function to clear old logs (Docker container logs)
clear_logs() {
    print_colored $YELLOW "WARNING: This will clear all Docker container logs."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_colored $BLUE "Clearing Docker container logs..."
        
        # Stop all services
        docker-compose stop
        
        # Clear logs for each container
        for container in $(docker-compose ps -q); do
            if [ -n "$container" ]; then
                local container_name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///')
                print_colored $GREEN "Clearing logs for $container_name..."
                sudo sh -c "echo '' > $(docker inspect --format='{{.LogPath}}' $container)"
            fi
        done
        
        # Restart services
        print_colored $BLUE "Restarting services..."
        docker-compose up -d
        
        print_colored $GREEN "Container logs cleared successfully."
    else
        print_colored $YELLOW "Operation cancelled."
    fi
}

# Function to show log statistics
show_log_stats() {
    print_colored $BLUE "=== Log Statistics ==="
    
    services=("postgresql" "elasticsearch" "logstash" "kibana" "sonarqube" "tomcat" "gitlab")
    
    echo "Service         Lines    Size"
    echo "================================"
    
    for service in "${services[@]}"; do
        if docker-compose ps $service | grep -q "Up"; then
            local lines=$(docker-compose logs $service | wc -l)
            local container_id=$(docker-compose ps -q $service)
            local log_path=$(docker inspect --format='{{.LogPath}}' $container_id 2>/dev/null)
            local size="N/A"
            
            if [ -n "$log_path" ] && [ -f "$log_path" ]; then
                size=$(du -h "$log_path" | cut -f1)
            fi
            
            printf "%-15s %-8s %s\n" "$service" "$lines" "$size"
        fi
    done
    
    echo ""
    print_colored $BLUE "Total Docker System Disk Usage:"
    docker system df
}

# Main script execution
main() {
    # Check if docker-compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_colored $RED "ERROR: $COMPOSE_FILE not found in current directory."
        exit 1
    fi
    
    case "${1:-}" in
        "")
            # No arguments - show recent logs for all services
            show_all_logs 20
            ;;
        "errors")
            # Show error logs
            show_error_logs "${2:-}"
            ;;
        "export")
            # Export all logs to files
            export_logs
            ;;
        "clear")
            # Clear all container logs
            clear_logs
            ;;
        "stats")
            # Show log statistics
            show_log_stats
            ;;
        "follow" | "tail" | "-f")
            # Follow logs for specific service
            if [ -n "$2" ]; then
                show_service_logs "$2" 50 true
            else
                print_colored $RED "ERROR: Service name required for follow mode."
                echo "Usage: $0 follow [service-name]"
                exit 1
            fi
            ;;
        *)
            # Show logs for specific service
            local lines=${2:-50}
            show_service_logs "$1" "$lines"
            ;;
    esac
}

# Display usage if help requested
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [service-name|command] [options]"
    echo ""
    echo "Commands:"
    echo "  (no args)         Show recent logs for all services"
    echo "  service-name      Show logs for specific service"
    echo "  service-name N    Show last N lines for specific service"
    echo "  follow service    Follow live logs for specific service"
    echo "  errors [service]  Show error logs (all services or specific)"
    echo "  export            Export all logs to files"
    echo "  clear             Clear all container logs (WARNING: Destructive)"
    echo "  stats             Show log statistics and disk usage"
    echo ""
    echo "Available services: postgresql, elasticsearch, logstash, kibana, sonarqube, tomcat, gitlab"
    echo ""
    echo "Examples:"
    echo "  $0 gitlab         # Show last 50 lines of GitLab logs"
    echo "  $0 gitlab 100     # Show last 100 lines of GitLab logs"
    echo "  $0 follow gitlab  # Follow GitLab logs in real-time"
    echo "  $0 errors         # Show all error logs"
    echo "  $0 export         # Export all logs to files"
    exit 0
fi

# Run main function
main "$@"