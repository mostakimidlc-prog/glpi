# GLPI Dockerfile - Meeting Official Prerequisites
FROM php:8.2-apache

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
<<<<<<< HEAD
    && rm -rf /var/lib/apt/lists/*

# Configure and install mandatory PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    # Mandatory extensions
=======
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
>>>>>>> dev-testing
    bcmath \
    gd \
    intl \
    mysqli \
    pdo \
    pdo_mysql \
<<<<<<< HEAD
    # Suggested extensions
=======
>>>>>>> dev-testing
    bz2 \
    exif \
    ldap \
    opcache \
    zip

# Install additional required extensions
RUN pecl install apcu \
    && docker-php-ext-enable apcu

<<<<<<< HEAD
# Enable required PHP modules (dom, fileinfo, filter, etc. are enabled by default)
# Verify they are available
RUN php -m | grep -E 'dom|fileinfo|filter|libxml|simplexml|xmlreader|xmlwriter|curl|openssl|zlib'

=======
>>>>>>> dev-testing
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

<<<<<<< HEAD
# Set working directory
WORKDIR /var/www/html

# Copy GLPI source code
COPY . /var/www/html/

# Create required directories and set permissions
RUN mkdir -p /var/www/html/config \
    /var/www/html/files \
    /var/www/html/marketplace \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html
=======
# Set working directory to GLPI root
WORKDIR /var/www/glpi

# Copy GLPI source code
COPY . /var/www/glpi/

# Install Composer dependencies (PHP only - fast)
RUN if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# Skip npm dependencies during build - will install on container startup
# This avoids timeout issues during Jenkins builds
# Dependencies will be installed via docker-entrypoint.sh

# Configure Apache DocumentRoot to point to /public directory
RUN sed -i 's|/var/www/html|/var/www/glpi/public|g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|/var/www/html|/var/www/glpi/public|g' /etc/apache2/apache2.conf

# Update Apache configuration for GLPI public directory
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
>>>>>>> dev-testing

# Expose port 80
EXPOSE 80

# Health check
<<<<<<< HEAD
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start Apache
CMD ["apache2-foreground"]
=======
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=5 \
    CMD curl -f http://localhost/ || exit 1

# Use custom entrypoint that installs dependencies on startup
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
>>>>>>> dev-testing
