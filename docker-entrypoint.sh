#!/bin/bash
set -e

echo "=========================================="
echo "Starting GLPI container..."
echo "=========================================="

# Check if dependencies are already installed
if [ ! -f "/var/www/glpi/.dependencies_installed" ]; then
    echo ""
    echo "📦 Installing GLPI dependencies..."
    echo "This process can take 5-15 minutes."
    echo "Please be patient..."
    echo ""
    
    cd /var/www/glpi
    
    # Configure npm for better reliability
    echo "⚙️  Configuring npm..."
    npm config set fetch-timeout 300000
    npm config set fetch-retries 5
    npm config set fetch-retry-mintimeout 20000
    npm config set fetch-retry-maxtimeout 120000
    
    # Install dependencies with retries
    max_attempts=5
    attempt=1
    success=0
    
    while [ $attempt -le $max_attempts ] && [ $success -eq 0 ]; do
        echo ""
        echo "🔄 Attempt $attempt of $max_attempts..."
        echo "$(date): Starting dependency installation..."
        
        if php bin/console dependencies install --allow-superuser --no-interaction; then
            echo ""
            echo "✅ $(date): Dependencies installed successfully!"
            success=1
            touch /var/www/glpi/.dependencies_installed
        else
            exit_code=$?
            echo ""
            echo "❌ $(date): Dependency installation failed with exit code $exit_code"
            
            if [ $attempt -lt $max_attempts ]; then
                wait_time=$((attempt * 15))
                echo "Waiting $wait_time seconds before retry..."
                sleep $wait_time
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $success -eq 0 ]; then
        echo ""
        echo "⚠️  ERROR: Dependencies installation failed after $max_attempts attempts."
        echo "This is likely due to network timeouts downloading npm packages."
        echo ""
        echo "You can try to fix this by:"
        echo "1. docker exec -it glpi-container bash"
        echo "2. cd /var/www/glpi"
        echo "3. php bin/console dependencies install --allow-superuser"
        echo ""
        echo "Container will start Apache anyway, but GLPI may not work correctly."
        echo ""
    fi
else
    echo "✅ Dependencies already installed. Skipping..."
fi

# Ensure .htaccess exists
if [ ! -f "/var/www/glpi/public/.htaccess" ]; then
    echo "📝 Creating .htaccess file..."
    cat > /var/www/glpi/public/.htaccess << 'EOF'
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>

DirectoryIndex index.php
EOF
    chown www-data:www-data /var/www/glpi/public/.htaccess
    chmod 644 /var/www/glpi/public/.htaccess
    echo "✅ .htaccess created successfully!"
else
    echo "✅ .htaccess already exists. Skipping..."
fi

# Ensure proper permissions
echo "🔒 Setting permissions..."
chown -R www-data:www-data /var/www/glpi/config /var/www/glpi/files /var/www/glpi/marketplace 2>/dev/null || true

echo ""
echo "=========================================="
echo "🚀 GLPI container is ready!"
echo "=========================================="
echo "Access GLPI at: http://localhost:8088"
echo ""

# Start Apache
exec apache2-foreground
