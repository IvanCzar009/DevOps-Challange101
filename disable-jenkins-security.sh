#!/bin/bash

echo "=== TEMPORARILY DISABLING JENKINS SECURITY FOR JOB CREATION ==="

echo "[1/4] Backing up Jenkins config..."
sudo docker exec jenkins cp /var/jenkins_home/config.xml /var/jenkins_home/config.xml.backup

echo "[2/4] Temporarily disabling security..."
sudo docker exec jenkins sed -i 's/<useSecurity>true<\/useSecurity>/<useSecurity>false<\/useSecurity>/' /var/jenkins_home/config.xml

echo "[3/4] Restarting Jenkins..."
sudo docker restart jenkins
sleep 30

echo "[4/4] Waiting for Jenkins to be available..."
for i in {1..10}; do
    if curl -f -s http://localhost:8081 > /dev/null; then
        echo "✅ Jenkins is now accessible without authentication"
        break
    else
        echo "⏳ Waiting for Jenkins... ($i/10)"
        sleep 10
    fi
done

echo "
🎉 JENKINS SECURITY TEMPORARILY DISABLED

✅ You can now create jobs without authentication
✅ Access Jenkins at: http://54.67.22.49:8081

📋 Create your pipeline job:
1. Click 'New Item'
2. Job name: group6-auto-pipeline
3. Select 'Pipeline'
4. Configure with GitHub repo
5. Save and build

⚠️  IMPORTANT: After creating the job, run the restore script to re-enable security!

🔧 To restore security later:
sudo docker exec jenkins cp /var/jenkins_home/config.xml.backup /var/jenkins_home/config.xml
sudo docker restart jenkins
"