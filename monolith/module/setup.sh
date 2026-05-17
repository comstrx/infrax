#!/usr/bin/env bash
set -Eeuo pipefail

PHP_VERSION="${PHP_VERSION:-8.3}"

BASE_TOOLS=(
    rsync
    unzip
    curl
    git
    nginx
    supervisor
    mysql-server
    redis-server
    certbot
    python3-certbot-nginx
    logrotate
    htop
    net-tools
    ufw
    fail2ban
    util-linux
)
EXTRA_TOOLS=(
    phpmyadmin
)
PHP_TOOLS=(
    "php${PHP_VERSION}"
    "php${PHP_VERSION}-cli"
    "php${PHP_VERSION}-mbstring"
    "php${PHP_VERSION}-xml"
    "php${PHP_VERSION}-bcmath"
    "php${PHP_VERSION}-curl"
    "php${PHP_VERSION}-mysql"
    "php${PHP_VERSION}-tokenizer"
    "php${PHP_VERSION}-common"
    "php${PHP_VERSION}-zip"
    "php${PHP_VERSION}-intl"
    "php${PHP_VERSION}-fpm"
    "php${PHP_VERSION}-gd"
    "php${PHP_VERSION}-redis"
    "php${PHP_VERSION}-opcache"
    "php${PHP_VERSION}-readline"

)
SERVICES=(
    "php${PHP_VERSION}-fpm"
    ufw
    fail2ban
    supervisor
    mysql
    redis-server
)

apt_update () {

    sudo apt-get update -qq

}
apt_install () {

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || { echo "❌ Failed to install: $*"; exit 1; }

}
pkg_installed () {

    dpkg -s "${1:-}" >/dev/null 2>&1

}
ensure_base_tools () {

    local tool=""

    for tool in "${BASE_TOOLS[@]}"; do

        if ! pkg_installed "${tool}"; then

            echo "Installing ${tool} ..."
            apt_install "${tool}"

        fi

    done

}
ensure_extra_tools () {

    local tool=""

    for tool in "${EXTRA_TOOLS[@]}"; do

        if ! pkg_installed "${tool}"; then

            echo "Installing ${tool} ..."
            apt_install "${tool}"

        fi

    done

}
ensure_php_tools () {

    command -v php >/dev/null 2>&1 && systemctl is-active --quiet "php${PHP_VERSION}-fpm" && return 0

    echo "Installing PHP ${PHP_VERSION} ..."

    sudo apt-get install -y software-properties-common || { echo "❌ Failed to install software-properties-common"; exit 1; }
    sudo add-apt-repository ppa:ondrej/php -y || { echo "❌ Failed to add PHP repository"; exit 1; }

    apt_update
    apt_install "${PHP_TOOLS[@]}"

}
ensure_composer () {

    local expected="" actual=""

    command -v composer >/dev/null 2>&1 && return 0

    echo "Installing Composer ..."

    expected="$(curl -fsSL https://composer.github.io/installer.sig)" || { echo "❌ Failed to fetch composer signature"; exit 1; }
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" || { echo "❌ Failed to download composer installer"; exit 1; }
    actual="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

    if [[ "${expected}" != "${actual}" ]]; then

        rm -f -- composer-setup.php
        echo "❌ Invalid composer installer signature"
        exit 1

    fi

    php composer-setup.php --quiet || { rm -f -- composer-setup.php; echo "❌ Failed to setup composer"; exit 1; }
    rm -f -- composer-setup.php

    sudo mv -f -- composer.phar /usr/local/bin/composer || { echo "❌ Failed to install composer"; exit 1; }
    sudo chmod +x /usr/local/bin/composer

}
start_services () {

    local service=""

    for service in "${SERVICES[@]}"; do

        if ! systemctl is-active --quiet "${service}"; then

            echo "Starting ${service} ..."
            sudo systemctl enable "${service}" || { echo "❌ Failed to enable ${service}"; exit 1; }
            sudo systemctl start "${service}" || { echo "❌ Failed to start ${service}"; exit 1; }

        fi

    done

}

apt_update

ensure_base_tools
ensure_php_tools
ensure_composer
ensure_extra_tools

start_services

echo "✅ Server Setup Completed Successfully."
