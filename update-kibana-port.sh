#!/bin/bash

# Script to update Kibana port from 5061 to 8443 on running instance
echo "🔧 Updating Kibana Port from 5061 to 8443"
echo "=========================================="

# Step 1: Stop current Kibana container
echo "1. Stopping current Kibana container..."
docker stop kibana
docker rm kibana

# Step 2: Update Docker container with new port
echo "2. Starting Kibana with new port 8443..."
docker run -d \
  --name kibana \
  --network elk \
  -p 8443:5601 \
  -e ELASTICSEARCH_HOSTS=http://elasticsearch:9200 \
  -e XPACK_SECURITY_ENABLED=false \
  -e XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab954b8c7831e \
  docker.elastic.co/kibana/kibana:8.10.4

# Step 3: Wait for Kibana to start
echo "3. Waiting for Kibana to start..."
sleep 30

# Step 4: Update port forwarding
echo "4. Updating port forwarding rules..."
# Remove old rule
sudo iptables -t nat -D PREROUTING -p tcp --dport 8090 -j REDIRECT --to-port 5061 2>/dev/null || echo "Old rule not found"
# Add new rule
sudo iptables -t nat -A PREROUTING -p tcp --dport 8090 -j REDIRECT --to-port 8443

# Step 5: Test new configuration
echo "5. Testing new Kibana configuration..."
sleep 10

KIBANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8443 2>/dev/null)
if [ "$KIBANA_STATUS" = "302" ] || [ "$KIBANA_STATUS" = "200" ]; then
    echo "✅ Kibana is responding on port 8443 (HTTP $KIBANA_STATUS)"
else
    echo "❌ Kibana not responding on port 8443 (HTTP $KIBANA_STATUS)"
fi

PORT_FORWARD_TEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090 2>/dev/null)
if [ "$PORT_FORWARD_TEST" = "302" ] || [ "$PORT_FORWARD_TEST" = "200" ]; then
    echo "✅ Port forwarding working: 8090 → 8443 (HTTP $PORT_FORWARD_TEST)"
else
    echo "❌ Port forwarding not working: 8090 → 8443 (HTTP $PORT_FORWARD_TEST)"
fi

# Step 6: Show final URLs
echo ""
echo "🎉 Update Complete!"
echo "=================="
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "New Kibana URLs:"
echo "  Direct: http://$PUBLIC_IP:8443"
echo "  Forwarded: http://$PUBLIC_IP:8090 (recommended)"
echo ""
echo "All other services remain unchanged:"
echo "  React App: http://$PUBLIC_IP:8080/group6-react-app/"
echo "  Jenkins: http://$PUBLIC_IP:8081"
echo "  SonarQube: http://$PUBLIC_IP:9000"
echo "  Elasticsearch: http://$PUBLIC_IP:9200"