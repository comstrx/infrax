#!/usr/bin/env bash
set -Eeuo pipefail

REDIS_PASSWORD="${REDIS_PASSWORD:-}"

set_password () {

    echo "Setup Redis Password ..."

    if [[ -n "${REDIS_PASSWORD}" ]]; then

        PASSWORD="$(printf '%s' "${REDIS_PASSWORD}" | sed 's/[&/\|\\]/\\&/g')"

        if sudo grep -qE '^[[:space:]]*#?[[:space:]]*requirepass[[:space:]]+' /etc/redis/redis.conf; then
            sudo sed -i "s|^[[:space:]]*#\?[[:space:]]*requirepass[[:space:]].*|requirepass ${PASSWORD}|" /etc/redis/redis.conf
        else
            printf 'requirepass %s\n' "${REDIS_PASSWORD}" | sudo tee -a /etc/redis/redis.conf >/dev/null
        fi

    else
        sudo sed -i '/^[[:space:]]*#\?[[:space:]]*requirepass[[:space:]]\+/d' /etc/redis/redis.conf
    fi

}
restart () {

    sudo systemctl restart redis-server || { echo "❌ Failed to restart redis-server"; exit 1; }

}

set_password
restart

echo "✅ Redis Configured Successfully."
