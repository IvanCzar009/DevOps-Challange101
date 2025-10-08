#!/bin/bash

# CI/CD Stack Status and Monitoring Script
# Usage: ./status.sh [service-name] or ./status.sh (for all services)

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

# Function to check service health
check_service_health() {
    local service=$1
    local status=$(docker-compose ps $service 2>/dev/null | grep $service | awk '{print $4}')
    
    if [[ $status == *"Up"* ]]; then
        if [[ $status == *"healthy"* ]]; then
            print_colored $GREEN "✓ $service: Healthy"
        else
            print_colored $YELLOW "⚠ $service: Running (health check pending)"
        fi
        return 0
    elif [[ $status == *"Exit"* ]]; then
        print_colored $RED "✗ $service: Exited"
        return 1
    else
        print_colored $RED "✗ $service: Not running"
        return 1
    fi
}

# Function to show service URLs and credentials
show_access_info() {
    local public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    
    print_colored $BLUE "\n=========================================="
    print_colored $BLUE "CI/CD Services Access Information"
    print_colored $BLUE "=========================================="
    
    # Check each service and show URL if running
    if docker-compose ps gitlab | grep -q "Up"; then
        echo "GitLab:         http://$public_ip:8083"
        echo "GitLab SSH:     git@$public_ip:2222"
        echo "GitLab Registry: http://$public_ip:5050"
    fi
    
    if docker-compose ps sonarqube | grep -q "Up"; then
        echo "SonarQube:      http://$public_ip:9000"
    fi
    
    if docker-compose ps tomcat | grep -q "Up"; then
        echo "Tomcat:         http://$public_ip:8080"
        echo "Tomcat Manager: http://$public_ip:8080/manager"
    fi
    
    if docker-compose ps kibana | grep -q "Up"; then
        echo "Kibana:         http://$public_ip:5061"
    fi
    
    if docker-compose ps elasticsearch | grep -q "Up"; then
        echo "Elasticsearch:  http://$public_ip:9200"
    fi
    
    print_colored $BLUE "\n=========================================="
    print_colored $YELLOW "Default Credentials:"
    echo "Elasticsearch:  elastic / changeme123"
    echo "Tomcat Manager: admin / admin123"
    echo "SonarQube:      admin / admin (change on first login)"
    echo "GitLab root:    Run 'docker exec -it gitlab grep Password /etc/gitlab/initial_root_password'"
    print_colored $BLUE "=========================================="
}

# Function to show detailed service information
show_service_details() {
    local service=$1
    
    print_colored $BLUE "\n=== $service Service Details ==="
    
    # Container status
    docker-compose ps $service
    
    # Resource usage
    echo -e "\nResource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" | grep -E "(CONTAINER|$service)"
    
    # Recent logs (last 10 lines)
    echo -e "\nRecent Logs (last 10 lines):"
    docker-compose logs --tail=10 $service
    
    # Port information
    echo -e "\nPort Mappings:"
    docker-compose port $service 2>/dev/null || echo "No exposed ports"
}

# Function to show overall system health
show_system_health() {
    print_colored $BLUE "\n=========================================="
    print_colored $BLUE "CI/CD Stack Health Check"
    print_colored $BLUE "=========================================="
    
    # Service health checks
    services=("postgresql" "elasticsearch" "logstash" "kibana" "sonarqube" "tomcat" "gitlab")
    healthy_count=0
    total_count=${#services[@]}
    
    for service in "${services[@]}"; do
        if check_service_health $service; then
            ((healthy_count++))
        fi
    done
    
    print_colored $BLUE "\n=========================================="
    print_colored $BLUE "Health Summary: $healthy_count/$total_count services healthy"
    print_colored $BLUE "=========================================="
    
    # System resources
    echo -e "\nSystem Resource Usage:"
    echo "======================"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    
    # Disk usage
    echo -e "\nDocker Disk Usage:"
    echo "=================="
    docker system df
    
    # Network information
    echo -e "\nDocker Networks:"
    echo "================"
    docker network ls | grep -E "(NETWORK|cicd)"
}

# Function to run connectivity tests
test_connectivity() {
    print_colored $BLUE "\n=========================================="
    print_colored $BLUE "Connectivity Tests"
    print_colored $BLUE "=========================================="
    
    # Test service endpoints
    services_endpoints=(
        "elasticsearch:9200:/_cluster/health"
        "kibana:5061:/api/status" 
        "sonarqube:9000:/api/system/status"
        "tomcat:8080:/"
        "gitlab:8083:/-/health"
    )
    
    for endpoint in "${services_endpoints[@]}"; do
        IFS=':' read -r service port path <<< "$endpoint"
        
        if docker-compose ps $service | grep -q "Up"; then
            if curl -s -f "http://localhost:$port$path" > /dev/null; then
                print_colored $GREEN "✓ $service ($port$path): Accessible"
            else
                print_colored $RED "✗ $service ($port$path): Not accessible"
            fi
        else
            print_colored $YELLOW "⚠ $service: Not running"
        fi
    done
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
            # No arguments - show overall status
            show_system_health
            show_access_info
            ;;
        "test")
            # Run connectivity tests
            test_connectivity
            ;;
        "health")
            # Show health check only
            show_system_health
            ;;
        "urls")
            # Show access URLs only
            show_access_info
            ;;
        *)
            # Show specific service details
            if docker-compose ps --services | grep -q "^$1$"; then
                show_service_details $1
            else
                print_colored $RED "ERROR: Service '$1' not found."
                echo "Available services: postgresql, elasticsearch, logstash, kibana, sonarqube, tomcat, gitlab"
                exit 1
            fi
            ;;
    esac
}

# Display usage if help requested
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [service-name|test|health|urls]"
    echo ""
    echo "Options:"
    echo "  (no args)     Show overall system health and access info"
    echo "  service-name  Show detailed information for specific service"
    echo "  test          Run connectivity tests for all services"
    echo "  health        Show health status only"
    echo "  urls          Show access URLs and credentials only"
    echo ""
    echo "Available services: postgresql, elasticsearch, logstash, kibana, sonarqube, tomcat, gitlab"
    exit 0
fi

# Run main function
main "$@"