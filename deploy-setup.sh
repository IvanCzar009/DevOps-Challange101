#!/bin/bash

# Comprehensive deployment script that creates all files and deploys the CI/CD stack
# This script runs on the EC2 instance to avoid SCP issues

set -e

echo "Starting comprehensive CI/CD deployment..."

# Wait for system to be fully ready
echo "Waiting for system initialization to complete..."
cloud-init status --wait || true
sleep 10

# Ensure we're in the right directory
cd /home/ec2-user

# Create Docker Compose file
echo "Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  cicd-network:
    driver: bridge

volumes:
  gitlab-config:
  gitlab-logs:
  gitlab-data:
  sonarqube-data:
  sonarqube-logs:
  sonarqube-extensions:
  postgresql-data:
  tomcat-webapps:
  tomcat-logs:

services:
  # PostgreSQL Database for SonarQube
  postgresql:
    image: postgres:13
    container_name: postgresql
    restart: unless-stopped
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar123
      POSTGRES_DB: sonarqube
    volumes:
      - postgresql-data:/var/lib/postgresql/data
    networks:
      - cicd-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar"]
      interval: 30s
      timeout: 10s
      retries: 5

  # GitLab CE
  gitlab:
    image: gitlab/gitlab-ce:16.5.1-ce.0
    container_name: gitlab
    restart: unless-stopped
    hostname: gitlab.local
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://gitlab.local:8083'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['time_zone'] = 'UTC'
        unicorn['worker_processes'] = 4
        sidekiq['max_concurrency'] = 25
        postgresql['max_connections'] = 200
        postgresql['shared_buffers'] = "512MB"
        postgresql['enable'] = true
        registry_external_url 'http://gitlab.local:5050'
        gitlab_rails['registry_enabled'] = true
        pages_external_url "http://pages.gitlab.local"
        gitlab_pages['enable'] = true
        prometheus_monitoring['enable'] = true
        grafana['enable'] = false
        gitlab_rails['backup_keep_time'] = 604800
        gitlab_rails['backup_path'] = '/var/opt/gitlab/backups'
    ports:
      - "8083:8083"
      - "2222:22"
      - "5050:5050"
    volumes:
      - gitlab-config:/etc/gitlab
      - gitlab-logs:/var/log/gitlab
      - gitlab-data:/var/opt/gitlab
    networks:
      - cicd-network
    shm_size: '256m'
    healthcheck:
      test: ["CMD", "/opt/gitlab/bin/gitlab-healthcheck", "--fail", "--max-time", "10"]
      interval: 60s
      timeout: 30s
      retries: 5
      start_period: 200s

  # SonarQube Community Edition
  sonarqube:
    image: sonarqube:10.2-community
    container_name: sonarqube
    restart: unless-stopped
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://postgresql:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar123
      SONAR_ES_BOOTSTRAP_CHECKS_DISABLE: true
    ports:
      - "9000:9000"
    volumes:
      - sonarqube-data:/opt/sonarqube/data
      - sonarqube-logs:/opt/sonarqube/logs
      - sonarqube-extensions:/opt/sonarqube/extensions
    networks:
      - cicd-network
    depends_on:
      postgresql:
        condition: service_healthy
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:9000/api/system/status"]
      interval: 30s
      timeout: 10s
      retries: 5

  # Apache Tomcat
  tomcat:
    image: tomcat:10.1-jdk11
    container_name: tomcat
    restart: unless-stopped
    environment:
      CATALINA_OPTS: "-Xms512m -Xmx1024m -server -XX:+UseParallelGC"
      JAVA_OPTS: "-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
    ports:
      - "8080:8080"
      - "8009:8009"
    volumes:
      - tomcat-webapps:/usr/local/tomcat/webapps
      - tomcat-logs:/usr/local/tomcat/logs
      - ./tomcat-config/server.xml:/usr/local/tomcat/conf/server.xml:ro
      - ./tomcat-config/tomcat-users.xml:/usr/local/tomcat/conf/tomcat-users.xml:ro
    networks:
      - cicd-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ELK Stack - Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.4
    container_name: elasticsearch
    restart: unless-stopped
    environment:
      - node.name=elasticsearch
      - cluster.name=cicd-elk-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - ELASTIC_PASSWORD=changeme123
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - ./elk-config/elasticsearch:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
      - "9300:9300"
    networks:
      - cicd-network
    healthcheck:
      test: ["CMD-SHELL", "curl -u elastic:changeme123 -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  # ELK Stack - Logstash
  logstash:
    image: docker.elastic.co/logstash/logstash:8.10.4
    container_name: logstash
    restart: unless-stopped
    environment:
      - "LS_JAVA_OPTS=-Xmx512m -Xms512m"
    volumes:
      - ./elk-config/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./elk-config/logstash/pipelines.yml:/usr/share/logstash/config/pipelines.yml:ro
      - ./elk-config/logstash/conf.d:/usr/share/logstash/pipeline:ro
    ports:
      - "5044:5044"
      - "9600:9600"
    networks:
      - cicd-network
    depends_on:
      elasticsearch:
        condition: service_healthy

  # ELK Stack - Kibana
  kibana:
    image: docker.elastic.co/kibana/kibana:8.10.4
    container_name: kibana
    restart: unless-stopped
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=5601
    ports:
      - "5601:5601"
    networks:
      - cicd-network
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
EOF

# Create ELK configuration directories and files
echo "Creating ELK configuration files..."
mkdir -p elk-config/logstash/conf.d
mkdir -p elk-config/elasticsearch

# Logstash configuration
cat > elk-config/logstash/logstash.yml << 'EOF'
http.host: "0.0.0.0"
path.config: /usr/share/logstash/pipeline
path.logs: /usr/share/logstash/logs
xpack.monitoring.enabled: true
xpack.monitoring.elasticsearch.hosts: ["http://elasticsearch:9200"]
xpack.monitoring.elasticsearch.username: "elastic"
xpack.monitoring.elasticsearch.password: "changeme123"
pipeline.workers: 2
pipeline.batch.size: 125
pipeline.batch.delay: 50
queue.type: memory
queue.max_bytes: 1gb
dead_letter_queue.enable: false
EOF

cat > elk-config/logstash/pipelines.yml << 'EOF'
- pipeline.id: main
  path.config: "/usr/share/logstash/pipeline/logstash.conf"
  pipeline.workers: 2
  pipeline.batch.size: 125
  queue.type: memory
EOF

cat > elk-config/logstash/conf.d/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  
  http {
    port => 8080
    codec => json
  }
  
  syslog {
    port => 514
    type => "syslog"
  }
  
  tcp {
    port => 5000
    codec => json_lines
    type => "docker"
  }
}

filter {
  mutate {
    add_field => { "received_at" => "%{@timestamp}" }
    add_field => { "received_from" => "%{host}" }
  }
  
  if [type] == "docker" {
    if [container_name] {
      mutate {
        add_tag => [ "docker", "%{container_name}" ]
      }
    }
  }
  
  if [container_name] == "gitlab" {
    mutate {
      add_tag => [ "gitlab" ]
      add_field => { "service" => "gitlab" }
    }
  }
  
  mutate {
    remove_field => [ "agent", "ecs", "input", "log" ]
  }
  
  mutate {
    add_field => { "environment" => "cicd" }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    user => "elastic"
    password => "changeme123"
    index => "cicd-%{service}-%{+YYYY.MM.dd}"
  }
  
  stdout {
    codec => rubydebug {
      metadata => false
    }
  }
}
EOF

# Create Tomcat configuration
echo "Creating Tomcat configuration..."
mkdir -p tomcat-config

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
               redirectPort="8443"
               maxThreads="200"
               minSpareThreads="10"
               maxSpareThreads="50"
               acceptCount="100"
               compression="on"
               compressionMinSize="2048"
               compressableMimeType="text/html,text/xml,text/javascript,text/css,text/plain,application/javascript,application/json"
               URIEncoding="UTF-8" />

    <Connector protocol="AJP/1.3"
               address="0.0.0.0"
               port="8009"
               redirectPort="8443"
               maxThreads="200" />

    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost" appBase="webapps"
            unpackWARs="true" autoDeploy="true">

        <Valve className="org.apache.catalina.valves.AccessLogValve" 
               directory="logs"
               prefix="localhost_access_log" 
               suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b %D &quot;%{Referer}i&quot; &quot;%{User-Agent}i&quot;"
               resolveHosts="false" />

        <Valve className="org.apache.catalina.valves.ErrorReportValve"
               showReport="false"
               showServerInfo="false" />

        <Valve className="org.apache.catalina.valves.RemoteIpValve"
               remoteIpHeader="X-Forwarded-For"
               protocolHeader="X-Forwarded-Proto" />

      </Host>
    </Engine>
  </Service>
</Server>
EOF

cat > tomcat-config/tomcat-users.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">

  <role rolename="tomcat"/>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>

  <user username="admin" 
        password="admin123" 
        roles="tomcat,manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>
  
  <user username="deployer" 
        password="deploy123" 
        roles="manager-script,manager-jmx"/>
  
  <user username="monitor" 
        password="monitor123" 
        roles="manager-status"/>

  <user username="tomcat" 
        password="tomcat123" 
        roles="tomcat"/>

</tomcat-users>
EOF

# Create management scripts
echo "Creating management scripts..."

cat > start-services.sh << 'EOF'
#!/bin/bash
echo "Starting CI/CD stack..."
cd /home/ec2-user
docker-compose up -d
echo "Services started. Use ./status.sh to check status."
EOF

cat > stop-services.sh << 'EOF'
#!/bin/bash
echo "Stopping CI/CD stack..."
cd /home/ec2-user
docker-compose down
echo "Services stopped."
EOF

cat > status.sh << 'EOF'
#!/bin/bash
echo "CI/CD Stack Status:"
cd /home/ec2-user
docker-compose ps
echo ""
echo "Docker Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
EOF

cat > logs.sh << 'EOF'
#!/bin/bash
cd /home/ec2-user
if [ -z "$1" ]; then
    echo "Usage: $0 [service-name]"
    echo "Available services: postgresql, elasticsearch, logstash, kibana, sonarqube, tomcat, gitlab"
    echo "Showing recent logs for all services..."
    docker-compose logs --tail=20
else
    docker-compose logs --tail=50 $1
fi
EOF

# Set permissions
chmod +x *.sh
chown -R ec2-user:ec2-user /home/ec2-user/

# Start Docker services
echo "Waiting for Docker to be ready..."
sleep 30

echo "Pulling Docker images..."
docker-compose pull

echo "Starting CI/CD stack..."
docker-compose up -d

echo "Waiting for services to initialize..."
sleep 60

echo "Checking service status..."
docker-compose ps

# Display final information
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "=========================================="
echo "CI/CD Stack Deployment Complete!"
echo "=========================================="
echo "Access your services at:"
echo "GitLab:      http://$PUBLIC_IP:8083"
echo "SonarQube:   http://$PUBLIC_IP:9000"
echo "Tomcat:      http://$PUBLIC_IP:8080"
echo "Kibana:      http://$PUBLIC_IP:5601"
echo "Elasticsearch: http://$PUBLIC_IP:9200"
echo ""
echo "Default Credentials:"
echo "- Elasticsearch: elastic / changeme123"
echo "- Tomcat Manager: admin / admin123"
echo "- SonarQube: admin / admin (change on first login)"
echo "- GitLab root: docker exec -it gitlab grep Password /etc/gitlab/initial_root_password"
echo ""
echo "Management Commands:"
echo "./start-services.sh - Start all services"
echo "./stop-services.sh  - Stop all services"
echo "./status.sh         - Check service status"
echo "./logs.sh [service] - View service logs"
echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="

# Create a marker file to indicate completion
echo "$(date): CI/CD stack deployment completed successfully" > /home/ec2-user/deployment-complete.txt

echo "Deployment script completed successfully!"