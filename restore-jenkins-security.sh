#!/bin/bash

echo "=== RESTORING JENKINS SECURITY ==="

echo "[1/2] Restoring original security configuration..."
sudo docker exec jenkins cp /var/jenkins_home/config.xml.backup /var/jenkins_home/config.xml

echo "[2/2] Restarting Jenkins..."
sudo docker restart jenkins
sleep 30

echo "Waiting for Jenkins to be available..."
for i in {1..10}; do
    if curl -f -s http://localhost:8081 > /dev/null; then
        echo "✅ Jenkins is running with security restored"
        break
    else
        echo "⏳ Waiting for Jenkins... ($i/10)"
        sleep 10
    fi
done

echo "
🔒 JENKINS SECURITY RESTORED

✅ Security settings have been restored
✅ Jenkins is accessible at: http://54.67.22.49:8081
✅ Login required: admin/admin123456

🎯 Your pipeline job should now be available and ready to use!
"