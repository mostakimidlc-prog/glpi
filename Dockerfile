# GLPI Dockerfile - Meeting Official Prerequisites
FROM php:8.2-apache

# --- PROXY CONFIGURATION START ---
# Declare build arguments passed from Jenkins
ARG http_proxy
ARG https_proxy
ARG no_proxy

# Set environment variables for the build process (apt, curl, etc.)
ENV http_proxy=$http_proxy
ENV https_proxy=$https_proxy
ENV no_proxy=$no_proxy
# --- PROXY CONFIGURATION END ---

# Install system dependencies
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
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configure and install mandatory PHP extensions
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

# Install Redis and APCu extensions
# Using -d avoids the 'config-set' channel validation error
RUN pear config-set http_proxy "$http_proxy" \
    && pecl install apcu redis \
    && docker-php-ext-enable apcu redis

# Configure PHP for GLPI
RUN { \
    echo 'memory_limit = 256M'; \
    echo 'file_uploads = On'; \
    echo 'max_execution_time = 600'; \
    echo 'session.auto_start = Off'; \
    echo 'session.use_trans_sid = 0'; \
    echo 'post_max_size = 100M'; \
    echo 'upload_max_filesize = 100M'; \
    echo 'max_input_vars = 5000'; \
    } > /usr/local/etc/php/conf.d/glpi.ini

# Configure Zend OPcache for performance
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    } > /usr/local/etc/php/conf.d/opcache.ini

# Enable Apache modules
RUN a2enmod rewrite headers ssl

# Set working directory to GLPI root
WORKDIR /var/www/glpi

# Copy GLPI source code
COPY . /var/www/glpi/

# Install Composer dependencies
# Composer respects the http_proxy env variable automatically
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# Configure Apache DocumentRoot
RUN sed -i 's|/var/www/html|/var/www/glpi/public|g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|/var/www/html|/var/www/glpi/public|g' /etc/apache2/apache2.conf

# Update Apache configuration
RUN echo '<Directory /var/www/glpi/public>' >> /etc/apache2/apache2.conf \
    && echo '    Options Indexes FollowSymLinks' >> /etc/apache2/apache2.conf \
    && echo '    AllowOverride All' >> /etc/apache2/apache2.conf \
    && echo '    Require all granted' >> /etc/apache2/apache2.conf \
    && echo '</Directory>' >> /etc/apache2/apache2.conf

# Create required directories and set permissions
RUN mkdir -p /var/www/glpi/config \
    /var/www/glpi/files \
    /var/www/glpi/marketplace \
    && chown -R www-data:www-data /var/www/glpi \
    && chmod -R 755 /var/www/glpi

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -f http://localhost/status.php || curl -f http://localhost/ || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
