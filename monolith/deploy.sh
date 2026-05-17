#!/usr/bin/env bash
set -Eeuo pipefail

JSON_ENV="${JSON_ENV:-}"
SCRIPT_DIR=".github/scripts"
ENTRY_FILE="run.sh"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_PATH="${DEPLOY_PATH:-"$(mktemp -d)/deploy-scripts"}"

TEMP_FILE="$(mktemp)"
TEMP_ENV="$(mktemp)"
REMOTE_ENV="${TEMP_ENV}"
KEY_FILE="${HOME}/.ssh/deploy.pem"

SSH_BASE=()
SCP_BASE=()

die () {

    printf '❌ %s\n' "$*"
    exit 1

}
quote () {

    printf '%q' "${1:-}"

}
cleanup () {

    rm -f "${TEMP_FILE}" "${TEMP_ENV}" "${KEY_FILE}"

}
ensure () {

    local bin="${1:-}"
    local package="${2:-${bin}}"

    if ! command -v "${bin}" >/dev/null 2>&1; then
        sudo apt-get update -qq || die "Failed to update apt"
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${package}" || die "Failed to install ${bin}"
    fi

}
load_env () {

    local item="" obj="" key="" val=""

    [[ -n "${JSON_ENV:-}" ]] || die "Missing JSON_ENV"

    ensure jq
    ensure base64 coreutils

    while IFS= read -r item; do

        [[ -n "${item}" ]] || continue

        obj="$(printf '%s' "${item}" | base64 -d)"    || continue
        key="$(jq -r '.key // empty' <<< "${obj}")"   || continue
        val="$(jq -r '.value // empty' <<< "${obj}")" || continue

        [[ -n "${key}" && "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        printf -v "${key}" '%s' "${val}"
        export "${key?}"

    done < <(jq -r 'to_entries[] | select(.value != null) | @base64' <<< "${JSON_ENV}")

}
validate_env () {

    [[ -n "${SERVER_IP:-}" ]] || die "Missing SERVER_IP"
    [[ -n "${SERVER_SSH_USER:-}" ]] || die "Missing SERVER_SSH_USER"
    [[ -n "${SERVER_SSH_KEY:-}" || -n "${SERVER_SSH_PASSWORD:-}" ]] || die "Missing SERVER_SSH_KEY or SERVER_SSH_PASSWORD"

}
build_env () {

    local file="${TEMP_ENV}" name="" value=""

    umask 077

    : > "${file}" || die "Invalid local env file: ${file}"
    chmod 600 "${file}" || die "Cannot chmod 600 for: ${file}"

    while IFS= read -r name; do

        case "${name}" in
            JSON_ENV|HOME|USER|USERNAME|LOGNAME|SHELL|PWD|OLDPWD|PATH|SHLVL|_ ) continue ;;
        esac

        [[ "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        value="${!name-}"
        printf 'export %s=%q\n' "${name}" "${value}" >> "${file}" || die "Cannot export env key: ${name}"

    done < <(compgen -e)

}
send_env () {

    local dir=""

    dir="$(dirname -- "${REMOTE_ENV}")"

    "${SSH_BASE[@]}" "${SERVER_SSH_USER}@${SERVER_IP}" "
        mkdir -p $(quote "${dir}") 2>/dev/null || sudo mkdir -p $(quote "${dir}")
        sudo chown -R $(quote "${SERVER_SSH_USER}:${SERVER_SSH_USER}") $(quote "${dir}")
    " || die "Cannot mkdir for remote env file"

    "${SCP_BASE[@]}" "${TEMP_ENV}" "${SERVER_SSH_USER}@${SERVER_IP}:${REMOTE_ENV}" || die "Cannot send env file"

    rm -f -- "${TEMP_ENV}"

}
send_script () {

    tar -C "${ROOT_DIR}" -czf "${TEMP_FILE}" "${SCRIPT_DIR}" || die "Cannot create archive script: ${SCRIPT_DIR}"

    "${SSH_BASE[@]}" "${SERVER_SSH_USER}@${SERVER_IP}" "

        set -Eeuo pipefail

        mkdir -p $(quote "${DEPLOY_PATH}") 2>/dev/null || sudo mkdir -p $(quote "${DEPLOY_PATH}")
        sudo chown -R $(quote "${SERVER_SSH_USER}:${SERVER_SSH_USER}") $(quote "${DEPLOY_PATH}")

        rm -rf $(quote "${DEPLOY_PATH}/${SCRIPT_DIR}")

        tar xzf - -C $(quote "${DEPLOY_PATH}")

        chmod 600 $(quote "${REMOTE_ENV}")

        set -a
        . $(quote "${REMOTE_ENV}")
        set +a

        rm -f $(quote "${REMOTE_ENV}")

        chmod +x $(quote "${DEPLOY_PATH}/${SCRIPT_DIR}/${ENTRY_FILE}")

        $(quote "${DEPLOY_PATH}/${SCRIPT_DIR}/${ENTRY_FILE}")

    " < "${TEMP_FILE}" || die "Cannot run remote script"

}
connection () {

    mkdir -p "${HOME}/.ssh" || die "Cannot mkdir: ${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh" 2>/dev/null || true

    SSH_BASE=( ssh -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ServerAliveCountMax=6 -o ConnectTimeout=20 )
    SCP_BASE=( scp -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ServerAliveCountMax=6 -o ConnectTimeout=20 )

    if [[ -n "${SERVER_SSH_KEY:-}" ]]; then

        printf '%s' "${SERVER_SSH_KEY}" | tr -d '\r\n\t ' | base64 -d > "${KEY_FILE}" 2>/dev/null \
            || printf '%s\n' "${SERVER_SSH_KEY}" > "${KEY_FILE}"

        chmod 600 "${KEY_FILE}" || die "Cannot chmod 600 for: ${KEY_FILE}"

        SSH_BASE+=( -i "${KEY_FILE}" -o IdentitiesOnly=yes -o BatchMode=yes )
        SCP_BASE+=( -i "${KEY_FILE}" -o IdentitiesOnly=yes -o BatchMode=yes )

        return 0

    fi
    if [[ -n "${SERVER_SSH_PASSWORD:-}" ]]; then

        ensure sshpass

        SSH_BASE=( sshpass -p "${SERVER_SSH_PASSWORD}" "${SSH_BASE[@]}" )
        SCP_BASE=( sshpass -p "${SERVER_SSH_PASSWORD}" "${SCP_BASE[@]}" )

        return 0

    fi

    die "Missing SERVER_SSH_KEY or SERVER_SSH_PASSWORD"

}
main () {

    trap cleanup EXIT

    echo "🕓 Syncing Script ..."

    load_env
    validate_env
    build_env
    connection
    send_env
    send_script

    echo "✅ Script Synced Successfully."

}

main
