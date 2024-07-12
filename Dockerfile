# This helps keep our Dockerfiles DRY -> https://bit.ly/dry-code
# You can see a list of required extensions for Laravel here: https://laravel.com/docs/11.x/deployment#server-requirements
ARG PHPIZE_DEPS="libpng-dev libjpeg-dev libfreetype6-dev libicu-dev libzip-dev vim git zip unzip libssl-dev wget lsb-release systemctl"
ARG PHP_EXTS="pdo pdo_mysql mysqli zip ftp"
ARG PHP_PECL_EXTS=""
ARG ENV="local"

#-------- --------

# Use the official PHP 8.2 Apache image as the base image
FROM php:8.2-apache

ARG PHPIZE_DEPS
ARG PHP_EXTS
ARG PHP_PECL_EXTS
ARG ENV

# Set the build argument as an environment variable
ENV APP_ENV=${APP_ENV}

# Set the working directory in the container (Contains the composer.json file)
WORKDIR /var/www/html/

# Enable Apache modules
RUN a2enmod rewrite

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y --fix-missing ${PHPIZE_DEPS} ca-certificates \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure ftp --with-openssl-dir=/usr \
    && if [ -n "$PHP_EXTS" ]; then \
        docker-php-ext-install -j$(nproc) ${PHP_EXTS}; \
    fi \
    && if [ -n "$PHP_PECL_EXTS" ]; then \
        pecl install ${PHP_PECL_EXTS} \
        && docker-php-ext-enable ${PHP_PECL_EXTS}; \
    fi

# Install Node.js
RUN curl -sL https://deb.nodesource.com/setup_current.x | bash -
RUN apt-get install -y nodejs

# Clean up apt-get cache
RUN if [ "$APP_ENV" != "local" ]; then \
    apt-get clean; \
    fi

# Install Composer (PHP package manager)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy the application files to the container
COPY . /var/www/html/
COPY php.ini /usr/local/etc/php/php.ini

ENV COMPOSER_ALLOW_SUPERUSER=1

# Install dependencies using Composer
RUN composer install --no-dev --optimize-autoloader --ignore-platform-reqs

# Conditional copying based on build argument
RUN if [ "$ENV" = "dev" ]; then \
        cp .env.dev .env; \
    elif [ "$ENV" = "prod" ]; then \
        cp .env.prod .env; \
    fi

# Generate application key
RUN php artisan key:generate

# NodeJS Packages
RUN npm update && npm run build

# Storage link
RUN php artisan storage:link --force

# Clear cached bootstrap files
RUN php artisan clear-compiled
RUN php artisan config:clear
RUN php artisan event:clear
RUN php artisan route:clear
RUN php artisan view:clear

RUN if [ "$APP_ENV" = "local" ]; then \
    groupadd --force -g $WWWGROUP sail; \
    useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 sail; \
    fi

# Setting file permissions to run Laravel
RUN chown -R www-data:www-data /var/www/html/

