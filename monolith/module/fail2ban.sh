#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="${CONFIG_DIR:-}"
F2B_BANTIME="${F2B_BANTIME:-24h}"
F2B_FINDTIME="${F2B_FINDTIME:-10m}"
F2B_MAXRETRY="${F2B_MAXRETRY:-5}"

F2B_SSHD_ENABLED="${F2B_SSHD_ENABLED:-1}"
F2B_RECIDIVE_ENABLED="${F2B_RECIDIVE_ENABLED:-1}"
F2B_NGINX_ENABLED="${F2B_NGINX_ENABLED:-1}"
F2B_MYSQL_ENABLED="${F2B_MYSQL_ENABLED:-1}"
F2B_MYSQL_PORT="${F2B_MYSQL_PORT:-3306}"

[[ -n "${CONFIG_DIR}" ]] || { echo "❌ Missing CONFIG_DIR"; exit 1; }
[[ -f "${CONFIG_DIR}/fail2ban.conf" ]] || { echo "❌ Missing fail2ban config"; exit 1; }

sed_escape () {

    printf '%s' "${1:-}" | sed 's/[&|\\]/\\&/g'

}
bool_word () {

    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON|enable|ENABLE|enabled|ENABLED) printf 'true' ;;
        *) printf 'false' ;;
    esac

}
set_config () {

    echo "Configuring fail2ban ..."

    F2B_BANTIME_SED="$(sed_escape "${F2B_BANTIME}")"
    F2B_FINDTIME_SED="$(sed_escape "${F2B_FINDTIME}")"
    F2B_MAXRETRY_SED="$(sed_escape "${F2B_MAXRETRY}")"
    F2B_SSHD_ENABLED_SED="$(bool_word "${F2B_SSHD_ENABLED}")"
    F2B_RECIDIVE_ENABLED_SED="$(bool_word "${F2B_RECIDIVE_ENABLED}")"
    F2B_NGINX_ENABLED_SED="$(bool_word "${F2B_NGINX_ENABLED}")"
    F2B_MYSQL_ENABLED_SED="$(bool_word "${F2B_MYSQL_ENABLED}")"
    F2B_MYSQL_PORT_SED="$(sed_escape "${F2B_MYSQL_PORT}")"

    sed \
        -e "s|__F2B_BANTIME__|${F2B_BANTIME_SED}|g" \
        -e "s|__F2B_FINDTIME__|${F2B_FINDTIME_SED}|g" \
        -e "s|__F2B_MAXRETRY__|${F2B_MAXRETRY_SED}|g" \
        -e "s|__F2B_SSHD_ENABLED__|${F2B_SSHD_ENABLED_SED}|g" \
        -e "s|__F2B_RECIDIVE_ENABLED__|${F2B_RECIDIVE_ENABLED_SED}|g" \
        -e "s|__F2B_NGINX_ENABLED__|${F2B_NGINX_ENABLED_SED}|g" \
        -e "s|__F2B_MYSQL_ENABLED__|${F2B_MYSQL_ENABLED_SED}|g" \
        -e "s|__F2B_MYSQL_PORT__|${F2B_MYSQL_PORT_SED}|g" \
        "${CONFIG_DIR}/fail2ban.conf" | sudo tee "/etc/fail2ban/jail.local" >/dev/null

    sudo fail2ban-client -t || { echo "❌ Invalid fail2ban config"; exit 1; }

}
restart () {

    sudo systemctl enable fail2ban

    sudo systemctl restart fail2ban || {
        sudo journalctl -u fail2ban --no-pager -n 80 || true
        echo "❌ Failed to restart fail2ban"; exit 1
    }

    for _ in {1..10}; do
        sudo fail2ban-client ping >/dev/null 2>&1 && break
        sleep 1
    done

    sudo fail2ban-client ping >/dev/null 2>&1 || {
        sudo journalctl -u fail2ban --no-pager -n 80 || true
        echo "❌ Fail2ban is not running"; exit 1
    }

    sudo fail2ban-client status sshd || true

}

set_config
restart

echo "✅ Fail2ban Configured Successfully."
