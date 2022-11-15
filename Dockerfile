FROM ubuntu:22.04

ARG CONTAINER_USER_ID=1000
ARG CONTAINER_GROUP_ID=1000
ARG CONTAINER_WORKDIR=/var/www/html

ARG PHP_VERSION='8.0'
ARG S6_OVERLAY_VERSION=3.1.2.1

ENV DEBIAN_FRONTEND=noninteractive \
    PHP_DATE_TIMEZONE="UTC" \
    PHP_DISPLAY_ERRORS=Off \
    PHP_DISPLAY_STARTUP_ERRORS=Off \
    PHP_ERROR_REPORTING="22527" \
    PHP_MEMORY_LIMIT="256M" \
    PHP_MAX_EXECUTION_TIME="99" \
    PHP_OPEN_BASEDIR="$CONTAINER_WORKDIR:/dev/stdout:/tmp" \
    PHP_POST_MAX_SIZE="100M" \
    PHP_UPLOAD_MAX_FILE_SIZE="100M" \
    PHP_POOL_NAME="www" \
    PHP_PM_CONTROL="dynamic" \
    PHP_PM_MAX_CHILDREN="20" \
    PHP_PM_START_SERVERS="2" \
    PHP_PM_MIN_SPARE_SERVERS="1" \
    PHP_PM_MAX_SPARE_SERVERS="3" \
    COMPOSER_HOME=/composer

#  Base Packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    gnupg2 \
    ca-certificates \
    software-properties-common \
    gpg-agent \
    xz-utils

# S6 Overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# User
RUN groupadd -r -g $CONTAINER_GROUP_ID webgroup \
    && useradd --no-log-init -r -s /usr/bin/bash -d $CONTAINER_WORKDIR -u $CONTAINER_USER_ID -g $CONTAINER_GROUP_ID webuser

# Install Packages
ADD packages/${PHP_VERSION}.txt /tmp/packages.txt
RUN add-apt-repository ppa:ondrej/php \
    && mkdir -p /etc/php/current \
    && ln -sf /etc/php/current /etc/php/${PHP_VERSION} \
    && ln -sf /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm \
    && apt-get install -y --no-install-recommends \
    $(cat /tmp/packages.txt) \
    nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /var/www/html/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Filesystem
COPY rootfs /

RUN mkdir /run/php

WORKDIR ${CONTAINER_WORKDIR}

ENTRYPOINT ["/init"]