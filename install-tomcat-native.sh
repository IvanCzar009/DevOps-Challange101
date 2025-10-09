#!/bin/bash
set -e

echo "=== Installing Tomcat (Native from tar.gz) ==="
echo "Starting at: $(date)"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a service is responding
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=${3:-30}
    local attempt=0
    
    log "Waiting for $service_name to be ready at $url..."
    while [ $attempt -lt $max_attempts ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "404" || "$HTTP_CODE" == "302" ]]; then
            log "$service_name is ready! (HTTP $HTTP_CODE)"
            return 0
        fi
        attempt=$((attempt + 1))
        log "Attempt $attempt/$max_attempts - $service_name not ready yet... (HTTP $HTTP_CODE)"
        sleep 5
    done
    log "ERROR: $service_name failed to start after $max_attempts attempts"
    return 1
}

# Install Java if not present
if ! command -v java &> /dev/null; then
    log "Installing Java 11..."
    sudo yum install -y java-11-amazon-corretto java-11-amazon-corretto-devel
    log "✅ Java installed"
else
    log "✅ Java already installed"
fi

# Set JAVA_HOME
export JAVA_HOME="/usr/lib/jvm/java-11-amazon-corretto"
log "✅ JAVA_HOME set to $JAVA_HOME"

# Define Tomcat variables
TOMCAT_VERSION="10.1.15"
TOMCAT_DIR="/home/ec2-user/apache-tomcat-$TOMCAT_VERSION"
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"

# Download Tomcat if not already present
cd /home/ec2-user
if [ ! -f "apache-tomcat-$TOMCAT_VERSION.tar.gz" ]; then
    log "Downloading Tomcat $TOMCAT_VERSION..."
    wget "$TOMCAT_URL"
    log "✅ Tomcat downloaded"
else
    log "✅ Tomcat tar.gz already exists"
fi

# Extract Tomcat if not already extracted
if [ ! -d "$TOMCAT_DIR" ]; then
    log "Extracting Tomcat..."
    tar -xzf "apache-tomcat-$TOMCAT_VERSION.tar.gz"
    log "✅ Tomcat extracted"
else
    log "✅ Tomcat already extracted"
fi

# Make scripts executable
chmod +x "$TOMCAT_DIR/bin/"*.sh
log "✅ Tomcat scripts made executable"

# Create users configuration for manager access
log "Creating Tomcat users configuration..."
cat > "$TOMCAT_DIR/conf/tomcat-users.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>
  <user username="admin" password="admin123" roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>
  <user username="deployer" password="deployer123" roles="manager-script"/>
</tomcat-users>
EOF

# Update manager context to allow remote access
log "Configuring Tomcat manager for remote access..."
mkdir -p "$TOMCAT_DIR/webapps/manager/META-INF"
cat > "$TOMCAT_DIR/webapps/manager/META-INF/context.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!-- Remove the valve that restricts access to localhost -->
  <!-- 
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.0\.0\.1|::1|0:0:0:0:0:0:0:1" />
  -->
</Context>
EOF

# Start Tomcat
log "Starting native Tomcat..."
export JAVA_HOME="$JAVA_HOME"
cd "$TOMCAT_DIR"
./bin/startup.sh

# Wait for Tomcat to be ready
log "Waiting for Tomcat to initialize..."
sleep 20

wait_for_service "http://localhost:8080" "Tomcat" 30

# Verify Tomcat is serving content
log "Verifying Tomcat is serving content..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|404\|302"; then
    log "✅ Tomcat is serving content successfully!"
else
    log "⚠️ Tomcat may still be starting up..."
fi

# Display final status
log "Checking Tomcat final status..."
if ps aux | grep java | grep tomcat > /dev/null; then
    log "✅ Tomcat process is running"
else
    log "⚠️ Tomcat process not found"
fi

echo ""
echo "=== Tomcat Installation Complete ==="
echo "Tomcat: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):8080"
echo "Manager App: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'localhost'):8080/manager"
echo "Admin credentials: admin / admin123"
echo "Deployer credentials: deployer / deployer123"
echo ""
echo "Installation directory: $TOMCAT_DIR"
echo "Logs directory: $TOMCAT_DIR/logs"
echo "Webapps directory: $TOMCAT_DIR/webapps"
echo ""
echo "Management commands:"
echo "  Start: $TOMCAT_DIR/bin/startup.sh"
echo "  Stop: $TOMCAT_DIR/bin/shutdown.sh"
echo "  Logs: tail -f $TOMCAT_DIR/logs/catalina.out"
echo ""

log "✅ Native Tomcat installation completed successfully"