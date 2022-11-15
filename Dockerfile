FROM ubuntu:22.04

# Build args
ARG RUNTIME_UID=1000
ARG RUNTIME_GID=1000
ARG RUNTIME_WORKDIR=/www/app
ARG RUNTIME_USERDIR=/home/app

ARG PHP_VERSION='8.0'
ARG S6_OVERLAY_VERSION='3.1.2.1'

# Environment
ENV RUNTIME_UID=${RUNTIME_UID} \
    RUNTIME_GID=${RUNTIME_GID} \
    RUNTIME_WORKDIR=${RUNTIME_WORKDIR} \
    RUNTIME_USERDIR=${RUNTIME_USERDIR} \
    PHP_VERSION=${PHP_VERSION} \
    PHP_POOL_NAME="www" \
    PHP_DATE_TIMEZONE="UTC" \
    PHP_DISPLAY_ERRORS=Off \
    PHP_DISPLAY_STARTUP_ERRORS=Off \
    PHP_ERROR_REPORTING="22527" \
    PHP_MEMORY_LIMIT="256M" \
    PHP_MAX_EXECUTION_TIME="99" \
    PHP_OPEN_BASEDIR="$RUNTIME_WORKDIR:/dev/stdout:/tmp" \
    PHP_POST_MAX_SIZE="100M" \
    PHP_UPLOAD_MAX_FILE_SIZE="100M" \
    PHP_PM_CONTROL="dynamic" \
    PHP_PM_MAX_CHILDREN="20" \
    PHP_PM_START_SERVERS="2" \
    PHP_PM_MIN_SPARE_SERVERS="1" \
    PHP_PM_MAX_SPARE_SERVERS="3"

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
RUN groupadd -r -g $RUNTIME_GID app \
    && useradd --no-log-init -r -s /usr/bin/bash -m -d $RUNTIME_USERDIR -u $RUNTIME_UID -g $RUNTIME_GID app

# Install Packages
ADD install-packages /usr/bin/install-packages
ADD packages/${PHP_VERSION}.txt /tmp/packages.txt

RUN add-apt-repository ppa:ondrej/php \
    && mkdir -p /etc/php/current \
    && ln -sf /etc/php/current /etc/php/${PHP_VERSION} \
    && ln -sf /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm \
    && install-packages \
    $(cat /tmp/packages.txt) \
    curl nano msmtp nginx

# Install Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php \
    && mv composer.phar /usr/local/bin/composer \
    && php -r "unlink('composer-setup.php');" \
    && composer --version

# Install WPCLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp \
    && wp --allow-root --version

# Config
COPY rootfs /

RUN ln -sf ${RUNTIME_WORKDIR} ${RUNTIME_USERDIR}/www \
    && chown -R app:app ${RUNTIME_WORKDIR} ${RUNTIME_USERDIR}

WORKDIR ${RUNTIME_WORKDIR}

ENTRYPOINT ["/init"]