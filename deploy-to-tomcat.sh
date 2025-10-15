#!/bin/bash

# Automated Tomcat Deployment Script for CI/CD Pipeline
# This script handles deployment of React applications to Tomcat server

set -euo pipefail

# Configuration Variables
APP_NAME="${APP_NAME:-group6-react-app}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}"
TOMCAT_HOME="${TOMCAT_HOME:-/home/ec2-user/apache-tomcat-10.1.15}"
TOMCAT_WEBAPPS="${TOMCAT_HOME}/webapps"
TOMCAT_MANAGER_URL="${TOMCAT_MANAGER_URL:-http://localhost:8080/manager}"
DEPLOYMENT_USER="${DEPLOYMENT_USER:-admin}"
DEPLOYMENT_PASS="${DEPLOYMENT_PASS:-admin123}"

# Logging Functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ INFO: $1"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ SUCCESS: $1"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ WARNING: $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1"
}

# Health Check Function
check_tomcat_status() {
    local url="$1"
    local max_attempts=30
    local attempt=1
    
    log_info "Checking Tomcat status at $url"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" >/dev/null 2>&1; then
            log_success "Tomcat is responding"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: Waiting for Tomcat to respond..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Tomcat failed to respond after $max_attempts attempts"
    return 1
}

# Backup Function
backup_existing_deployment() {
    log_info "Creating backup of existing deployment"
    
    if [ -d "${TOMCAT_WEBAPPS}/${APP_NAME}" ]; then
        local backup_dir="${TOMCAT_WEBAPPS}/backups"
        mkdir -p "$backup_dir"
        
        local backup_name="${APP_NAME}_backup_$(date +%Y%m%d_%H%M%S)"
        mv "${TOMCAT_WEBAPPS}/${APP_NAME}" "${backup_dir}/${backup_name}"
        
        log_success "Backup created: ${backup_dir}/${backup_name}"
        
        # Keep only last 5 backups
        find "$backup_dir" -name "${APP_NAME}_backup_*" -type d | sort | head -n -5 | xargs rm -rf
    else
        log_info "No existing deployment found to backup"
    fi
}

# Deployment Function
deploy_application() {
    local build_artifact="$1"
    
    log_info "Starting deployment of $build_artifact"
    
    # Stop Tomcat gracefully
    log_info "Stopping Tomcat for deployment"
    "${TOMCAT_HOME}/bin/shutdown.sh" || log_warning "Tomcat shutdown command failed"
    
    # Wait for Tomcat to stop
    sleep 15
    
    # Kill any remaining Tomcat processes
    pkill -f "tomcat" || log_info "No Tomcat processes to kill"
    
    # Create backup
    backup_existing_deployment
    
    # Deploy new version
    log_info "Deploying new application version"
    
    if [[ "$build_artifact" == *.tar.gz ]]; then
        # Extract tar.gz directly to webapps
        mkdir -p "${TOMCAT_WEBAPPS}/${APP_NAME}"
        tar -xzf "$build_artifact" -C "${TOMCAT_WEBAPPS}/${APP_NAME}"
        log_success "Application extracted to ${TOMCAT_WEBAPPS}/${APP_NAME}"
    elif [[ "$build_artifact" == *.war ]]; then
        # Copy WAR file
        cp "$build_artifact" "${TOMCAT_WEBAPPS}/${APP_NAME}.war"
        log_success "WAR file deployed to ${TOMCAT_WEBAPPS}/${APP_NAME}.war"
    else
        # Assume it's a directory
        cp -r "$build_artifact" "${TOMCAT_WEBAPPS}/${APP_NAME}"
        log_success "Directory deployed to ${TOMCAT_WEBAPPS}/${APP_NAME}"
    fi
    
    # Set proper permissions
    chown -R ec2-user:ec2-user "${TOMCAT_WEBAPPS}/${APP_NAME}"
    chmod -R 755 "${TOMCAT_WEBAPPS}/${APP_NAME}"
    
    # Start Tomcat
    log_info "Starting Tomcat"
    "${TOMCAT_HOME}/bin/startup.sh"
    
    # Wait for startup
    check_tomcat_status "http://localhost:8080"
    
    # Verify deployment
    local app_url="http://localhost:8080/${APP_NAME}/"
    if check_tomcat_status "$app_url"; then
        log_success "Application deployed successfully and is accessible"
        return 0
    else
        log_error "Application deployment failed - not accessible"
        return 1
    fi
}

# Rollback Function
rollback_deployment() {
    log_info "Starting rollback procedure"
    
    local backup_dir="${TOMCAT_WEBAPPS}/backups"
    local latest_backup=$(find "$backup_dir" -name "${APP_NAME}_backup_*" -type d | sort | tail -n 1)
    
    if [ -n "$latest_backup" ]; then
        log_info "Rolling back to: $latest_backup"
        
        # Stop Tomcat
        "${TOMCAT_HOME}/bin/shutdown.sh" || log_warning "Tomcat shutdown failed"
        sleep 10
        
        # Remove current deployment
        rm -rf "${TOMCAT_WEBAPPS}/${APP_NAME}"
        
        # Restore backup
        mv "$latest_backup" "${TOMCAT_WEBAPPS}/${APP_NAME}"
        
        # Start Tomcat
        "${TOMCAT_HOME}/bin/startup.sh"
        
        check_tomcat_status "http://localhost:8080/${APP_NAME}/"
        log_success "Rollback completed successfully"
    else
        log_error "No backup found for rollback"
        return 1
    fi
}

# Performance Test Function
run_performance_test() {
    local app_url="http://localhost:8080/${APP_NAME}/"
    log_info "Running performance test on $app_url"
    
    local total_time=0
    local requests=10
    local failed_requests=0
    
    for i in $(seq 1 $requests); do
        local response_time=$(curl -s -w "%{time_total}" -o /dev/null "$app_url" 2>/dev/null || echo "999")
        
        if [ "$response_time" == "999" ]; then
            ((failed_requests++))
            log_warning "Request $i failed"
        else
            total_time=$(echo "$total_time + $response_time" | bc -l)
            log_info "Request $i: ${response_time}s"
        fi
    done
    
    local success_requests=$((requests - failed_requests))
    
    if [ $success_requests -gt 0 ]; then
        local avg_time=$(echo "scale=3; $total_time / $success_requests" | bc -l)
        log_success "Performance test completed: Average response time: ${avg_time}s, Success rate: $success_requests/$requests"
        
        # Send metrics to ELK
        curl -X POST "http://localhost:9200/cicd-pipeline-$(date +%Y.%m.%d)/_doc/" \
            -H 'Content-Type: application/json' \
            -d "{
                \"timestamp\": \"$(date -Iseconds)\",
                \"pipeline\": \"${APP_NAME}\",
                \"stage\": \"performance_test\",
                \"avg_response_time\": $avg_time,
                \"success_rate\": $(echo "scale=2; $success_requests * 100 / $requests" | bc -l),
                \"total_requests\": $requests,
                \"failed_requests\": $failed_requests
            }" >/dev/null 2>&1 || log_warning "Failed to send metrics to ELK"
    else
        log_error "All performance test requests failed"
        return 1
    fi
}

# Smoke Test Function
run_smoke_tests() {
    local app_url="http://localhost:8080/${APP_NAME}/"
    log_info "Running smoke tests"
    
    # Test main page
    if curl -f -s "$app_url" >/dev/null; then
        log_success "✓ Main page accessible"
    else
        log_error "✗ Main page not accessible"
        return 1
    fi
    
    # Test static resources
    local static_resources=("static/css" "static/js")
    for resource in "${static_resources[@]}"; do
        if curl -f -s "${app_url}${resource}/" >/dev/null 2>&1; then
            log_success "✓ Static resource accessible: $resource"
        else
            log_warning "⚠ Static resource not accessible: $resource"
        fi
    done
    
    # Test API endpoints (if any)
    local api_endpoints=("api/health" "health")
    for endpoint in "${api_endpoints[@]}"; do
        if curl -f -s "${app_url}${endpoint}" >/dev/null 2>&1; then
            log_success "✓ API endpoint accessible: $endpoint"
        else
            log_info "ℹ API endpoint not found (expected): $endpoint"
        fi
    done
    
    log_success "Smoke tests completed"
}

# Main Function
main() {
    log_info "Starting Tomcat deployment script"
    log_info "App: $APP_NAME, Build: $BUILD_NUMBER"
    
    # Check if build artifact exists
    local build_artifact="${1:-}"
    if [ -z "$build_artifact" ]; then
        log_error "No build artifact specified"
        log_info "Usage: $0 <build_artifact_path> [action]"
        log_info "Actions: deploy (default), rollback, test"
        exit 1
    fi
    
    local action="${2:-deploy}"
    
    case "$action" in
        "deploy")
            if [ ! -f "$build_artifact" ] && [ ! -d "$build_artifact" ]; then
                log_error "Build artifact not found: $build_artifact"
                exit 1
            fi
            
            if deploy_application "$build_artifact"; then
                log_success "Deployment completed successfully"
                
                # Run smoke tests
                if run_smoke_tests; then
                    log_success "All smoke tests passed"
                else
                    log_warning "Some smoke tests failed, but deployment is live"
                fi
                
                # Run performance tests
                run_performance_test
                
                # Send deployment success to ELK
                curl -X POST "http://localhost:9200/cicd-pipeline-$(date +%Y.%m.%d)/_doc/" \
                    -H 'Content-Type: application/json' \
                    -d "{
                        \"timestamp\": \"$(date -Iseconds)\",
                        \"pipeline\": \"${APP_NAME}\",
                        \"stage\": \"deployment\",
                        \"status\": \"completed\",
                        \"build_number\": \"${BUILD_NUMBER}\",
                        \"deployment_url\": \"http://localhost:8080/${APP_NAME}/\"
                    }" >/dev/null 2>&1 || true
                
                log_success "🎉 Deployment pipeline completed successfully!"
                log_info "Application URL: http://localhost:8080/${APP_NAME}/"
            else
                log_error "Deployment failed, initiating rollback"
                rollback_deployment
                exit 1
            fi
            ;;
        "rollback")
            rollback_deployment
            ;;
        "test")
            run_smoke_tests
            run_performance_test
            ;;
        *)
            log_error "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi