#!/bin/bash
set -e

echo "=== Installing ELK Stack ==="
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
        sleep 10
    done
    log "ERROR: $service_name failed to start after $max_attempts attempts"
    return 1
}

# Wait for Docker to be ready
log "Checking Docker availability..."
attempt=0
max_attempts=30
while [ $attempt -lt $max_attempts ]; do
    if docker info >/dev/null 2>&1; then
        log "Docker is ready!"
        break
    fi
    attempt=$((attempt + 1))
    log "Attempt $attempt/$max_attempts - Docker not ready, waiting..."
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    log "ERROR: Docker failed to start after $max_attempts attempts"
    exit 1
fi

# Create ELK directory
mkdir -p /home/ec2-user/elk-stack
cd /home/ec2-user/elk-stack

# Create ELK configuration directory
mkdir -p elk-config

# Create Logstash configuration
cat > elk-config/logstash.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  if [fields][service] == "gitlab" {
    mutate { add_tag => [ "gitlab" ] }
  }
  if [fields][service] == "sonarqube" {
    mutate { add_tag => [ "sonarqube" ] }
  }
  if [fields][service] == "tomcat" {
    mutate { add_tag => [ "tomcat" ] }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

# Create Logstash config file
cat > elk-config/logstash.yml << 'EOF'
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://elasticsearch:9200" ]
path.config: /usr/share/logstash/pipeline
path.logs: /usr/share/logstash/logs
EOF

# Create ELK docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.4
    container_name: elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=docker-cluster
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - elk_network
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s

  logstash:
    image: docker.elastic.co/logstash/logstash:8.10.4
    container_name: logstash
    volumes:
      - ./elk-config/logstash.conf:/usr/share/logstash/pipeline/logstash.conf
      - ./elk-config/logstash.yml:/usr/share/logstash/config/logstash.yml
    ports:
      - "5044:5044"
      - "9600:9600"
    networks:
      - elk_network
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9600 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  kibana:
    image: docker.elastic.co/kibana/kibana:8.10.4
    container_name: kibana
    ports:
      - "5061:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    networks:
      - elk_network
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

volumes:
  elasticsearch_data:

networks:
  elk_network:
    driver: bridge
EOF

log "Starting ELK Stack..."
if ! docker-compose up -d; then
    log "ERROR: Failed to start ELK Stack"
    exit 1
fi

log "Waiting for services to initialize..."
sleep 30

# Wait for Elasticsearch to be ready
if ! wait_for_service "http://localhost:9200/_cluster/health" "Elasticsearch" 20; then
    log "ERROR: Elasticsearch failed to start"
    docker-compose logs elasticsearch
    exit 1
fi

# Wait for Kibana to be ready
if ! wait_for_service "http://localhost:5061/api/status" "Kibana" 15; then
    log "WARNING: Kibana might still be starting up. Check http://localhost:5061 in a few minutes"
fi

# Wait for Logstash to be ready
if ! wait_for_service "http://localhost:9600" "Logstash" 10; then
    log "ERROR: Logstash failed to start"
    docker-compose logs logstash
    exit 1
fi

# Check final status
log "Checking ELK Stack final status..."
docker-compose ps

echo ""
echo "=== ELK Stack Installation Complete ==="
echo "Elasticsearch: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9200"
echo "Kibana: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5061"
echo "Logstash: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9600"
echo ""