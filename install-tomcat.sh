#!/bin/bash
set -e

echo "=== Installing Tomcat ==="
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
        if curl -s "$url" >/dev/null 2>&1; then
            log "$service_name is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        log "Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 5
    done
    log "ERROR: $service_name failed to start after $max_attempts attempts"
    return 1
}

# Create Tomcat directory
log "Creating Tomcat directory..."
mkdir -p /home/ec2-user/tomcat
cd /home/ec2-user/tomcat

# Create Tomcat configuration directory
mkdir -p tomcat-config

# Create Tomcat server.xml
cat > tomcat-config/server.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />

    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />
      </Host>
    </Engine>
  </Service>
</Server>
EOF

# Create Tomcat users configuration
cat > tomcat-config/tomcat-users.xml << 'EOF'
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

# Create Tomcat docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  tomcat:
    image: tomcat:10.1-jdk11
    container_name: tomcat
    ports:
      - "8080:8080"
    volumes:
      - tomcat_webapps:/usr/local/tomcat/webapps
      - ./tomcat-config/server.xml:/usr/local/tomcat/conf/server.xml
      - ./tomcat-config/tomcat-users.xml:/usr/local/tomcat/conf/tomcat-users.xml
    networks:
      - tomcat_network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

volumes:
  tomcat_webapps:

networks:
  tomcat_network:
    driver: bridge
EOF

log "Starting Tomcat..."
if ! docker-compose up -d; then
    log "ERROR: Failed to start Tomcat container"
    exit 1
fi

log "Waiting for Tomcat to initialize..."
sleep 20

# Wait for Tomcat to be ready
if ! wait_for_service "http://localhost:8080" "Tomcat" 12; then
    log "ERROR: Tomcat failed to start"
    docker-compose logs tomcat
    exit 1
fi

# Verify Tomcat is serving content
log "Verifying Tomcat is serving content..."
if curl -s http://localhost:8080 | grep -q "Apache Tomcat"; then
    log "Tomcat is serving content successfully!"
else
    log "WARNING: Tomcat is running but may not be serving content properly"
fi

# Check final status
log "Checking Tomcat final status..."
docker-compose ps

echo ""
echo "=== Tomcat Installation Complete ==="
echo "Tomcat: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Manager App: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/manager"
echo "Admin credentials: admin / admin123"
echo "Deployer credentials: deployer / deployer123"
echo ""