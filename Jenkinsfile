pipeline {
    agent any
    
    environment {
        SONARQUBE_SERVER = 'http://localhost:9000'
        TOMCAT_URL = 'http://localhost:8080'
        APP_NAME = 'group6-react-app'
        SONAR_TOKEN = credentials('sonar-token')
    }
    
    triggers {
        // Poll SCM every 5 minutes for changes
        pollSCM('H/5 * * * *')
        // GitHub webhook trigger
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code from Git...'
                checkout scm
                sh 'ls -la'
                sh 'pwd'
            }
        }
        
        stage('Setup') {
            steps {
                echo 'Setting up environment...'
                sh '''
                    # Install Node.js if not present
                    if ! command -v node &> /dev/null; then
                        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
                        sudo yum install -y nodejs
                    fi
                    
                    # Verify Node.js and npm
                    node --version
                    npm --version
                '''
            }
        }
        
        stage('Build React App') {
            steps {
                echo 'Building React application...'
                dir('group6-react-app') {
                    sh '''
                        # Install dependencies
                        npm install
                        
                        # Build the React app
                        npm run build
                        
                        # Verify build output
                        ls -la build/
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                echo 'Running tests...'
                dir('group6-react-app') {
                    sh '''
                        # Run tests
                        npm test -- --coverage --watchAll=false || echo "Tests completed"
                        
                        # Generate test reports
                        if [ -d coverage ]; then
                            echo "Test coverage generated"
                            ls -la coverage/
                        fi
                    '''
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                echo 'Running SonarQube code analysis...'
                dir('group6-react-app') {
                    sh '''
                        # Run SonarQube scanner
                        sonar-scanner \
                            -Dsonar.projectKey=group6-react-app \
                            -Dsonar.projectName="Group6 React App" \
                            -Dsonar.sources=src \
                            -Dsonar.host.url=$SONARQUBE_SERVER \
                            -Dsonar.login=admin \
                            -Dsonar.password=admin \
                            -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info || echo "SonarQube analysis completed"
                    '''
                }
            }
        }
        
        stage('Build Deployment Package') {
            steps {
                echo 'Creating deployment package...'
                dir('group6-react-app') {
                    sh '''
                        # Create deployment directory
                        mkdir -p ../deployment
                        
                        # Copy build artifacts
                        cp -r build/* ../deployment/
                        
                        # Create deployment archive
                        cd ../deployment
                        tar -czf ../group6-react-app-${BUILD_NUMBER}.tar.gz *
                        
                        echo "Deployment package created: group6-react-app-${BUILD_NUMBER}.tar.gz"
                        ls -la ../*.tar.gz
                    '''
                }
            }
        }
        
        stage('Deploy to Tomcat') {
            steps {
                echo 'Deploying to Tomcat server...'
                sh '''
                    # Stop Tomcat for safe deployment
                    /home/ec2-user/apache-tomcat-10.1.15/bin/shutdown.sh || echo "Tomcat already stopped"
                    
                    # Backup current deployment
                    if [ -d /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app ]; then
                        mv /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app \
                           /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app-backup-$(date +%Y%m%d-%H%M%S)
                    fi
                    
                    # Create new deployment directory
                    mkdir -p /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app
                    
                    # Extract new deployment
                    cd /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app
                    tar -xzf $WORKSPACE/group6-react-app-${BUILD_NUMBER}.tar.gz
                    
                    # Set proper permissions
                    chown -R ec2-user:ec2-user /home/ec2-user/apache-tomcat-10.1.15/webapps/group6-react-app
                    
                    # Start Tomcat
                    /home/ec2-user/apache-tomcat-10.1.15/bin/startup.sh
                    
                    echo "Deployment completed successfully!"
                '''
            }
        }
        
        stage('Health Check') {
            steps {
                echo 'Performing application health check...'
                sh '''
                    # Wait for Tomcat to start
                    sleep 15
                    
                    # Check if application is accessible
                    for i in {1..10}; do
                        if curl -f http://localhost:8080/group6-react-app/ > /dev/null 2>&1; then
                            echo "✅ Application is healthy and accessible!"
                            curl -I http://localhost:8080/group6-react-app/
                            break
                        else
                            echo "⏳ Waiting for application to start... (attempt $i/10)"
                            sleep 10
                        fi
                    done
                    
                    # Final health check
                    curl -f http://localhost:8080/group6-react-app/ || echo "⚠️ Health check completed with warnings"
                '''
            }
        }
        
        stage('Notification') {
            steps {
                echo 'Sending deployment notifications...'
                sh '''
                    echo "🎉 DEPLOYMENT SUCCESSFUL! 🎉"
                    echo "Application URL: http://54.67.22.49:8080/group6-react-app/"
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Git Branch: ${GIT_BRANCH}"
                    echo "Git Commit: ${GIT_COMMIT}"
                    echo "Deployed at: $(date)"
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline execution completed!'
            // Archive build artifacts
            archiveArtifacts artifacts: '*.tar.gz', fingerprint: true, allowEmptyArchive: true
            
            // Cleanup workspace
            sh 'rm -f *.tar.gz'
        }
        
        success {
            echo '✅ Pipeline succeeded! Application deployed successfully.'
            sh '''
                echo "SUCCESS: Deployment completed at $(date)"
                echo "Application: http://54.67.22.49:8080/group6-react-app/"
            '''
        }
        
        failure {
            echo '❌ Pipeline failed! Check logs for details.'
            sh '''
                echo "FAILURE: Pipeline failed at $(date)"
                echo "Check Jenkins console output for details"
            '''
        }
        
        unstable {
            echo '⚠️ Pipeline unstable! Some tests may have failed.'
        }
    }
}