# vtiger CRM 8.4 runtime — PHP 8.3 + Apache, matching the old srv004 stack.
# Site code is NOT baked in: html/ is a bind mount.
FROM php:8.3-apache-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      libpng-dev libjpeg-dev libfreetype6-dev libzip-dev libxml2-dev libxslt1-dev \
      libicu-dev libc-client-dev libkrb5-dev libonig-dev libcurl4-openssl-dev \
      libmagickwand-dev unzip git msmtp ca-certificates cron \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
 && docker-php-ext-install -j"$(nproc)" \
      gd zip xml xsl intl imap mysqli pdo_mysql mbstring curl opcache \
      exif bcmath soap gettext calendar sockets ftp \
 && (pecl install imagick && docker-php-ext-enable imagick || echo "imagick skipped") \
 && a2enmod rewrite headers expires remoteip \
 && rm -rf /var/lib/apt/lists/*

COPY php.ini /usr/local/etc/php/conf.d/zz-vtiger.ini
COPY apache.conf /etc/apache2/conf-enabled/zz-vtiger.conf
