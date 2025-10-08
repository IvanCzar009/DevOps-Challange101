#!/bin/bash
set -e

echo "=== GitLab Post-Installation Verification and Configuration ==="
echo "Starting at: $(date)"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check GitLab container status
check_gitlab_container() {
    log "Checking GitLab container status..."
    if docker ps | grep -q "gitlab.*healthy"; then
        log "✓ GitLab container is running and healthy"
        return 0
    elif docker ps | grep -q "gitlab"; then
        log "⚠ GitLab container is running but not yet healthy"
        return 1
    else
        log "✗ GitLab container is not running"
        return 2
    fi
}

# Function to verify GitLab internal services
check_gitlab_services() {
    log "Checking GitLab internal services..."
    
    # Get service status
    local services_output
    if services_output=$(docker exec gitlab-gitlab-1 gitlab-ctl status 2>/dev/null); then
        log "GitLab services status:"
        echo "$services_output" | head -15
        
        # Check if key services are running
        if echo "$services_output" | grep -q "run: nginx" && echo "$services_output" | grep -q "run: puma"; then
            log "✓ Key GitLab services (nginx, puma) are running"
            return 0
        else
            log "⚠ Some key GitLab services may not be running"
            return 1
        fi
    else
        log "✗ Unable to check GitLab services"
        return 2
    fi
}

# Function to test GitLab web interface
test_gitlab_web() {
    log "Testing GitLab web interface..."
    
    local attempts=0
    local max_attempts=15
    
    while [ $attempts -lt $max_attempts ]; do
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081" 2>/dev/null || echo "000")
        
        case $response_code in
            200)
                log "✓ GitLab web interface is fully accessible (HTTP 200)"
                return 0
                ;;
            302)
                log "✓ GitLab web interface is responding with redirect (HTTP 302)"
                return 0
                ;;
            502|503)
                log "GitLab web interface returning $response_code - still starting up..."
                ;;
            000)
                log "GitLab web interface not yet responding..."
                ;;
            *)
                log "GitLab web interface returned HTTP $response_code"
                ;;
        esac
        
        attempts=$((attempts + 1))
        log "Web interface test $attempts/$max_attempts..."
        sleep 20
    done
    
    log "⚠ GitLab web interface verification timeout - may need more time"
    return 1
}

# Function to perform GitLab reconfigure if needed
gitlab_reconfigure_if_needed() {
    log "=== Checking if GitLab reconfigure is needed ==="
    
    # Check if GitLab services are properly configured
    if ! check_gitlab_services; then
        log "GitLab services need reconfiguration..."
        
        log "Running gitlab-ctl reconfigure..."
        if docker exec gitlab-gitlab-1 gitlab-ctl reconfigure; then
            log "✓ GitLab reconfigure completed"
            
            log "Restarting GitLab services..."
            docker exec gitlab-gitlab-1 gitlab-ctl restart
            
            log "Waiting for services to stabilize after reconfigure..."
            sleep 60
        else
            log "⚠ GitLab reconfigure had issues"
        fi
    else
        log "✓ GitLab services appear to be properly configured"
    fi
}

# Function to setup GitLab for external access
setup_gitlab_external_access() {
    log "=== Setting up GitLab for external access ==="
    
    # Get public IP
    local public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
    
    if [ "$public_ip" != "localhost" ]; then
        log "Configuring GitLab for external URL: http://$public_ip:8081"
        
        # Update GitLab configuration for external access
        docker exec gitlab-gitlab-1 bash -c "cat >> /etc/gitlab/gitlab.rb << EOF

# External URL configuration
external_url 'http://$public_ip:8081'

# Additional configuration for external access
gitlab_rails['gitlab_shell_ssh_port'] = 8022
nginx['listen_port'] = 80
nginx['listen_https'] = false

EOF"
        
        log "Reconfiguring GitLab with external URL..."
        docker exec gitlab-gitlab-1 gitlab-ctl reconfigure
        
        log "Restarting GitLab after external URL configuration..."
        docker exec gitlab-gitlab-1 gitlab-ctl restart
        
        log "Waiting for GitLab to restart with new configuration..."
        sleep 90
    fi
}

# Main verification flow
log "Starting GitLab verification process..."

# Step 1: Check container status
check_gitlab_container
container_status=$?

# Step 2: Check services if container is running
if [ $container_status -le 1 ]; then
    check_gitlab_services
    services_status=$?
    
    # Step 3: Reconfigure if needed
    if [ $services_status -ne 0 ]; then
        gitlab_reconfigure_if_needed
    fi
    
    # Step 4: Setup external access
    setup_gitlab_external_access
    
    # Step 5: Test web interface
    test_gitlab_web
    web_status=$?
    
    # Final status report
    log "=== GitLab Verification Summary ==="
    
    if [ $web_status -eq 0 ]; then
        log "✓ GitLab is fully operational and ready to use"
        echo ""
        echo "GitLab Access Information:"
        echo "  URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo localhost):8081"
        echo "  Default credentials: root / admin123456"
        echo ""
    else
        log "⚠ GitLab verification completed with warnings"
        log "GitLab may need additional time to fully initialize"
        echo ""
        echo "GitLab should be accessible at:"
        echo "  URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo localhost):8081"
        echo "  Default credentials: root / admin123456"
        echo ""
        echo "If not immediately accessible, please wait 5-10 minutes and try again"
    fi
else
    log "✗ GitLab container is not running properly"
    log "Please check GitLab installation and container logs"
    exit 1
fi

echo "=== GitLab Verification Complete ==="