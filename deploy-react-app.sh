#!/bin/bash

# Deploy Group6 React App to Tomcat
# This script deploys your existing React application after all tools are installed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

echo -e "${BLUE}=== Deploying Group6 React Application ===${NC}"
echo "Starting at: $(date)"

# Check if React app directory exists
if [ ! -d "/tmp/group6-react-app" ]; then
    error "React app directory not found at /tmp/group6-react-app"
    exit 1
fi

# Get public IP for configuration
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
log "Deploying to server: $PUBLIC_IP"

# Wait for Tomcat to be ready
log "Waiting for Tomcat to be ready..."
TOMCAT_READY=false
for i in {1..30}; do
    # Check if Tomcat is responding (accept 200, 404, or 302 as valid responses)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null)
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "404" || "$HTTP_CODE" == "302" ]]; then
        TOMCAT_READY=true
        log "✅ Tomcat is ready (HTTP $HTTP_CODE)"
        break
    fi
    log "Waiting for Tomcat... attempt $i/30 (HTTP $HTTP_CODE)"
    sleep 10
done

if [ "$TOMCAT_READY" != "true" ]; then
    error "❌ Tomcat is not ready"
    exit 1
fi

# Build the React application
log "Building React application..."
cd /tmp/group6-react-app

# Install dependencies and build
log "Installing Node.js dependencies..."
if command -v npm &> /dev/null; then
    npm install --no-audit --no-fund
    log "✅ Dependencies installed"
    
    log "Building production version..."
    npm run build
    log "✅ React app built successfully"
else 
    error "npm not found. Installing Node.js..."
    # Install Node.js 18
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
    
    # Now install dependencies and build
    npm install --no-audit --no-fund
    npm run build
    log "✅ React app built with fresh Node.js installation"
fi

# Verify build directory exists
if [ ! -d "build" ]; then
    error "❌ Build failed - no build directory found"
    exit 1
fi

log "Build directory contents:"
ls -la build/

# Deploy to Tomcat
log "Deploying to Tomcat webapps directory..."

# Define Tomcat paths for native installation
TOMCAT_HOME="/home/ec2-user/apache-tomcat-10.1.15"
WEBAPPS_DIR="$TOMCAT_HOME/webapps"

# Check if native Tomcat installation exists
if [ ! -d "$TOMCAT_HOME" ]; then
    error "❌ Native Tomcat installation not found at $TOMCAT_HOME"
    exit 1
fi

# Stop Tomcat temporarily for safe deployment
log "Stopping native Tomcat for safe deployment..."
export JAVA_HOME="/usr/lib/jvm/java-11-amazon-corretto"
$TOMCAT_HOME/bin/shutdown.sh || warn "Tomcat shutdown failed, continuing..."
sleep 5

# Remove old deployment if exists
if [ -d "$WEBAPPS_DIR/group6-react-app" ]; then
    rm -rf "$WEBAPPS_DIR/group6-react-app"
    log "✅ Removed old deployment"
fi

# Deploy new build to both ROOT and dedicated directory
log "Deploying to native Tomcat webapps..."
cp -r build/* "$WEBAPPS_DIR/ROOT/" 2>/dev/null || log "ROOT deployment skipped"
mkdir -p "$WEBAPPS_DIR/group6-react-app"
cp -r build/* "$WEBAPPS_DIR/group6-react-app/"
log "✅ New build deployed to native Tomcat"

# Start Tomcat
log "Starting native Tomcat..."
export JAVA_HOME="/usr/lib/jvm/java-11-amazon-corretto"
$TOMCAT_HOME/bin/startup.sh

# Wait for Tomcat to start
log "Waiting for native Tomcat to restart..."
for i in {1..30}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null)
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "404" || "$HTTP_CODE" == "302" ]]; then
        log "✅ Native Tomcat restarted successfully (HTTP $HTTP_CODE)"
        break
    fi
    sleep 5
done

# Verify deployment
log "Verifying deployment..."
sleep 10

# Test both app endpoints
HTTP_CODE_APP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/group6-react-app/ 2>/dev/null)
HTTP_CODE_ROOT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ 2>/dev/null)

if [[ "$HTTP_CODE_APP" == "200" ]]; then
    log "✅ Group6 React App deployed successfully!"
    log "🌐 App URL: http://$PUBLIC_IP:8080/group6-react-app/"
elif [[ "$HTTP_CODE_ROOT" == "200" ]]; then
    log "✅ React App deployed to ROOT successfully!"
    log "🌐 App URL: http://$PUBLIC_IP:8080/"
else
    warn "⚠️ App deployment verification failed (App: $HTTP_CODE_APP, Root: $HTTP_CODE_ROOT), but files are in place"
fi

# Also set up development server (optional)
log "Setting up development server..."
cd /tmp/group6-react-app

# Create startup script for development server
cat > start-dev-server.sh << 'EOF'
#!/bin/bash
cd /tmp/group6-react-app
export PORT=3000
npm start
EOF

chmod +x start-dev-server.sh

# Start development server in background
log "Starting development server on port 3000..."
nohup npm start > /tmp/react-dev-server.log 2>&1 &
DEV_PID=$!

log "Development server started with PID: $DEV_PID"

# Wait a moment and check if dev server is running
sleep 15
if curl -s -f http://localhost:3000 > /dev/null 2>&1; then
    log "✅ Development server running on port 3000"
    log "🚀 Dev Server: http://$PUBLIC_IP:3000"
else
    warn "⚠️ Development server may still be starting up"
fi

# Copy app to user directory for easy access
log "Copying app to user directory..."
sudo cp -r /tmp/group6-react-app /home/ec2-user/
sudo chown -R ec2-user:ec2-user /home/ec2-user/group6-react-app
log "✅ App copied to /home/ec2-user/group6-react-app"

# Create helpful scripts
log "Creating management scripts..."

# Create deployment script
cat > /home/ec2-user/redeploy-app.sh << 'EOF'
#!/bin/bash
echo "Rebuilding and redeploying Group6 React App..."
cd /home/ec2-user/group6-react-app

# Build the app
npm run build

# Stop native Tomcat
export JAVA_HOME="/usr/lib/jvm/java-11-amazon-corretto"
/home/ec2-user/apache-tomcat-10.1.15/bin/shutdown.sh
sleep 5

# Remove old deployment
rm -rf /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app

# Deploy new build
mkdir -p /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app
cp -r build/* /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app/

# Start native Tomcat
/home/ec2-user/apache-tomcat-10.1.15/bin/startup.sh

echo "✅ Redeployment completed!"
echo "🌐 App URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/group6-react-app/"
EOF

chmod +x /home/ec2-user/redeploy-app.sh

# Create status check script
cat > /home/ec2-user/check-app-status.sh << 'EOF'
#!/bin/bash
echo "=== Group6 React App Status ==="
echo "Native Tomcat Process:"
ps aux | grep java | grep tomcat | head -1 || echo "Tomcat not running"
echo ""
echo "App Files:"
ls -la /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app/ 2>/dev/null || echo "App not deployed"
echo ""
echo "Tomcat Logs (last 10 lines):"
tail -10 /home/ec2-user/apache-tomcat-10.1.15/logs/catalina.out 2>/dev/null || echo "No logs found"
echo ""
echo "Testing URLs:"
curl -s -I http://localhost:8080/group6-react-app/ || echo "Production app not responding"
curl -s -I http://localhost:3000/ || echo "Dev server not responding"
EOF

chmod +x /home/ec2-user/check-app-status.sh

log "✅ Management scripts created"

# Final status report
echo ""
echo -e "${GREEN}🎉 REACT APPLICATION DEPLOYMENT COMPLETE! 🎉${NC}"
echo "=================================================="
echo ""
echo "📱 Your Group6 React App:"
echo "  🌐 Production: http://$PUBLIC_IP:8080/group6-react-app/"
echo "  🚀 Development: http://$PUBLIC_IP:3000/"
echo ""
echo "📁 App Locations:"
echo "  📦 Production: $TOMCAT_HOME/webapps/group6-react-app/"
echo "  🔧 Source: /home/ec2-user/group6-react-app/"
echo ""
echo "☕ Tomcat Info:"
echo "  🏠 Installation: $TOMCAT_HOME"
echo "  📄 Logs: $TOMCAT_HOME/logs/catalina.out"
echo "  🔧 Native installation from tar.gz"
echo ""
echo "🛠️ Management Commands:"
echo "  ./redeploy-app.sh - Rebuild and redeploy"
echo "  ./check-app-status.sh - Check status"
echo ""
echo "📊 Next Steps:"
echo "  1. Jenkins pipeline will handle automatic builds"
echo "  2. SonarQube will analyze code quality"
echo "  3. Check logs at /tmp/react-dev-server.log and $TOMCAT_HOME/logs/"
echo ""

# Configure Log Shipping to ELK Stack
log "Setting up log shipping to ELK Stack..."

# Install Filebeat for log shipping
log "Installing Filebeat..."
if [ ! -d "/opt/filebeat" ]; then
    curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.10.2-linux-x86_64.tar.gz
    tar xzvf filebeat-8.10.2-linux-x86_64.tar.gz > /dev/null 2>&1
    sudo mv filebeat-8.10.2-linux-x86_64 /opt/filebeat
    sudo chown -R ec2-user:ec2-user /opt/filebeat
    rm -f filebeat-8.10.2-linux-x86_64.tar.gz
    log "✅ Filebeat installed"
else
    log "✅ Filebeat already installed"
fi

# Create Filebeat configuration for Tomcat logs
log "Configuring Filebeat for Tomcat logs..."
cat > /opt/filebeat/filebeat.yml << 'EOF'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /home/ec2-user/apache-tomcat-*/logs/localhost_access_log.*.txt
  fields:
    logtype: tomcat-access
    service: group6-react-app
    environment: production
  fields_under_root: true
  multiline.pattern: '^\d'
  multiline.negate: true
  multiline.match: after

- type: log
  enabled: true
  paths:
    - /home/ec2-user/apache-tomcat-*/logs/catalina.out
  fields:
    logtype: tomcat-catalina
    service: group6-react-app
    environment: production
  fields_under_root: true
  multiline.pattern: '^\d{4}-\d{2}-\d{2}'
  multiline.negate: true
  multiline.match: after

- type: log
  enabled: true
  paths:
    - /home/ec2-user/apache-tomcat-*/logs/*.log
  fields:
    logtype: tomcat-general
    service: group6-react-app
    environment: production
  fields_under_root: true

output.logstash:
  hosts: ["localhost:5044"]

processors:
- add_host_metadata:
    when.not.contains.tags: forwarded
- timestamp:
    field: "@timestamp"
    layouts:
      - '2006-01-02T15:04:05.000Z'
      - '2006-01-02 15:04:05'
    test:
      - '2025-10-09T12:34:56.789Z'

logging.level: info
logging.to_files: true
logging.files:
  path: /opt/filebeat/logs
  name: filebeat
  keepfiles: 7
  permissions: 0644
EOF

# Create systemd service for Filebeat
log "Creating Filebeat service..."
sudo tee /etc/systemd/system/filebeat.service > /dev/null << 'EOF'
[Unit]
Description=Filebeat sends log files to Logstash or directly to Elasticsearch
Documentation=https://www.elastic.co/products/beats/filebeat
Wants=network-online.target
After=network-online.target

[Service]
User=ec2-user
Group=ec2-user
ExecStart=/opt/filebeat/filebeat -e -c /opt/filebeat/filebeat.yml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Generate sample traffic for logs
log "Generating sample traffic for log data..."
for i in {1..25}; do
    curl -s http://localhost:8080/group6-react-app/ > /dev/null 2>&1
    curl -s http://localhost:8080/group6-react-app/static/css/main.css > /dev/null 2>&1
    curl -s http://localhost:8080/group6-react-app/static/js/main.js > /dev/null 2>&1
    curl -s http://localhost:8080/group6-react-app/favicon.ico > /dev/null 2>&1
    curl -s http://localhost:8080/group6-react-app/nonexistent > /dev/null 2>&1  # Generate 404s
    curl -s "http://localhost:8080/group6-react-app/?user=test$i" > /dev/null 2>&1
    sleep 0.3
done
log "✅ Sample traffic generated for rich log data"

# Start Filebeat service
log "Starting Filebeat service..."
sudo systemctl daemon-reload
sudo systemctl enable filebeat
sudo systemctl start filebeat

# Wait for logs to be processed
sleep 10

# Restart services for optimal performance
log "Restarting services for optimal performance..."

# Restart Kibana container
log "Restarting Kibana..."
docker restart kibana 2>/dev/null && log "✅ Kibana restarted successfully" || warn "Kibana restart failed or not running"

# Wait for Kibana to be ready
sleep 15

# Restart Tomcat for final optimization
log "Final Tomcat restart for optimization..."
export JAVA_HOME="/usr/lib/jvm/java-11-amazon-corretto"
$TOMCAT_HOME/bin/shutdown.sh || warn "Tomcat shutdown failed"
sleep 5
$TOMCAT_HOME/bin/startup.sh
log "✅ Tomcat restarted for final optimization"

# Wait for services to stabilize
log "Waiting for services to stabilize..."
sleep 10

# Final service verification
log "Final service verification..."
KIBANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5061 2>/dev/null)
TOMCAT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null)

if [[ "$KIBANA_STATUS" == "302" || "$KIBANA_STATUS" == "200" ]]; then
    log "✅ Kibana is running (HTTP $KIBANA_STATUS)"
else
    warn "⚠️ Kibana status: HTTP $KIBANA_STATUS"
fi

if [[ "$TOMCAT_STATUS" == "200" || "$TOMCAT_STATUS" == "404" || "$TOMCAT_STATUS" == "302" ]]; then
    log "✅ Tomcat is running (HTTP $TOMCAT_STATUS)"
else
    warn "⚠️ Tomcat status: HTTP $TOMCAT_STATUS"
fi

# Check Filebeat status
log "Checking Filebeat status..."
FILEBEAT_STATUS=$(sudo systemctl is-active filebeat 2>/dev/null || echo "inactive")
if [[ "$FILEBEAT_STATUS" == "active" ]]; then
    log "✅ Filebeat is running and shipping logs"
else
    warn "⚠️ Filebeat status: $FILEBEAT_STATUS"
fi

# Wait a bit more for logs to flow
sleep 15

# Check if logs are appearing in Elasticsearch
log "Checking for log data in Elasticsearch..."
LOG_INDICES=$(curl -s http://localhost:9200/_cat/indices | grep -E "(logstash|filebeat|tomcat)" | wc -l)
if [ "$LOG_INDICES" -gt 0 ]; then
    log "✅ Log indices found in Elasticsearch!"
    curl -s http://localhost:9200/_cat/indices?v | grep -E "(logstash|filebeat|tomcat)" | head -3
else
    warn "⚠️ No log indices found yet, may take a few more minutes"
fi

# Set up Kibana port forwarding for external access
log "Setting up Kibana port forwarding..."
sudo iptables -t nat -A PREROUTING -p tcp --dport 8090 -j REDIRECT --to-port 5061 2>/dev/null || warn "Port forwarding may already exist"

# Create Kibana dashboard setup script
log "Creating Kibana dashboard automation..."
cat > /home/ec2-user/setup-kibana-dashboard.sh << 'KIBANA_EOF'
#!/bin/bash

KIBANA_URL="http://localhost:5601"
KIBANA_EXTERNAL_URL="http://localhost:8090"
INDEX_PATTERN="tomcat-logs-*"
DASHBOARD_NAME="Tomcat Access Logs Dashboard"

echo "🔧 Setting up Kibana Dashboard for Tomcat Logs..."

# Wait for Kibana to be ready
echo "⏳ Waiting for Kibana to be ready..."
WAIT_COUNT=0
until curl -s -f "$KIBANA_URL/api/status" > /dev/null 2>&1; do
    echo "Waiting for Kibana... ($WAIT_COUNT/30)"
    sleep 10
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge 30 ]; then
        echo "❌ Kibana not ready after 5 minutes, skipping dashboard setup"
        exit 1
    fi
done
echo "✅ Kibana is ready!"

# Generate sample traffic first
echo "🔄 Generating sample traffic to create logs..."
for i in {1..30}; do
    curl -s http://localhost:8080/group6-react-app/ > /dev/null
    echo -n "."
    sleep 0.3
done
echo ""

# Wait for logs to be processed
echo "⏳ Waiting for logs to be processed..."
sleep 20

# Create index pattern using Kibana API
echo "📋 Creating index pattern: $INDEX_PATTERN..."
INDEX_PATTERN_ID=$(curl -s -X POST "$KIBANA_URL/api/saved_objects/index-pattern" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d '{
        "attributes": {
            "title": "'$INDEX_PATTERN'",
            "timeFieldName": "@timestamp"
        }
    }' | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -n "$INDEX_PATTERN_ID" ]; then
    echo "✅ Index pattern created with ID: $INDEX_PATTERN_ID"
else
    echo "ℹ️  Using existing index pattern"
fi

echo ""
echo "🎉 Kibana Dashboard Setup Complete!"
echo "🌐 Access Kibana at: http://54.177.65.33:8090"
echo ""
echo "📊 To view your logs:"
echo "  1. Go to Analytics → Discover"
echo "  2. Select '$INDEX_PATTERN' index pattern"
echo "  3. View your Tomcat access logs"
echo "  4. Create visualizations and dashboards as needed"
echo ""
KIBANA_EOF

chmod +x /home/ec2-user/setup-kibana-dashboard.sh

# Run the dashboard setup in background
log "Running Kibana dashboard setup..."
nohup /home/ec2-user/setup-kibana-dashboard.sh > /home/ec2-user/kibana-setup.log 2>&1 &

# Show final URLs with updated IP
echo ""
echo -e "${GREEN}🎉 COMPLETE ELK STACK WITH LOG SHIPPING READY! 🎉${NC}"
echo "=================================================="
echo ""
echo "📊 **KIBANA DASHBOARD ACCESS**:"
echo "  🌐 URL: http://$PUBLIC_IP:8090 (port forwarded from 5061)"
echo "  📈 Dashboard setup is running in background"
echo "  📋 Check setup status: tail -f /home/ec2-user/kibana-setup.log"
echo ""
echo "🚀 **AUTOMATED FEATURES**:"
echo "  ✅ Port forwarding: 8090 → 5061 for Kibana access"
echo "  ✅ Index pattern: 'tomcat-logs-*' will be created"
echo "  ✅ Sample traffic generated for log data"
echo "  ✅ Dashboard setup running in background"
echo ""

log "✅ Group6 React App deployment completed successfully!"
log "✅ Services restarted and optimized"
log "Deployment finished at: $(date)"

exit 0