FROM ubuntu:22.04

# Build args
ARG RUNTIME_UID=1000
ARG RUNTIME_GID=1000
ARG RUNTIME_WORKDIR=/www/app
ARG PHP_VERSION='8.0'
ARG S6_OVERLAY_VERSION='3.1.2.1'

# Environment
ENV RUNTIME_UID=${RUNTIME_UID} \
    RUNTIME_GID=${RUNTIME_GID} \
    RUNTIME_WORKDIR=${RUNTIME_WORKDIR} \
    S6_KEEP_ENV=1 \
    S6_VERBOSITY=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    PHP_VERSION=${PHP_VERSION}

#  Base Packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    gnupg2 \
    ca-certificates \
    software-properties-common \
    gpg-agent \
    xz-utils \
    python3-pip

# S6 Overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# User
RUN groupadd -r -g $RUNTIME_GID app \
    && useradd --no-log-init -r -s /usr/bin/bash -m -d $RUNTIME_WORKDIR -u $RUNTIME_UID -g $RUNTIME_GID app

# Install Packages
ADD install-packages /usr/bin/install-packages
ADD packages/${PHP_VERSION}.txt /tmp/packages.txt

RUN add-apt-repository ppa:ondrej/php \
    && mkdir -p /etc/php/current \
    && ln -sf /etc/php/current /etc/php/${PHP_VERSION} \
    && ln -sf /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm \
    && install-packages \
    $(cat /tmp/packages.txt) \
    curl nano unzip msmtp nginx mariadb-client

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
COPY rootfs /

RUN chown -R app:app ${RUNTIME_WORKDIR}

WORKDIR ${RUNTIME_WORKDIR}/public

EXPOSE 80

ENTRYPOINT ["/init"]

CMD ["php-fpm", "-F"]
