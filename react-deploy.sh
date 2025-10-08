#!/bin/bash

# React App Build and Deployment Script
# This script builds a React app and deploys it to Tomcat as a WAR file

set -e

# Configuration
REACT_APP_DIR="/home/ec2-user/group6-react-app"
BUILD_DIR="/home/ec2-user/group6-react-app/build"
TOMCAT_WEBAPPS="/home/ec2-user/tomcat-webapps"
WAR_NAME="group6-react-app.war"
LOG_FILE="/var/log/react-deploy.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to check if Node.js is available
check_nodejs() {
    if ! command -v node &> /dev/null; then
        log_message "ERROR: Node.js is not installed"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_message "ERROR: npm is not installed"
        exit 1
    fi
    
    log_message "Node.js version: $(node --version)"
    log_message "npm version: $(npm --version)"
}

# Function to install dependencies
install_dependencies() {
    log_message "Installing React app dependencies..."
    cd $REACT_APP_DIR
    
    if [ -f "package.json" ]; then
        npm install
        log_message "Dependencies installed successfully"
    else
        log_message "ERROR: package.json not found in $REACT_APP_DIR"
        exit 1
    fi
}

# Function to build React app
build_react_app() {
    log_message "Building React application..."
    cd $REACT_APP_DIR
    
    # Set production environment
    export NODE_ENV=production
    
    # Build the app
    npm run build
    
    if [ -d "$BUILD_DIR" ]; then
        log_message "React app built successfully"
        log_message "Build directory size: $(du -sh $BUILD_DIR)"
    else
        log_message "ERROR: Build failed - build directory not found"
        exit 1
    fi
}

# Function to create WAR file from React build
create_war_file() {
    log_message "Creating WAR file from React build..."
    
    # Create temporary directory for WAR structure
    local temp_dir="/tmp/react-war-$(date +%s)"
    mkdir -p $temp_dir
    
    # Copy build files to temporary directory
    cp -r $BUILD_DIR/* $temp_dir/
    
    # Create WEB-INF directory and web.xml for Tomcat
    mkdir -p $temp_dir/WEB-INF
    cat > $temp_dir/WEB-INF/web.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
         http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">
    
    <display-name>React Application</display-name>
    <description>React.js Application deployed on Tomcat</description>
    
    <!-- Default servlet mapping for static content -->
    <servlet-mapping>
        <servlet-name>default</servlet-name>
        <url-pattern>/static/*</url-pattern>
    </servlet-mapping>
    
    <!-- Welcome file list -->
    <welcome-file-list>
        <welcome-file>index.html</welcome-file>
    </welcome-file-list>
    
    <!-- Error pages -->
    <error-page>
        <error-code>404</error-code>
        <location>/index.html</location>
    </error-page>
    
    <!-- Security constraints (optional) -->
    <security-constraint>
        <web-resource-collection>
            <web-resource-name>React App</web-resource-name>
            <url-pattern>/*</url-pattern>
        </web-resource-collection>
    </security-constraint>
    
</web-app>
EOF

    # Create META-INF directory and MANIFEST.MF
    mkdir -p $temp_dir/META-INF
    cat > $temp_dir/META-INF/MANIFEST.MF << EOF
Manifest-Version: 1.0
Created-By: React Deploy Script
Implementation-Title: React Application
Implementation-Version: 1.0.0
Implementation-Vendor: Your Company
Built-Date: $(date)
EOF

    # Create the WAR file
    cd $temp_dir
    zip -r $WAR_NAME ./*
    
    # Move WAR file to webapps directory
    mkdir -p $TOMCAT_WEBAPPS
    mv $WAR_NAME $TOMCAT_WEBAPPS/
    
    # Cleanup
    rm -rf $temp_dir
    
    log_message "WAR file created: $TOMCAT_WEBAPPS/$WAR_NAME"
    log_message "WAR file size: $(du -sh $TOMCAT_WEBAPPS/$WAR_NAME)"
}

# Function to wait for Tomcat to be ready
wait_for_tomcat() {
    log_message "Waiting for Tomcat to be ready..."
    local timeout=300
    local counter=0
    
    while [ $counter -lt $timeout ]; do
        if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
            log_message "Tomcat is ready!"
            return 0
        fi
        sleep 5
        counter=$((counter + 5))
        echo -n "."
    done
    
    log_message "WARNING: Tomcat readiness check timed out"
    return 1
}

# Function to deploy to Tomcat via Manager
deploy_to_tomcat() {
    log_message "Deploying React app to Tomcat..."
    
    # Wait for Tomcat to be ready
    wait_for_tomcat
    
    # Copy WAR file to Tomcat webapps directory (hot deployment)
    docker cp $TOMCAT_WEBAPPS/$WAR_NAME tomcat:/usr/local/tomcat/webapps/
    
    log_message "WAR file deployed to Tomcat container"
    
    # Wait a bit for deployment
    sleep 10
    
    # Check if deployment was successful
    if curl -s -f http://localhost:8080/group6-react-app/ > /dev/null 2>&1; then
        log_message "✅ React app deployed successfully!"
        log_message "Access your app at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/group6-react-app/"
    else
        log_message "⚠️  Deployment completed but app may still be initializing"
        log_message "Check Tomcat logs: docker-compose logs tomcat"
    fi
}

# Function to create nginx configuration for better React routing
create_nginx_config() {
    log_message "Creating nginx configuration for React routing..."
    
    # Create nginx config directory
    mkdir -p /home/ec2-user/nginx-config
    
    cat > /home/ec2-user/nginx-config/react-app.conf << 'EOF'
server {
    listen 3000;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;
    
    # Handle React Router (SPA routing)
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }
    
    # Cache static assets
    location /static/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
    
    log_message "Nginx configuration created for better React routing support"
}

# Function to create development server option
create_dev_server() {
    log_message "Setting up development server option..."
    
    cat > /home/ec2-user/start-react-dev.sh << 'EOF'
#!/bin/bash
# Start React development server
cd /home/ec2-user/group6-react-app
echo "Starting React development server on port 3000..."
echo "Access at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
npm start
EOF
    
    chmod +x /home/ec2-user/start-react-dev.sh
    log_message "Development server script created: start-react-dev.sh"
}

# Function to setup environment variables
setup_environment() {
    log_message "Setting up environment variables..."
    
    # Create .env file for React app
    cat > $REACT_APP_DIR/.env.production << 'EOF'
# Production environment variables for Group6 React app
GENERATE_SOURCEMAP=false
PUBLIC_URL=/group6-react-app
REACT_APP_API_URL=http://localhost:8080/api
REACT_APP_VERSION=1.0.0
REACT_APP_ENV=production
EOF

    log_message "Environment variables configured"
}

# Main deployment function
main() {
    log_message "Starting React app build and deployment process..."
    
    # Check if React app directory exists
    if [ ! -d "$REACT_APP_DIR" ]; then
        log_message "ERROR: React app directory not found: $REACT_APP_DIR"
        exit 1
    fi
    
    # Run all steps
    check_nodejs
    setup_environment
    install_dependencies
    build_react_app
    create_war_file
    deploy_to_tomcat
    create_nginx_config
    create_dev_server
    
    log_message "✅ React app deployment completed successfully!"
    
    # Display access information
    local public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    echo ""
    echo "=========================================="
    echo "Group6 React App Deployment Complete!"
    echo "=========================================="
    echo "Production (Tomcat): http://$public_ip:8080/group6-react-app/"
    echo "Development server:  ./start-react-dev.sh (port 3000)"
    echo "WAR file location:   $TOMCAT_WEBAPPS/$WAR_NAME"
    echo "Build artifacts:     $BUILD_DIR"
    echo "=========================================="
}

# Run main function
main "$@"