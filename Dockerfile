ARG IMAGE='nginx'

# ---- BASE IMAGE ---- #
FROM ubuntu:22.04 AS base

# Build args
ARG PHP_VERSION='8.0'
ARG S6_OVERLAY_VERSION='3.1.5.0'

# Environment
ENV RUNTIME_SSH=false \
    RUNTIME_USER=app \
    RUNTIME_GROUP=app \
    RUNTIME_UID=1000 \
    RUNTIME_GID=1000 \
    RUNTIME_WORKDIR=/www/app \
    RUNTIME_WELCOME=false \
    S6_KEEP_ENV=1 \
    S6_VERBOSITY=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    PHP_VERSION=${PHP_VERSION}

# Install Packages Script
ADD install-packages /usr/bin/install-packages

#  Base Packages
RUN install-packages \
    gnupg2 \
    ca-certificates \
    software-properties-common \
    gpg-agent \
    xz-utils \
    python3-pip \
    openssh-server \
    mariadb-client \
    msmtp \
    unzip \
    nano \
    curl \
    less

# S6 Overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# User
RUN groupadd -r -g ${RUNTIME_GID} ${RUNTIME_GROUP} \
    && useradd --no-log-init -r -s /usr/bin/bash -m -d ${RUNTIME_WORKDIR} -u ${RUNTIME_UID} -g ${RUNTIME_GID} ${RUNTIME_USER}

# ---- NGINX IMAGE ---- #
FROM base AS nginx

ENV RUNTIME_SERVER=nginx

ADD packages/php-${PHP_VERSION}.txt /tmp/packages.txt

RUN add-apt-repository ppa:ondrej/php \
    && mkdir -p /etc/php/current \
    && ln -sf /etc/php/current /etc/php/${PHP_VERSION} \
    && ln -sf /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm \
    && install-packages \
    $(cat /tmp/packages.txt) \
    nginx

RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/nginx

ENV RUNTIME_CMD="php-fpm -F"

# ---- OPENLITESPEED IMAGE ---- #
FROM base AS openlitespeed

ENV RUNTIME_SERVER=openlitespeed

ADD packages/lsphp-${PHP_VERSION}.txt /tmp/packages.txt

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 011AA62DEDA1F085 \
    && curl -s http://rpms.litespeedtech.com/debian/enable_lst_debian_repo.sh | bash \
    && install-packages \
      openlitespeed \
      $(cat /tmp/packages.txt) \
    && mkdir -p /etc/php \
    && export LSPHP_VERSION=$(echo $PHP_VERSION | sed s/[.]//g) \
    && ln -sf /usr/local/lsws/lsphp$LSPHP_VERSION /etc/php/current  \
    && ln -sf /usr/local/lsws/lsphp$LSPHP_VERSION/bin/php /usr/local/bin/php

ENV RUNTIME_CMD="/usr/local/lsws/bin/openlitespeed -d"

# ---- FINAL IMAGE ---- #
FROM ${IMAGE} AS final

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

# Install j2cli
RUN pip install j2cli

# Config
RUN rm -rf /etc/update-motd.d/*

COPY rootfs /

RUN chown -R ${RUNTIME_USER}:${RUNTIME_GROUP} ${RUNTIME_WORKDIR}

WORKDIR ${RUNTIME_WORKDIR}/public

EXPOSE 80

ENTRYPOINT ["/init"]

CMD $RUNTIME_CMD
