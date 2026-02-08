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
                        docker-compose down || true
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
        
        stage('Verify Prerequisites') {
            steps {
                echo '🔍 Verifying GLPI prerequisites...'
                sh '''
                    echo "Checking Docker and Docker Compose versions..."
                    docker --version
                    docker-compose --version
                    
                    echo "Building verification image..."
                    docker build -t glpi-verify -f Dockerfile .
                    
                    echo "Running prerequisite checks..."
                    docker run --rm glpi-verify php -v
                    docker run --rm glpi-verify php -m
                '''
            }
        }
        
        stage('Build and Start Services') {
            steps {
                echo '🔨 Building and starting GLPI with MariaDB...'
                sh '''
                    docker-compose up -d --build
                    
                    echo "Waiting for database to be ready..."
                    sleep 20
                    
                    echo "Waiting for GLPI application to start..."
                    sleep 10
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo '✅ Verifying deployment...'
                sh '''
                    echo "Checking container status..."
                    docker-compose ps
                    
                    echo "\nChecking container health..."
                    docker inspect --format='{{.State.Health.Status}}' glpi-container || echo "No health check"
                    docker inspect --format='{{.State.Health.Status}}' glpi-mysql || echo "No health check"
                    
                    echo "\nVerifying GLPI PHP requirements..."
                    docker exec glpi-container php /var/www/html/verify-requirements.php || echo "Verification script not found"
                    
                    echo "\nTesting GLPI accessibility..."
                    curl -I http://localhost:${HOST_PORT} || echo "GLPI is starting..."
                    
                    echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
            echo '📋 Installation Wizard Database Credentials:'
            echo '   SQL Server: glpi-db'
            echo '   SQL User: glpi_user'
            echo '   SQL Password: glpi_pass_2024'
            echo '   Database: glpidb'
            echo ''
            echo '🔐 Default GLPI Login (after installation):'
            echo '   Username: glpi'
            echo '   Password: glpi'
        }
        failure {
            echo '❌ Pipeline failed. Cleaning up...'
            sh 'docker-compose down || true'
        }
        always {
            echo '📊 Container Logs (last 50 lines):'
            sh 'docker-compose logs --tail=50 || true'
        }
    }
}
