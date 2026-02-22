FROM php:8.2-apache

# 1. Setup Build-time Proxy Arguments
ARG http_proxy
ARG https_proxy
ARG no_proxy

# Set environment variables
ENV http_proxy=$http_proxy
ENV https_proxy=$https_proxy
ENV no_proxy=$no_proxy

# 2. System Dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev \
    libldap2-dev libicu-dev libxml2-dev libbz2-dev \
    libonig-dev libcurl4-openssl-dev \
    unzip git wget curl gnupg gettext netcat-traditional \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# 3. Setup Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 4. Install PHP Extensions (Core)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    bcmath gd intl mysqli pdo pdo_mysql bz2 exif ldap opcache zip

# 5. Install Redis and APCu (The Working PECL Fix)
# We use pear to set the config as it is more forgiving than pecl
RUN if [ -n "$http_proxy" ]; then \
    pear config-set http_proxy "$http_proxy"; \
    fi && \
    pecl install apcu redis && \
    docker-php-ext-enable apcu redis

# 6. Apache Configuration
ENV APACHE_DOCUMENT_ROOT /var/www/glpi/public
RUN a2enmod rewrite headers \
    && sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/000-default.conf \
    && sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf

WORKDIR /var/www/glpi
COPY . /var/www/glpi/

# 7. GLPI Dependencies
RUN npm config set proxy "$http_proxy" && \
    npm config set https-proxy "$https_proxy" && \
    composer install --no-dev --optimize-autoloader --no-interaction

RUN chown -R www-data:www-data /var/www/glpi
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
