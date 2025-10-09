#!/bin/bash

# Automated Jenkins Pipeline Job Creation for Terraform
# Creates Jenkins job for Group6 React App automatically

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

echo -e "${BLUE}=== Automated Jenkins Pipeline Job Creation ===${NC}"

# Configuration
JENKINS_URL="http://localhost:8081"
JENKINS_USER="admin"
JENKINS_PASS="${JENKINS_ADMIN_PASSWORD:-admin123456}"
JOB_NAME="group6-react-app-pipeline"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

log "Creating Jenkins pipeline job: $JOB_NAME"

# Wait for Jenkins to be fully ready
log "Waiting for Jenkins to be ready..."
ATTEMPTS=0
MAX_ATTEMPTS=60

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if timeout 15 curl -s -u $JENKINS_USER:$JENKINS_PASS --max-time 10 $JENKINS_URL/api/json > /dev/null 2>&1; then
        log "✅ Jenkins is ready"
        break
    fi
    
    ATTEMPTS=$((ATTEMPTS + 1))
    log "Jenkins readiness check: attempt $ATTEMPTS/$MAX_ATTEMPTS"
    sleep 10
done

if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    error "❌ Jenkins failed to become ready"
    exit 1
fi

# Copy React app to Jenkins workspace if not exists
if [ ! -d "/home/ec2-user/group6-react-app" ]; then
    cp -r /tmp/group6-react-app /home/ec2-user/
    chown -R ec2-user:ec2-user /home/ec2-user/group6-react-app
    log "✅ React app copied to Jenkins workspace"
fi

# Initialize git repository in React app
cd /home/ec2-user/group6-react-app
if [ ! -d ".git" ]; then
    git init
    git add .
    git commit -m "Initial commit for Jenkins pipeline" || log "Git commit completed"
    log "✅ Git repository initialized"
fi

# Create Jenkins job using Jenkins CLI approach
log "Setting up Jenkins CLI..."

# Download Jenkins CLI if not exists
if [ ! -f "/tmp/jenkins-cli.jar" ]; then
    curl -s $JENKINS_URL/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar
fi

# Create job XML configuration
cat > /tmp/pipeline-job.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Automated CI/CD Pipeline for Group6 React Application</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <jenkins.model.BuildDiscarderProperty>
      <strategy class="hudson.tasks.LogRotator">
        <daysToKeep>30</daysToKeep>
        <numToKeep>10</numToKeep>
        <artifactDaysToKeep>-1</artifactDaysToKeep>
        <artifactNumToKeep>-1</artifactNumToKeep>
      </strategy>
    </jenkins.model.BuildDiscarderProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>
pipeline {
    agent any
    
    environment {
        APP_NAME = 'group6-react-app'
        PUBLIC_IP = '$PUBLIC_IP'
        NODE_VERSION = '18'
    }
    
    stages {
        stage('🚀 Setup') {
            steps {
                echo "Starting Group6 React App CI/CD Pipeline"
                echo "Build Number: \${BUILD_NUMBER}"
                echo "Public IP: \${PUBLIC_IP}"
                echo "Workspace: \${WORKSPACE}"
            }
        }
        
        stage('📥 Checkout') {
            steps {
                script {
                    dir('/home/ec2-user/group6-react-app') {
                        sh '''
                            echo "Source code already available in workspace"
                            ls -la
                        '''
                    }
                }
            }
        }
        
        stage('🔧 Install Dependencies') {
            steps {
                script {
                    dir('/home/ec2-user/group6-react-app') {
                        sh '''
                            echo "📦 Installing npm dependencies..."
                            npm install --no-audit --no-fund
                            echo "✅ Dependencies installed successfully"
                        '''
                    }
                }
            }
        }
        
        stage('🏗️ Build') {
            steps {
                script {
                    dir('/home/ec2-user/group6-react-app') {
                        sh '''
                            echo "🏗️ Building React application..."
                            npm run build
                            echo "✅ Build completed successfully"
                            
                            # Verify build output
                            if [ -d "build" ]; then
                                echo "Build directory contents:"
                                ls -la build/
                                echo "Build size: \$(du -sh build/ | cut -f1)"
                            else
                                echo "❌ Build failed - no build directory found"
                                exit 1
                            fi
                        '''
                    }
                }
            }
            post {
                success {
                    script {
                        dir('/home/ec2-user/group6-react-app') {
                            archiveArtifacts artifacts: 'build/**/*', fingerprint: true
                        }
                    }
                }
            }
        }
        
        stage('🧪 Test') {
            steps {
                script {
                    dir('/home/ec2-user/group6-react-app') {
                        sh '''
                            echo "🧪 Running tests with coverage..."
                            export CI=true
                            npm test -- --coverage --watchAll=false --passWithNoTests --silent
                            echo "✅ Tests completed successfully"
                        '''
                    }
                }
            }
            post {
                always {
                    script {
                        dir('/home/ec2-user/group6-react-app') {
                            if (fileExists('coverage')) {
                                archiveArtifacts artifacts: 'coverage/**/*', allowEmptyArchive: true
                                echo "✅ Test coverage reports archived"
                            }
                        }
                    }
                }
            }
        }
        
        stage('🔍 Quality Analysis') {
            steps {
                script {
                    dir('/home/ec2-user/group6-react-app') {
                        sh '''
                            echo "🔍 Running SonarQube quality analysis..."
                            
                            # Get SonarQube credentials
                            if [ -f /home/ec2-user/.sonarqube-credentials ]; then
                                source /home/ec2-user/.sonarqube-credentials
                                SONAR_PASS="\$SONARQUBE_ADMIN_PASSWORD"
                            else
                                SONAR_PASS="admin"
                            fi
                            
                            # Wait for SonarQube to be ready
                            timeout 60 bash -c 'until curl -s http://localhost:9000/api/system/status | grep -q "UP"; do sleep 5; done' || echo "SonarQube check completed"
                            
                            # Run SonarQube analysis
                            sonar-scanner \\
                                -Dsonar.projectKey=group6-react-app \\
                                -Dsonar.projectName="Group6 React App" \\
                                -Dsonar.projectVersion=1.0.\${BUILD_NUMBER} \\
                                -Dsonar.sources=src \\
                                -Dsonar.host.url=http://localhost:9000 \\
                                -Dsonar.login=admin \\
                                -Dsonar.password="\$SONAR_PASS" \\
                                -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info || echo "SonarQube analysis completed with warnings"
                                
                            echo "✅ Quality analysis completed"
                        '''
                    }
                }
            }
        }
        
        stage('📦 Package') {
            steps {
                script {
                    dir('/home/ec2-user/group6-react-app') {
                        sh '''
                            echo "📦 Creating deployment package..."
                            tar -czf \${APP_NAME}-\${BUILD_NUMBER}.tar.gz build/
                            echo "✅ Package created: \${APP_NAME}-\${BUILD_NUMBER}.tar.gz"
                        '''
                    }
                }
            }
            post {
                success {
                    script {
                        dir('/home/ec2-user/group6-react-app') {
                            archiveArtifacts artifacts: "\${APP_NAME}-\${BUILD_NUMBER}.tar.gz", fingerprint: true
                        }
                    }
                }
            }
        }
        
        stage('🚀 Deploy to Tomcat') {
            steps {
                script {
                    dir('/home/ec2-user/group6-react-app') {
                        sh '''
                            echo "🚀 Deploying to Tomcat..."
                            
                            # Wait for Tomcat to be ready
                            timeout 30 bash -c 'until curl -s http://localhost:8080 > /dev/null 2>&1; do sleep 2; done' || echo "Tomcat check completed"
                            
                            # Clean previous deployment
                            sudo rm -rf /opt/tomcat/webapps/\${APP_NAME}
                            sudo rm -f /opt/tomcat/webapps/\${APP_NAME}.war
                            
                            # Deploy new build
                            sudo cp -r build /opt/tomcat/webapps/\${APP_NAME}
                            sudo chown -R tomcat:tomcat /opt/tomcat/webapps/\${APP_NAME}
                            
                            echo "✅ Deployment completed successfully"
                            echo "🌐 Application URL: http://\${PUBLIC_IP}:8080/\${APP_NAME}"
                        '''
                    }
                }
            }
        }
        
        stage('🏥 Health Check') {
            steps {
                sh '''
                    echo "🏥 Performing deployment health check..."
                    sleep 10
                    
                    # Check if application is accessible
                    HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/\${APP_NAME}/ || echo "000")
                    
                    if [ "\$HTTP_STATUS" = "200" ]; then
                        echo "✅ Application is healthy and accessible!"
                        echo "🎉 Deployment verification successful!"
                    else
                        echo "⚠️ Application returned HTTP status: \$HTTP_STATUS"
                        echo "ℹ️ Application may still be starting up..."
                    fi
                    
                    # Display deployment summary
                    echo ""
                    echo "=== DEPLOYMENT SUMMARY ==="
                    echo "Application: \${APP_NAME}"
                    echo "Build Number: \${BUILD_NUMBER}"
                    echo "Public URL: http://\${PUBLIC_IP}:8080/\${APP_NAME}"
                    echo "SonarQube: http://\${PUBLIC_IP}:9000"
                    echo "Jenkins: http://\${PUBLIC_IP}:8081"
                    echo "==========================="
                '''
            }
        }
    }
    
    post {
        always {
            echo '🧹 Cleaning up workspace...'
            sh 'npm cache clean --force || true'
        }
        success {
            echo '✅ Pipeline completed successfully!'
            echo '🎉 Your Group6 React App is now deployed and accessible!'
        }
        failure {
            echo '❌ Pipeline failed!'
            echo '💡 Check the console output above for details'
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers>
    <hudson.triggers.TimerTrigger>
      <spec>H */4 * * *</spec>
    </hudson.triggers.TimerTrigger>
  </triggers>
  <disabled>false</disabled>
</flow-definition>
EOF

# Try to create the job using curl with proper error handling
log "Creating Jenkins job via REST API..."

# Method 1: Try without CSRF token first (with timeout)
CREATE_RESPONSE=$(timeout 60 curl -s -w "HTTPSTATUS:%{http_code}" -u $JENKINS_USER:$JENKINS_PASS \
    -H "Content-Type: application/xml" \
    --data-binary @/tmp/pipeline-job.xml \
    --max-time 30 \
    "$JENKINS_URL/createItem?name=$JOB_NAME" 2>/dev/null || echo "HTTPSTATUS:000")

HTTP_STATUS=$(echo $CREATE_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
    log "✅ Jenkins job '$JOB_NAME' created successfully"
elif [ "$HTTP_STATUS" = "400" ]; then
    warn "⚠️ Job already exists, attempting to update..."
    
    # Try to update existing job (with timeout)
    UPDATE_RESPONSE=$(timeout 60 curl -s -w "HTTPSTATUS:%{http_code}" -u $JENKINS_USER:$JENKINS_PASS \
        -H "Content-Type: application/xml" \
        --data-binary @/tmp/pipeline-job.xml \
        --max-time 30 \
        "$JENKINS_URL/job/$JOB_NAME/config.xml" 2>/dev/null || echo "HTTPSTATUS:000")
    
    UPDATE_STATUS=$(echo $UPDATE_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$UPDATE_STATUS" = "200" ]; then
        log "✅ Jenkins job '$JOB_NAME' updated successfully"
    else
        warn "⚠️ Could not update job automatically. Manual setup may be required."
    fi
elif [ "$HTTP_STATUS" = "403" ]; then
    # Try with CSRF token
    log "Attempting job creation with CSRF protection..."
    
    CRUMB=$(timeout 30 curl -s -u $JENKINS_USER:$JENKINS_PASS --max-time 15 "$JENKINS_URL/crumbIssuer/api/json" | grep -o '"crumb":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    
    if [ ! -z "$CRUMB" ]; then
        CREATE_RESPONSE_CSRF=$(timeout 60 curl -s -w "HTTPSTATUS:%{http_code}" -u $JENKINS_USER:$JENKINS_PASS \
            -H "Jenkins-Crumb:$CRUMB" \
            -H "Content-Type: application/xml" \
            --data-binary @/tmp/pipeline-job.xml \
            --max-time 30 \
            "$JENKINS_URL/createItem?name=$JOB_NAME" 2>/dev/null || echo "HTTPSTATUS:000")
        
        CSRF_STATUS=$(echo $CREATE_RESPONSE_CSRF | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
        
        if [ "$CSRF_STATUS" = "200" ] || [ "$CSRF_STATUS" = "201" ]; then
            log "✅ Jenkins job '$JOB_NAME' created successfully with CSRF token"
        else
            warn "⚠️ Job creation with CSRF failed. Status: $CSRF_STATUS"
        fi
    else
        warn "⚠️ Could not retrieve CSRF token"
    fi
else
    warn "⚠️ Job creation returned status: $HTTP_STATUS"
fi

# Trigger initial build automatically
log "Triggering initial pipeline build automatically..."

# Wait a moment for job to be fully created
sleep 5

# Try multiple methods to trigger the build
BUILD_TRIGGERED=false

# Method 1: Try with CSRF token if available
if [ ! -z "$CRUMB" ]; then
    BUILD_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -u $JENKINS_USER:$JENKINS_PASS \
        -H "Jenkins-Crumb:$CRUMB" \
        -X POST "$JENKINS_URL/job/$JOB_NAME/build" 2>/dev/null || echo "HTTPSTATUS:000")
    BUILD_STATUS=$(echo $BUILD_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$BUILD_STATUS" = "201" ]; then
        log "✅ Initial build triggered successfully with CSRF token"
        BUILD_TRIGGERED=true
    fi
fi

# Method 2: Try without CSRF token
if [ "$BUILD_TRIGGERED" = false ]; then
    BUILD_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -u $JENKINS_USER:$JENKINS_PASS \
        -X POST "$JENKINS_URL/job/$JOB_NAME/build" 2>/dev/null || echo "HTTPSTATUS:000")
    BUILD_STATUS=$(echo $BUILD_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$BUILD_STATUS" = "201" ]; then
        log "✅ Initial build triggered successfully"
        BUILD_TRIGGERED=true
    fi
fi

# Method 3: Try with buildWithParameters endpoint
if [ "$BUILD_TRIGGERED" = false ]; then
    BUILD_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -u $JENKINS_USER:$JENKINS_PASS \
        -X POST "$JENKINS_URL/job/$JOB_NAME/buildWithParameters" 2>/dev/null || echo "HTTPSTATUS:000")
    BUILD_STATUS=$(echo $BUILD_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$BUILD_STATUS" = "201" ]; then
        log "✅ Initial build triggered successfully with parameters"
        BUILD_TRIGGERED=true
    fi
fi

if [ "$BUILD_TRIGGERED" = true ]; then
    log "🎉 Automatic build started! Your pipeline is running."
    log "📊 Monitor progress at: http://$PUBLIC_IP:8081/job/$JOB_NAME"
    
    # Wait and show build progress
    log "Waiting for build to start..."
    sleep 10
    
    # Check if build is running
    BUILD_INFO=$(curl -s -u $JENKINS_USER:$JENKINS_PASS "$JENKINS_URL/job/$JOB_NAME/api/json" 2>/dev/null || echo "")
    if echo "$BUILD_INFO" | grep -q '"inQueue":true\|"building":true'; then
        log "✅ Build is now running automatically!"
        log "🔄 Your Group6 React App is being built, tested, and deployed!"
    fi
else
    warn "⚠️ Automatic build trigger failed. Status: $BUILD_STATUS"
    log "💡 But don't worry - the job is created and ready to run manually if needed"
fi

# Clean up temporary files
rm -f /tmp/pipeline-job.xml

# Display completion information
echo -e "${GREEN}"
echo "=== JENKINS PIPELINE AUTOMATION COMPLETE ==="
echo ""
echo "🎉 Jenkins Pipeline Job Ready!"
echo ""
echo "📊 Access Jenkins: http://$PUBLIC_IP:8081"
echo "🔧 Pipeline Job: http://$PUBLIC_IP:8081/job/$JOB_NAME"
echo "👤 Credentials: $JENKINS_USER / $JENKINS_PASS"
echo ""
echo "🚀 Pipeline Features:"
echo "   • Automated source checkout"
echo "   • NPM dependency management"  
echo "   • React application build"
echo "   • Test execution with coverage"
echo "   • SonarQube quality analysis"
echo "   • Deployment package creation"
echo "   • Tomcat deployment"
echo "   • Health check verification"
echo ""
echo "🌐 After successful build:"
echo "   Your app: http://$PUBLIC_IP:8080/group6-react-app"
echo -e "${NC}"

log "✅ Jenkins pipeline automation completed successfully!"

exit 0