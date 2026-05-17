#!/usr/bin/env bash
set -Eeuo pipefail

APP_PATH="${APP_PATH:-}"
ENV_FILE="${ENV_FILE:-}"

[[ -n "${APP_PATH}" ]] || { echo "❌ Missing APP_PATH"; exit 1; }

cd "${APP_PATH}" || { echo "❌ Failed to enter APP_PATH"; exit 1; }
[[ -f artisan ]] || { echo "❌ Artisan file not found"; exit 1; }

env_file () {

    echo "Configuring Env File ..."

    if [[ -n "${ENV_FILE}" ]]; then
        printf '%s' "${ENV_FILE}" | tr -d '\r\n\t ' | base64 -d > .env 2>/dev/null || printf '%s\n' "${ENV_FILE}" > .env
    fi

    [[ -f ".env" ]] && return 0
    cp .env.production .env 2>/dev/null && return 0
    cp .env.example .env 2>/dev/null || { echo "❌ Missing .env file"; exit 1; }

}
install () {

    echo "Installing Dependencies ..."

    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist || { echo "❌ Failed to install composer"; exit 1; }

}
refresh () {

    echo "Refreshing Config ..."

    php artisan config:refresh || true

    php artisan config:clear
    php artisan route:clear
    php artisan view:clear

    php artisan migrate --force || { echo "❌ Failed to run migrate"; exit 1; }
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache

}

env_file
install
refresh

echo "✅ Artisan Configured Successfully."
