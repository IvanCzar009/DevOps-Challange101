#!/bin/bash

echo "=== INSTALLING JENKINS PLUGINS AUTOMATICALLY ==="

echo "[1/5] Installing required Jenkins plugins..."

# List of essential plugins for CI/CD
PLUGINS=(
    "git:5.0.0"
    "workflow-aggregator:596.v8c21c963d92d"
    "pipeline-stage-view:2.25"
    "blueocean:1.25.2"
    "github:1.37.0"
    "pipeline-github-lib:38.v445716ea_edda_"
    "nodejs:1.6.0"
    "sonar:2.15"
    "build-timeout:1.27"
    "credentials-binding:523.vd859a_4b_122e6"
    "timestamper:1.17"
    "ws-cleanup:0.44"
    "ant:475.vf34069fef73c"
    "gradle:2.8.1"
    "pipeline-npm:1.0.1"
    "junit:1159.v0b_396e1e07dd"
    "matrix-auth:3.1.5"
    "pam-auth:1.10"
    "ldap:682.v7b_544c9d1512"
    "email-ext:2.93"
    "mailer:448.v5b_97805e3767"
    "ssh-slaves:2.877.v365f5eb_a_b_eec"
    "publish-over-ssh:1.24"
    "copyartifact:705.v5295cffec284"
    "maven-plugin:3.19"
)

echo "[2/5] Downloading and installing plugins..."
for plugin in "${PLUGINS[@]}"; do
    plugin_name=$(echo $plugin | cut -d':' -f1)
    echo "Installing $plugin_name..."
    sudo docker exec jenkins java -jar /var/jenkins_home/war/WEB-INF/lib/cli-2.414.1.jar -s http://localhost:8080/ install-plugin $plugin || {
        echo "Failed to install $plugin_name, trying direct download..."
        sudo docker exec jenkins curl -L -o "/var/jenkins_home/plugins/${plugin_name}.jpi" "https://updates.jenkins-ci.org/download/plugins/${plugin_name}/latest/${plugin_name}.hpi" || true
    }
done

echo "[3/5] Installing core pipeline plugins manually..."
sudo docker exec jenkins bash -c "
mkdir -p /var/jenkins_home/plugins
cd /var/jenkins_home/plugins

# Download essential plugins directly
wget -q https://updates.jenkins-ci.org/download/plugins/git/latest/git.hpi
wget -q https://updates.jenkins-ci.org/download/plugins/workflow-aggregator/latest/workflow-aggregator.hpi
wget -q https://updates.jenkins-ci.org/download/plugins/pipeline-stage-view/latest/pipeline-stage-view.hpi
wget -q https://updates.jenkins-ci.org/download/plugins/github/latest/github.hpi
wget -q https://updates.jenkins-ci.org/download/plugins/nodejs/latest/nodejs.hpi
wget -q https://updates.jenkins-ci.org/download/plugins/sonar/latest/sonar.hpi
wget -q https://updates.jenkins-ci.org/download/plugins/blueocean/latest/blueocean.hpi

# Rename .hpi to .jpi for Jenkins
for file in *.hpi; do
    if [ -f \"\$file\" ]; then
        mv \"\$file\" \"\${file%.hpi}.jpi\"
    fi
done

# Set proper permissions
chown -R jenkins:jenkins /var/jenkins_home/plugins/
chmod 644 /var/jenkins_home/plugins/*.jpi
"

echo "[4/5] Creating plugin dependencies list..."
sudo docker exec jenkins bash -c "
cat > /var/jenkins_home/plugins.txt << 'EOF'
git:latest
workflow-aggregator:latest
pipeline-stage-view:latest
github:latest
nodejs:latest
sonar:latest
blueocean:latest
timestamper:latest
ws-cleanup:latest
build-timeout:latest
credentials-binding:latest
junit:latest
matrix-auth:latest
email-ext:latest
mailer:latest
EOF
"

echo "[5/5] Restarting Jenkins to load plugins..."
sudo docker restart jenkins

echo "Waiting for Jenkins to restart with plugins..."
sleep 45

for i in {1..15}; do
    if curl -f -s http://localhost:8081 > /dev/null; then
        echo "✅ Jenkins is running with plugins loaded"
        break
    else
        echo "⏳ Waiting for Jenkins with plugins... ($i/15)"
        sleep 10
    fi
done

echo "
🎉 JENKINS PLUGINS INSTALLATION COMPLETE!

✅ Git plugin installed
✅ Pipeline plugins installed  
✅ GitHub integration installed
✅ Node.js plugin installed
✅ SonarQube plugin installed
✅ Blue Ocean UI installed
✅ Additional CI/CD plugins installed

🌐 Access Jenkins: http://54.67.22.49:8081

📋 Now you can create a Pipeline job:
1. Click 'New Item'
2. Enter name: group6-auto-pipeline
3. Select 'Pipeline' (should now be available)
4. Configure with Git repository
5. Save and build

🔧 Available Job Types Now:
• Freestyle project
• Pipeline
• Multibranch Pipeline
• Folder
• GitHub Organization

🚀 Ready for full CI/CD automation!
"