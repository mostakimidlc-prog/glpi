# GLPI Dockerfile - Stable 11.0.5 Release (Proxy-Aware)
FROM php:8.2-apache

# --- PROXY CONFIGURATION START ---
# Declare build arguments passed from Jenkins or CLI
ARG http_proxy
ARG https_proxy
ARG no_proxy

# Set environment variables for the build process
# Tools like apt, curl, npm, and composer will detect these automatically
ENV http_proxy=$http_proxy
ENV https_proxy=$https_proxy
ENV no_proxy=$no_proxy
# --- PROXY CONFIGURATION END ---

# 1. Install system dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libldap2-dev \
    libicu-dev \
    libxml2-dev \
    libbz2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    unzip \
    git \
    wget \
    curl \
    gnupg \
    gettext \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js 20.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 4. Configure and install mandatory PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    bcmath \
    gd \
    intl \
    mysqli \
    pdo \
    pdo_mysql \
    bz2 \
    exif \
    ldap \
    opcache \
    zip

# 5. Install Redis and APCu extensions for caching
# PECL requires manual proxy configuration via pear
RUN if [ ! -z "$http_proxy" ]; then \
        pear config-set http_proxy $http_proxy; \
    fi \
    && pecl install apcu redis \
    && docker-php-ext-enable apcu redis

# 6. Configure PHP for GLPI Stable Performance
RUN { \
    echo 'memory_limit = 512M'; \
    echo 'file_uploads = On'; \
    echo 'max_execution_time = 600'; \
    echo 'session.auto_start = Off'; \
    echo 'session.use_trans_sid = 0'; \
    echo 'post_max_size = 100M'; \
    echo 'upload_max_filesize = 100M'; \
    echo 'max_input_vars = 5000'; \
    echo 'date.timezone = UTC'; \
    } > /usr/local/etc/php/conf.d/glpi.ini

# 7. Configure Zend OPcache
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=2'; \
    } > /usr/local/etc/php/conf.d/opcache.ini

# 8. Enable Apache modules
RUN a2enmod rewrite headers ssl

# 9. Set working directory
WORKDIR /var/www/glpi

# 10. Copy GLPI source code
COPY . /var/www/glpi/

# 11. Install Composer dependencies
# Note: Composer uses the ENV http_proxy variables set above automatically.
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# 12. Configure Apache DocumentRoot to point to /public
RUN sed -i 's|/var/www/html|/var/www/glpi/public|g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|/var/www/html|/var/www/glpi/public|g' /etc/apache2/apache2.conf

# 13. Update Apache Directory permissions
RUN echo '<Directory /var/www/glpi/public>' >> /etc/apache2/apache2.conf \
    && echo '    Options -Indexes +FollowSymLinks' >> /etc/apache2/apache2.conf \
    && echo '    AllowOverride All' >> /etc/apache2/apache2.conf \
    && echo '    Require all granted' >> /etc/apache2/apache2.conf \
    && echo '</Directory>' >> /etc/apache2/apache2.conf

# 14. Create required directories and enforce ownership
RUN mkdir -p /var/www/glpi/config \
    /var/www/glpi/files \
    /var/www/glpi/marketplace \
    /var/www/glpi/plugins \
    && chown -R www-data:www-data /var/www/glpi \
    && chmod -R 755 /var/www/glpi

# 15. Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 16. Expose internal port 80
EXPOSE 80

# 17. Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -f http://localhost/status.php || curl -f http://localhost/ || exit 1

# 18. Execution
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
