#!/bin/bash
set -e

echo "=========================================="
echo "Starting GLPI container..."
echo "=========================================="

# Check if dependencies are already installed
if [ ! -f "/var/www/glpi/.dependencies_installed" ]; then
    echo ""
    echo "📦 Installing GLPI dependencies..."
    echo "This process can take 5-10 minutes."
    echo "Please be patient..."
    echo ""
    
    cd /var/www/glpi
    
    # Install dependencies with retries and progress logging
    max_attempts=3
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "🔄 Attempt $attempt of $max_attempts..."
        echo "$(date): Starting dependency installation..."
        
        if php bin/console dependencies install --allow-superuser --no-interaction 2>&1 | tee /tmp/dependencies.log; then
            echo ""
            echo "✅ $(date): Dependencies installed successfully!"
            touch /var/www/glpi/.dependencies_installed
            break
        else
            echo ""
            echo "❌ $(date): Dependency installation failed."
            echo "Last 20 lines of output:"
            tail -20 /tmp/dependencies.log
            
            if [ $attempt -lt $max_attempts ]; then
                echo "Retrying in 10 seconds..."
                sleep 10
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    if [ ! -f "/var/www/glpi/.dependencies_installed" ]; then
        echo ""
        echo "⚠️  Warning: Dependencies installation failed after $max_attempts attempts."
        echo "GLPI may not work correctly. Please check logs."
        echo "You can try manually running:"
        echo "  docker exec glpi-container php /var/www/glpi/bin/console dependencies install --allow-superuser"
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
