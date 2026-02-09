pipeline {
    agent any
    
    environment {
        COMPOSE_PROJECT_NAME = 'glpi'
        HOST_PORT = '8088'
    }
    
    stages {
        stage('Cleanup Old Deployment') {
            steps {
                script {
                    echo '🧹 Cleaning up old containers...'
                    sh '''
                        # Stop and remove containers using docker-compose
                        docker-compose down || true
                        
                        # Remove old images to force rebuild
                        docker rmi glpi-glpi-app || true
                        
                        # Remove dangling images
                        docker image prune -f || true
                    '''
                }
            }
        }
        
        stage('Checkout Code') {
            steps {
                echo '📥 Pulling latest code from GitHub...'
                git branch: 'dev-testing',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/mostakimidlc-prog/glpi.git'
            }
        }
        
        stage('Build and Start Services') {
            steps {
                echo '🔨 Building and starting GLPI with database...'
                sh '''
                    # Build and start all services
                    docker-compose up -d --build
                    
                    # Wait for services to be healthy
                    echo "Waiting for database to be ready..."
                    sleep 20
                    
                    echo "Waiting for GLPI to be ready..."
                    sleep 10
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying containers are running...'
                sh '''
                    # Show running containers
                    docker-compose ps
                    
                    # Check container health
                    echo "Checking container health..."
                    docker inspect --format='{{.State.Health.Status}}' glpi-container || echo "No health check"
                    docker inspect --format='{{.State.Health.Status}}' glpi-mysql || echo "No health check"
                    
                    # Verify .htaccess was created
                    echo "Verifying .htaccess file..."
                    docker exec glpi-container cat /var/www/glpi/public/.htaccess
                    
                    # Check if GLPI is accessible
                    echo "Testing GLPI accessibility..."
                    curl -I http://localhost:${HOST_PORT} || echo "GLPI is starting up..."
                    
                    echo ""
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "✨ GLPI Deployment Complete!"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "🌐 Access GLPI at: http://localhost:${HOST_PORT}"
                    echo "📦 PHP Version: 8.2"
                    echo "🗄️  Database: MariaDB 10.11"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                '''
            }
        }
    }
    
    post {
        success {
            echo '✨ Pipeline completed successfully!'
            echo ''
            echo '📋 GLPI is ready for installation at:'
            echo '   http://localhost:8088'
            echo ''
            echo '🔐 Database Credentials for Installation:'
            echo '   SQL Server: glpi-db'
            echo '   SQL User: glpi_user'
            echo '   SQL Password: glpi_pass_2024'
            echo '   Database: glpidb'
        }
        failure {
            echo '❌ Pipeline failed. Check the logs above.'
            echo 'Cleaning up failed deployment...'
            sh 'docker-compose down || true'
        }
        always {
            echo '📊 Container Logs (last 50 lines):'
            sh 'docker-compose logs --tail=50 || true'
        }
    }
}
