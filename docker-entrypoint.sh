#!/bin/bash
set -e

echo "Starting GLPI container..."

# Check if dependencies are already installed
if [ ! -f "/var/www/glpi/.dependencies_installed" ]; then
    echo "Installing GLPI dependencies (this may take a few minutes)..."
    cd /var/www/glpi
    
    # Install dependencies with retries
    max_attempts=3
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts..."
        if php bin/console dependencies install --allow-superuser --no-interaction; then
            echo "Dependencies installed successfully!"
            touch /var/www/glpi/.dependencies_installed
            break
        else
            echo "Dependency installation failed. Retrying..."
            attempt=$((attempt + 1))
            sleep 5
        fi
    done
    
    if [ ! -f "/var/www/glpi/.dependencies_installed" ]; then
        echo "Warning: Dependencies installation failed after $max_attempts attempts."
        echo "GLPI may not work correctly. Please check logs."
    fi
fi

# Ensure .htaccess exists
if [ ! -f "/var/www/glpi/public/.htaccess" ]; then
    echo "Creating .htaccess file..."
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
    echo ".htaccess created successfully!"
fi

# Ensure proper permissions
chown -R www-data:www-data /var/www/glpi/config /var/www/glpi/files /var/www/glpi/marketplace 2>/dev/null || true

echo "GLPI container is ready!"

# Start Apache
exec apache2-foreground
