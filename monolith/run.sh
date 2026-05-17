#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

export CONFIG_DIR="${CONFIG_DIR:-${SCRIPT_DIR}/config}"
export MODULE_DIR="${MODULE_DIR:-${SCRIPT_DIR}/module}"
export START_TIME="${SECONDS}"

export SERVER_IP="${SERVER_IP:-}"
export APP_DOMAIN="${APP_DOMAIN:-}"
export PMA_DOMAIN="${PMA_DOMAIN:-}"

export APP_NAME="${APP_NAME:-}"
export APP_ID="${APP_ID:-${APP_NAME}}"

export GIT_REPO="${GIT_REPO:-}"
export GIT_BRANCH="${GIT_BRANCH:-main}"
export GIT_SSH_KEY="${GIT_SSH_KEY:-}"

export INNER_PATH="${INNER_PATH:-${GIT_INNER_PATH:-}}"
export APP_DIR="${APP_DIR:-${INNER_PATH:-server}}"
export STORAGE_DIR="${STORAGE_DIR:-storage}"

export ROOT_PATH="${ROOT_PATH:-/var/www/${APP_NAME}}"
export APP_PATH="${APP_PATH:-${ROOT_PATH}/${APP_DIR}}"
export STORAGE_PATH="${STORAGE_PATH:-${ROOT_PATH}/${STORAGE_DIR}}"

export DB_NAME="${DB_NAME:-}"
export DB_USER="${DB_USER:-user}"
export DB_PASSWORD="${DB_PASSWORD:-}"

export PHP_VERSION="${PHP_VERSION:-8.3}"
export UPLOAD_SIZE="${UPLOAD_SIZE:-256M}"
export MEMORY_LIMIT="${MEMORY_LIMIT:-512M}"
export INPUT_TIMEOUT="${INPUT_TIMEOUT:-300}"

export ENV_FILE="${ENV_FILE:-}"
export SESSION_ID="${SESSION_ID:-${APP_ID:-${APP_NAME:-deploy}}}"

die () {

    printf '❌ %s\n' "$*"
    exit 1

}
ensure () {

    local bin="${1:-}"
    local package="${2:-${bin}}"

    if ! command -v "${bin}" >/dev/null 2>&1; then
        sudo apt-get update -qq || die "Failed to update apt"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${package}" || die "Failed to install ${bin}"
    fi

}
lock () {

    ensure flock util-linux

    exec 9>"/tmp/${SESSION_ID}.deploy.lock"
    flock -n 9 || die "Deployment already running"

}
enter () {

    mkdir -p "${ROOT_PATH}" 2>/dev/null || sudo mkdir -p "${ROOT_PATH}"
    chown -R "$(id -un):$(id -gn)" "${ROOT_PATH}" 2>/dev/null || sudo chown -R "$(id -un):$(id -gn)" "${ROOT_PATH}"

    cd "${ROOT_PATH}" || die "Failed to enter root path: ${ROOT_PATH}"

}
run_module () {

    local file="${1:-}"
    [[ -f "${file}" ]] || die "Missing module: ${file}"

    chmod +x "${file}" 2>/dev/null || sudo chmod +x "${file}" || die "Cannot chmod module: ${file}"
    "${file}"

}
workflow () {

    run_module "${MODULE_DIR}/setup.sh"
    run_module "${MODULE_DIR}/nginx.sh"

    run_module "${MODULE_DIR}/ufw.sh"
    run_module "${MODULE_DIR}/ssl.sh"
    run_module "${MODULE_DIR}/fail2ban.sh"

    run_module "${MODULE_DIR}/database.sh"
    run_module "${MODULE_DIR}/redis.sh"

    run_module "${MODULE_DIR}/github.sh"

    run_module "${MODULE_DIR}/storage.sh"
    run_module "${MODULE_DIR}/artisan.sh"

    run_module "${MODULE_DIR}/job.sh"

}
validate () {

    [[ -n "${SERVER_IP}"   ]] || die "Missing SERVER_IP"
    [[ -n "${APP_DOMAIN}"  ]] || die "Missing APP_DOMAIN"
    [[ -n "${APP_NAME}"    ]] || die "Missing APP_NAME"
    [[ -n "${GIT_REPO}"    ]] || die "Missing GIT_REPO"
    [[ -n "${GIT_BRANCH}"  ]] || die "Missing GIT_BRANCH"
    [[ -n "${GIT_SSH_KEY}" ]] || die "Missing GIT_SSH_KEY"
    [[ -n "${DB_NAME}"     ]] || die "Missing DB_NAME"
    [[ -n "${DB_USER}"     ]] || die "Missing DB_USER"
    [[ -n "${DB_PASSWORD}" ]] || die "Missing DB_PASSWORD"

}
main () {

    echo "🚀 Starting Deployment ..."

    validate
    lock
    enter
    workflow

    echo "✅ Deployment Complete In $((SECONDS - START_TIME)) Sec."

}

main

# Remain :
# -----------------
# backup
# rollback
# healthcheck
# logrotate
# laravel octane
# millisearch/elasticsearch
# postgresql/pgAdmin
