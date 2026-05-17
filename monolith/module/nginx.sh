#!/usr/bin/env bash
set -Eeuo pipefail

SERVER_IP="${SERVER_IP:-}"
CONFIG_DIR="${CONFIG_DIR:-}"
SESSION_ID="${SESSION_ID:-}"

APP_PATH="${APP_PATH:-}"
APP_DOMAIN="${APP_DOMAIN:-}"
APP_RATE_LIMIT="${APP_RATE_LIMIT:-120}"
APP_MAX_BODY_SIZE="${APP_MAX_BODY_SIZE:-256M}"

APP_SOCKET_PORT="${APP_SOCKET_PORT:-8080}"
APP_SOCKET_HOST="${APP_SOCKET_HOST:-http://127.0.0.1:${APP_SOCKET_PORT}}"

APP_ACCESS_LOG="${APP_ACCESS_LOG:-/var/log/nginx/${SESSION_ID}.access.log}"
APP_ERROR_LOG="${APP_ERROR_LOG:-/var/log/nginx/${SESSION_ID}.error.log}"
APP_ACCESS_RULES="${APP_ACCESS_RULES:-}"

PMA_DOMAIN="${PMA_DOMAIN:-}"
PMA_RATE_LIMIT="${PMA_RATE_LIMIT:-60}"
PMA_MAX_BODY_SIZE="${PMA_MAX_BODY_SIZE:-256M}"
PMA_ACCESS_LOG="${PMA_ACCESS_LOG:-/var/log/nginx/phpmyadmin.access.log}"
PMA_ERROR_LOG="${PMA_ERROR_LOG:-/var/log/nginx/phpmyadmin.error.log}"
PMA_ACCESS_RULES="${PMA_ACCESS_RULES:-allow all;}"

PMA_AUTH_USER="${PMA_AUTH_USER:-}"
PMA_AUTH_PASSWORD="${PMA_AUTH_PASSWORD:-}"
PMA_AUTH_RULES=""

ENABLE_APP="${ENABLE_APP:-1}"
ENABLE_PMA="${ENABLE_PMA:-1}"
ENABLE_DEFAULT="${ENABLE_DEFAULT:-1}"

PHP_VERSION="${PHP_VERSION:-8.3}"
PHP_SOCKET="${PHP_SOCKET:-/run/php/php${PHP_VERSION}-fpm.sock}"

FILES=()

[[ -n "${SERVER_IP}"  ]] || { echo "❌ Missing SERVER_IP"; exit 1; }
[[ -n "${CONFIG_DIR}" ]] || { echo "❌ Missing CONFIG_DIR"; exit 1; }
[[ -n "${SESSION_ID}" ]] || { echo "❌ Missing SESSION_ID"; exit 1; }
[[ -n "${APP_PATH}"   ]] || { echo "❌ Missing APP_PATH"; exit 1; }
[[ -n "${APP_DOMAIN}" ]] || { echo "❌ Missing APP_DOMAIN"; exit 1; }

sed_escape () {

    printf '%s' "${1:-}" | sed 's/[&|\\]/\\&/g'

}
is_true () {

    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON|enable|ENABLE|enabled|ENABLED) return 0 ;;
        *) return 1 ;;
    esac

}
set_config () {

    APP_LIMIT_ZONE="app_${SESSION_ID}_auth"
    PMA_LIMIT_ZONE="pma_${SESSION_ID}_auth"

    APP_LIMIT_RULES="limit_req_zone \$binary_remote_addr zone=${APP_LIMIT_ZONE}:10m rate=${APP_RATE_LIMIT}r/m;"
    APP_LIMIT_USE="limit_req zone=${APP_LIMIT_ZONE} burst=$(( APP_RATE_LIMIT * 2 )) nodelay;"

    PMA_LIMIT_RULES="limit_req_zone \$binary_remote_addr zone=${PMA_LIMIT_ZONE}:10m rate=${PMA_RATE_LIMIT}r/m;"
    PMA_LIMIT_USE="limit_req zone=${PMA_LIMIT_ZONE} burst=$(( PMA_RATE_LIMIT * 2 )) nodelay;"

    if [[ -n "${PMA_AUTH_USER}" && -n "${PMA_AUTH_PASSWORD}" ]]; then
        PMA_AUTH_RULES=$'auth_basic "Restricted Access";\n    auth_basic_user_file /etc/nginx/.htpasswd;'
    fi

    for ENTRY in "${FILES[@]}"; do

        TEMPLATE="${ENTRY%%:*}"
        DEST="${ENTRY##*:}"
        DEST_NAME="$(basename "${DEST}")"
        LINK="/etc/nginx/sites-enabled/${DEST_NAME}"

        TMP="$(mktemp)" || { echo "❌ Failed to create tmp file"; exit 1; }

        [[ -f "${TEMPLATE}" ]] || { echo "❌ Missing template: ${TEMPLATE}"; rm -f -- "${TMP}"; exit 1; }

        echo "Generating Nginx Config: ${DEST_NAME}"

        SERVER_IP_SED="$(sed_escape "${SERVER_IP}")"
        APP_PATH_SED="$(sed_escape "${APP_PATH}")"
        APP_DOMAIN_SED="$(sed_escape "${APP_DOMAIN}")"
        APP_LIMIT_RULES_SED="$(sed_escape "${APP_LIMIT_RULES}")"
        APP_LIMIT_USE_SED="$(sed_escape "${APP_LIMIT_USE}")"
        APP_MAX_BODY_SIZE_SED="$(sed_escape "${APP_MAX_BODY_SIZE}")"
        APP_ACCESS_LOG_SED="$(sed_escape "${APP_ACCESS_LOG}")"
        APP_ERROR_LOG_SED="$(sed_escape "${APP_ERROR_LOG}")"
        APP_ACCESS_RULES_SED="$(sed_escape "${APP_ACCESS_RULES}")"
        APP_SOCKET_HOST_SED="$(sed_escape "${APP_SOCKET_HOST}")"
        PHP_SOCKET_SED="$(sed_escape "${PHP_SOCKET}")"
        PMA_DOMAIN_SED="$(sed_escape "${PMA_DOMAIN}")"
        PMA_LIMIT_RULES_SED="$(sed_escape "${PMA_LIMIT_RULES}")"
        PMA_LIMIT_USE_SED="$(sed_escape "${PMA_LIMIT_USE}")"
        PMA_AUTH_RULES_SED="$(sed_escape "${PMA_AUTH_RULES}")"
        PMA_MAX_BODY_SIZE_SED="$(sed_escape "${PMA_MAX_BODY_SIZE}")"
        PMA_ACCESS_LOG_SED="$(sed_escape "${PMA_ACCESS_LOG}")"
        PMA_ERROR_LOG_SED="$(sed_escape "${PMA_ERROR_LOG}")"
        PMA_ACCESS_RULES_SED="$(sed_escape "${PMA_ACCESS_RULES}")"

        sed \
            -e "s|__SERVER_IP__|${SERVER_IP_SED}|g" \
            -e "s|__APP_PATH__|${APP_PATH_SED}|g" \
            -e "s|__APP_DOMAIN__|${APP_DOMAIN_SED}|g" \
            -e "s|__APP_LIMIT_RULES__|${APP_LIMIT_RULES_SED}|g" \
            -e "s|__APP_LIMIT_USE__|${APP_LIMIT_USE_SED}|g" \
            -e "s|__APP_MAX_BODY_SIZE__|${APP_MAX_BODY_SIZE_SED}|g" \
            -e "s|__APP_ACCESS_LOG__|${APP_ACCESS_LOG_SED}|g" \
            -e "s|__APP_ERROR_LOG__|${APP_ERROR_LOG_SED}|g" \
            -e "s|__APP_ACCESS_RULES__|${APP_ACCESS_RULES_SED}|g" \
            -e "s|__APP_SOCKET_HOST__|${APP_SOCKET_HOST_SED}|g" \
            -e "s|__PHP_SOCKET__|${PHP_SOCKET_SED}|g" \
            -e "s|__PMA_DOMAIN__|${PMA_DOMAIN_SED}|g" \
            -e "s|__PMA_LIMIT_RULES__|${PMA_LIMIT_RULES_SED}|g" \
            -e "s|__PMA_LIMIT_USE__|${PMA_LIMIT_USE_SED}|g" \
            -e "s|__PMA_AUTH_RULES__|${PMA_AUTH_RULES_SED}|g" \
            -e "s|__PMA_MAX_BODY_SIZE__|${PMA_MAX_BODY_SIZE_SED}|g" \
            -e "s|__PMA_ACCESS_LOG__|${PMA_ACCESS_LOG_SED}|g" \
            -e "s|__PMA_ERROR_LOG__|${PMA_ERROR_LOG_SED}|g" \
            -e "s|__PMA_ACCESS_RULES__|${PMA_ACCESS_RULES_SED}|g" \
            "${TEMPLATE}" > "${TMP}" || { echo "❌ Failed to generate config: ${DEST_NAME}"; rm -f -- "${TMP}"; exit 1; }

        sudo mv -f -- "${TMP}" "${DEST}" || { echo "❌ Failed to install config: ${DEST_NAME}"; rm -f -- "${TMP}"; exit 1; }
        sudo ln -sfn "${DEST}" "${LINK}" || { echo "❌ Failed to enable config: ${DEST_NAME}"; exit 1; }

    done

}
remove_old () {

    for file in /etc/nginx/sites-available/"${SESSION_ID}"*.conf; do

        [[ -e "${file}" ]] || continue
        keep=0

        for entry in "${FILES[@]}"; do

            dest="${entry##*:}"
            [[ "${file}" == "${dest}" ]] && { keep=1; break; }

        done

        if (( keep == 0 )); then

            link="/etc/nginx/sites-enabled/$(basename "${file}")"
            [[ -L "${link}" ]] && sudo rm -f -- "${link}"
            sudo rm -f -- "${file}"

        fi

    done

    sudo rm -f -- /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

}
restart () {

    if systemctl list-unit-files apache2.service >/dev/null 2>&1; then
        sudo systemctl disable --now apache2 >/dev/null 2>&1 || true
    fi

    sudo nginx -t || { echo "❌ Nginx config test failed"; exit 1; }
    sudo systemctl enable nginx || true

    if systemctl is-active --quiet nginx; then sudo systemctl reload nginx || { echo "❌ Failed to reload nginx"; exit 1; }
    else sudo systemctl start nginx || { echo "❌ Failed to start nginx"; exit 1; }
    fi

}

if is_true "${ENABLE_APP}"; then

    FILES+=( "${CONFIG_DIR}/nginx.app.conf:/etc/nginx/sites-available/${SESSION_ID}-${APP_DOMAIN}.conf" )

fi
if is_true "${ENABLE_PMA}"; then

    if [[ -n "${PMA_DOMAIN}" ]]; then FILES+=( "${CONFIG_DIR}/nginx.pma.conf:/etc/nginx/sites-available/phpmyadmin.conf" )
    else FILES+=( "${CONFIG_DIR}/nginx.pma.local.conf:/etc/nginx/sites-available/phpmyadmin.conf" )
    fi

fi
if is_true "${ENABLE_DEFAULT}"; then

    FILES+=( "${CONFIG_DIR}/nginx.default.conf:/etc/nginx/sites-available/default.conf" )

fi

set_config
remove_old
restart

echo "✅ Nginx Configured Successfully."
