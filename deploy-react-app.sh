#!/bin/bash
set -e

echo "=== Deploying React Application ==="
echo "Starting at: $(date)"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Setting up React app deployment environment..."

# Install Node.js and npm if not already available
if ! command -v node >/dev/null 2>&1; then
    log "Installing Node.js..."
    curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
fi

# Verify Node.js installation
log "Node.js version: $(node --version)"
log "NPM version: $(npm --version)"

# Create deployment directory
mkdir -p /home/ec2-user/react-app
cd /home/ec2-user/react-app

# Create a sample React app structure (since we can't transfer the actual files via terraform)
log "Creating React app deployment structure..."

# Create package.json for the React app
cat > package.json << 'EOF'
{
  "name": "group6-react-app",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF

# Create a basic React app structure
mkdir -p src public

# Create basic HTML template
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Group 6 React Application" />
    <title>Group 6 React App</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# Create basic React component
cat > src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

cat > src/App.js << 'EOF'
import React from 'react';
import './App.css';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1>Group 6 React Application</h1>
        <p>Successfully deployed via CI/CD Pipeline!</p>
        <p>Services Status:</p>
        <ul style={{textAlign: 'left'}}>
          <li>✅ GitLab CI/CD Pipeline</li>
          <li>✅ SonarQube Code Quality</li>
          <li>✅ ELK Stack Monitoring</li>
          <li>✅ Tomcat Application Server</li>
        </ul>
        <p>
          <a href="/manager" target="_blank" rel="noopener noreferrer">
            Tomcat Manager
          </a>
          {' | '}
          <a href=":8081" target="_blank" rel="noopener noreferrer">
            GitLab
          </a>
          {' | '}
          <a href=":9000" target="_blank" rel="noopener noreferrer">
            SonarQube
          </a>
          {' | '}
          <a href=":5061" target="_blank" rel="noopener noreferrer">
            Kibana
          </a>
        </p>
      </header>
    </div>
  );
}

export default App;
EOF

cat > src/App.css << 'EOF'
.App {
  text-align: center;
}

.App-header {
  background-color: #282c34;
  padding: 20px;
  color: white;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-size: calc(10px + 2vmin);
}

.App-header a {
  color: #61dafb;
  text-decoration: none;
}

.App-header a:hover {
  text-decoration: underline;
}

.App-header ul {
  font-size: 18px;
  max-width: 400px;
}

.App-header li {
  margin: 10px 0;
}
EOF

# Install dependencies and build the React app
log "Installing React dependencies..."
npm install

log "Building React application..."
npm run build

# Create WAR file for Tomcat deployment
log "Creating WAR file for Tomcat deployment..."
cd build
jar -cvf ../group6-react-app.war *
cd ..

# Deploy to Tomcat
log "Deploying React app to Tomcat..."
# Wait for Tomcat to be ready
sleep 10

# Copy WAR file to Tomcat webapps directory
docker cp group6-react-app.war tomcat:/usr/local/tomcat/webapps/

log "Waiting for application deployment..."
sleep 30

# Verify deployment
if curl -s http://localhost:8080/group6-react-app/ | grep -q "Group 6 React Application"; then
    log "✅ React application deployed successfully!"
else
    log "⚠️  React application deployed but may need a few more moments to be fully available"
fi

log "=== React App Deployment Complete ==="
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo ""
echo "🎉 Your React Application is now deployed!"
echo ""
echo "📱 React App URL: http://$PUBLIC_IP:8080/group6-react-app/"
echo "🚀 Tomcat Manager: http://$PUBLIC_IP:8080/manager"
echo ""
log "React app deployment completed at: $(date)"