#!/bin/bash
set -e

# 1. Internal traffic MUST bypass the alpha proxy
export no_proxy="localhost,127.0.0.1,glpi-prod-db,glpi-prod-redis,glpi-db-service,glpi-redis-service,.svc,.cluster.local"
export NO_PROXY=$no_proxy

echo "🚀 Starting GLPI 11.0.5 Optimized Container..."

# 2. Wait for Redis (Internal check, bypasses proxy via no_proxy)
echo "⏳ Checking Redis connection at ${REDIS_HOST:-glpi-redis}..."
max_wait=15
counter=0
while ! nc -z ${REDIS_HOST:-glpi-redis} ${REDIS_PORT:-6379} 2>/dev/null; do
    counter=$((counter + 1))
    if [ $counter -ge $max_wait ]; then
        echo "⚠️  Redis not reachable, proceeding..."
        break
    fi
    sleep 1
done

# 3. Redis Configuration
if [ -f "/var/www/glpi/config/config_db.php" ] && [ ! -f "/var/www/glpi/config/local_define.php" ]; then
    echo "⚙️  Configuring Redis in local_define.php..."
    cat > /var/www/glpi/config/local_define.php << EOF
<?php
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
    chown www-data:www-data /var/www/glpi/config/local_define.php
fi

# 4. Smart Permission Check
echo "🔒 Verifying directory ownership..."
for dir in config files plugins marketplace; do
    if [ "$(stat -c '%u' /var/www/glpi/$dir)" != "33" ]; then
        echo "Updating permissions for $dir..."
        chown -R www-data:www-data /var/www/glpi/$dir
    fi
done

# 5. FORCE REWRITE RULES (Crucial for fixing 404)
echo "📝 Ensuring .htaccess routing exists in /public..."
cat > /var/www/glpi/public/.htaccess << 'EOF'
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>
EOF
chown www-data:www-data /var/www/glpi/public/.htaccess

echo "✅ Readiness check passed. Starting Apache..."
exec apache2-foreground
