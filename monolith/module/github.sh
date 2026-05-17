#!/usr/bin/env bash
set -Eeuo pipefail

APP_PATH="${APP_PATH:-}"
ROOT_PATH="${ROOT_PATH:-}"
INNER_PATH="${INNER_PATH:-}"
GIT_REPO="${GIT_REPO:-}"
GIT_SSH_KEY="${GIT_SSH_KEY:-}"
GIT_BRANCH="${GIT_BRANCH:-main}"

[[ -n "${ROOT_PATH}"   ]] || { echo "❌ Missing ROOT_PATH"; exit 1; }
[[ -n "${APP_PATH}"    ]] || { echo "❌ Missing APP_PATH"; exit 1; }
[[ -n "${GIT_REPO}"    ]] || { echo "❌ Missing GIT_REPO"; exit 1; }
[[ -n "${GIT_SSH_KEY}" ]] || { echo "❌ Missing GIT_SSH_KEY"; exit 1; }

norm_repo () {

    local repo="${1:-}"

    if [[ "${repo}" == git@*:* || "${repo}" == ssh://* || "${repo}" == https://* || "${repo}" == http://* ]]; then
        [[ "${repo}" == *.git ]] && printf '%s\n' "${repo}" || printf '%s.git\n' "${repo}"
    elif [[ "${repo}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
        printf 'git@github.com:%s.git\n' "${repo}"
    else
        return 1
    fi

}
set_ssh () {

    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    KEY_FILE="$(mktemp)"
    trap 'rm -f "${KEY_FILE}"' EXIT

    printf '%s' "${GIT_SSH_KEY}" | tr -d '\r\n\t ' | base64 -d > "${KEY_FILE}" 2>/dev/null || printf '%s\n' "${GIT_SSH_KEY}" > "${KEY_FILE}"
    chmod 600 "${KEY_FILE}"

    touch "${HOME}/.ssh/known_hosts"
    chmod 600 "${HOME}/.ssh/known_hosts"

    grep -q 'github.com' "${HOME}/.ssh/known_hosts" 2>/dev/null || ssh-keyscan github.com >> "${HOME}/.ssh/known_hosts" 2>/dev/null

    export GIT_SSH_COMMAND="ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"

}
sparse () {

    [[ -n "${INNER_PATH}" ]] || return 0

    git sparse-checkout init --cone || { echo "❌ Failed to init sparse checkout"; exit 1; }
    git sparse-checkout set "${INNER_PATH}" || { echo "❌ Failed to set sparse dir: ${INNER_PATH}"; exit 1; }

}
pull () {

    echo "Pulling Github Repository ..."

    GIT_REPO="$(norm_repo "${GIT_REPO}")" || { echo "❌ Invalid GIT_REPO"; exit 1; }

    GIT_PATH="${ROOT_PATH}"
    [[ -n "${INNER_PATH}" ]] || GIT_PATH="${APP_PATH}"

    mkdir -p -- "${GIT_PATH}"
    cd "${GIT_PATH}" || { echo "❌ Failed to enter root path"; exit 1; }

    if [[ ! -d ".git" ]]; then

        find . -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

        if [[ -n "${INNER_PATH}" ]]; then

            git clone --branch "${GIT_BRANCH}" --no-checkout --filter=blob:none "${GIT_REPO}" . \
                || { echo "❌ Failed to clone git repository"; exit 1; }

            sparse

            git checkout "${GIT_BRANCH}" || { echo "❌ Failed to checkout branch"; exit 1; }

        else

            git clone --branch "${GIT_BRANCH}" "${GIT_REPO}" . || { echo "❌ Failed to clone git repository"; exit 1; }

        fi

        return 0

    fi

    git remote set-url origin "${GIT_REPO}" || git remote add origin "${GIT_REPO}"

    sparse

    git fetch origin "${GIT_BRANCH}" || { echo "❌ Failed to fetch git repository"; exit 1; }
    git reset --hard "origin/${GIT_BRANCH}" || { echo "❌ Failed to reset origin"; exit 1; }
    git clean -fd || { echo "❌ Failed to clean git repository"; exit 1; }

}

set_ssh
pull

echo "✅ Github Repository Synced Successfully."
