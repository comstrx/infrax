#!/usr/bin/env bash
set -Eeuo pipefail

APP_DOMAIN="${APP_DOMAIN:-}"
PMA_DOMAIN="${PMA_DOMAIN:-}"
SSL_EMAIL="${SSL_EMAIL:-admin@${APP_DOMAIN}}"
FORCE_SSL="${FORCE_SSL:-0}"

[[ -n "${APP_DOMAIN}" ]] || { echo "❌ Missing APP_DOMAIN"; exit 1; }
[[ -n "${SSL_EMAIL}"  ]] || { echo "❌ Missing SSL_EMAIL"; exit 1; }

cert_exists () {

    local domain="${1:-}"

    [[ -n "${domain}" ]] || return 1
    [[ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]] &&
    [[ -f "/etc/letsencrypt/live/${domain}/privkey.pem" ]]

}
issue_cert () {

    local domain="${1:-}"

    [[ -n "${domain}" ]] || return 0

    if cert_exists "${domain}" && [[ "${FORCE_SSL}" != "1" ]]; then
        echo "SSL certificate already exists for ${domain}"
        return 0
    fi

    echo "Setup SSL for ${domain} ..."

    sudo certbot --nginx \
        --non-interactive \
        --agree-tos \
        --redirect \
        --email "${SSL_EMAIL}" \
        -d "${domain}" \
        || { echo "❌ Failed to setup SSL for ${domain}"; exit 1; }

}
set_certbot () {

    echo "Configuring SSL ..."

    sudo nginx -t || { echo "❌ Nginx config test failed"; exit 1; }

    issue_cert "${APP_DOMAIN}"
    issue_cert "${PMA_DOMAIN}"

    sudo certbot update_account --non-interactive --email "${SSL_EMAIL}" || true
    sudo systemctl enable --now certbot.timer || true

}

set_certbot

echo "✅ SSL Configured Successfully."
