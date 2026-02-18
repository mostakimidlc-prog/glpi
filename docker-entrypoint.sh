#!/bin/bash
set -e

echo "=========================================="
echo "Starting GLPI 11.0.5 Stable container..."
echo "=========================================="

# Wait for Redis to be ready
echo "⏳ Waiting for Redis to be ready..."
max_wait=30
counter=0
while ! nc -z ${REDIS_HOST:-glpi-redis} ${REDIS_PORT:-6379} 2>/dev/null; do
    counter=$((counter + 1))
    if [ $counter -ge $max_wait ]; then
        echo "⚠️  Warning: Redis not available after ${max_wait}s. Continuing anyway..."
        break
    fi
    echo "Waiting for Redis... ($counter/$max_wait)"
    sleep 1
done

if nc -z ${REDIS_HOST:-glpi-redis} ${REDIS_PORT:-6379} 2>/dev/null; then
    echo "✅ Redis is ready!"
fi

# Check if dependencies are already installed
if [ ! -f "/var/www/glpi/.dependencies_installed" ]; then
    echo ""
    echo "📦 Installing GLPI dependencies (Composer & Assets)..."
    echo "This process can take 5-15 minutes."
    
    cd /var/www/glpi
    
    # Configure npm for better reliability
    echo "⚙️  Configuring npm..."
    npm config set fetch-timeout 300000
    npm config set fetch-retries 5
    
    # Install dependencies with retries
    max_attempts=3
    attempt=1
    success=0
    
    while [ $attempt -le $max_attempts ] && [ $success -eq 0 ]; do
        echo ""
        echo "🔄 Attempt $attempt of $max_attempts..."
        
        # In Stable 11.x, we ensure composer is set and then build assets
        if php bin/console dependencies install --allow-superuser --no-interaction; then
            echo ""
            echo "✅ $(date): Dependencies and assets installed successfully!"
            success=1
            touch /var/www/glpi/.dependencies_installed
        else
            exit_code=$?
            echo "❌ Attempt failed with exit code $exit_code"
            attempt=$((attempt + 1))
            [ $attempt -le $max_attempts ] && sleep 10
        fi
    done
    
    if [ $success -eq 0 ]; then
        echo "⚠️  ERROR: Dependency installation failed. Check logs."
    fi
else
    echo "✅ Dependencies already verified. Skipping..."
fi

# Configure Redis in GLPI config
# Note: GLPI 11 uses local_define.php for system-wide constants
if [ -f "/var/www/glpi/config/config_db.php" ]; then
    echo "⚙️  Configuring Redis cache in GLPI..."
    
    if [ ! -f "/var/www/glpi/config/local_define.php" ]; then
        cat > /var/www/glpi/config/local_define.php << EOF
<?php
// Redis Cache Configuration for GLPI 11
if (!isset(\$GLPI_CACHE_CONFIG)) {
    \$GLPI_CACHE_CONFIG = [
        'default' => [
            'adapter' => 'redis',
            'options' => [
                'host' => '${REDIS_HOST:-glpi-redis}',
                'port' => ${REDIS_PORT:-6379},
                'database' => 0,
            ],
        ],
    ];
}
EOF
        # Ensure correct ownership
        chown www-data:www-data /var/www/glpi/config/local_define.php
        echo "✅ Redis cache configuration created!"
    fi
fi

# Ensure .htaccess exists in the /public folder
if [ ! -f "/var/www/glpi/public/.htaccess" ]; then
    echo "📝 Creating .htaccess file for /public entry point..."
    cat > /var/www/glpi/public/.htaccess << 'EOF'
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>
DirectoryIndex index.php
EOF
    chown www-data:www-data /var/www/glpi/public/.htaccess
    echo "✅ .htaccess created!"
fi

# Ensure proper permissions across all critical directories
echo "🔒 Finalizing permissions..."
# Ensure the plugins folder we cloned into is owned by www-data
chown -R www-data:www-data /var/www/glpi/config /var/www/glpi/files /var/www/glpi/marketplace /var/www/glpi/plugins 2>/dev/null || true
chmod -R 775 /var/www/glpi/files /var/www/glpi/config

echo ""
echo "=========================================="
echo "🚀 GLPI 11.0.5 is ready!"
echo "=========================================="
echo "Access GLPI at: http://localhost:8090"
echo "Redis Status: $(nc -z ${REDIS_HOST:-glpi-redis} ${REDIS_PORT:-6379} && echo 'Connected ✅' || echo 'Not available ⚠️')"
echo ""

# Start Apache
exec apache2-foreground
