#!/usr/bin/env bash
set -Eeuo pipefail

APP_PATH="${APP_PATH:-}"
STORAGE_PATH="${STORAGE_PATH:-}"

[[ -n "${APP_PATH}" ]] || { echo "❌ Missing APP_PATH"; exit 1; }
[[ -n "${STORAGE_PATH}" ]] || { echo "❌ Missing STORAGE_PATH"; exit 1; }

mkdir -p "${APP_PATH}" 2>/dev/null || sudo mkdir -p "${APP_PATH}"
mkdir -p "${STORAGE_PATH}" 2>/dev/null || sudo mkdir -p "${STORAGE_PATH}"

cd "${APP_PATH}"

link_path () {

    echo "Linking Storage Path ..."

    if [[ "$(realpath -m "${APP_PATH}")" == "$(realpath -m "${STORAGE_PATH}")" ]]; then

        echo "❌ APP_PATH and STORAGE_PATH must be different"
        exit 1

    fi
    if [[ -d "${APP_PATH}/storage" && ! -L "${APP_PATH}/storage" ]]; then

        shopt -s dotglob nullglob

        cp -R "${APP_PATH}/storage/"* "${STORAGE_PATH}/" 2>/dev/null \
            || sudo cp -R "${APP_PATH}/storage/"* "${STORAGE_PATH}/" 2>/dev/null || true

        shopt -u dotglob nullglob

    fi

    rm -rf "${APP_PATH}/storage" 2>/dev/null || sudo rm -rf "${APP_PATH}/storage"
    rm -rf "${APP_PATH}/public/storage" 2>/dev/null || sudo rm -rf "${APP_PATH}/public/storage"

    mkdir -p "${STORAGE_PATH}/app/public" 2>/dev/null || sudo mkdir -p "${STORAGE_PATH}/app/public"

    mkdir -p "${APP_PATH}/public" "${APP_PATH}/bootstrap/cache" 2>/dev/null \
        || sudo mkdir -p "${APP_PATH}/public" "${APP_PATH}/bootstrap/cache"

    ln -sfn "${STORAGE_PATH}" "${APP_PATH}/storage" 2>/dev/null \
        || sudo ln -sfn "${STORAGE_PATH}" "${APP_PATH}/storage"

    ln -sfn "${STORAGE_PATH}/app/public" "${APP_PATH}/public/storage" 2>/dev/null \
        || sudo ln -sfn "${STORAGE_PATH}/app/public" "${APP_PATH}/public/storage"

}
set_permissions () {

    echo "Setting Storage Permissions ..."

    local user=""
    user="$(id -un)"

    mkdir -p \
        "${STORAGE_PATH}/app/public" \
        "${STORAGE_PATH}/framework/cache" \
        "${STORAGE_PATH}/framework/sessions" \
        "${STORAGE_PATH}/framework/views" \
        "${STORAGE_PATH}/logs" \
        "${APP_PATH}/bootstrap/cache" \
        2>/dev/null || sudo mkdir -p \
        "${STORAGE_PATH}/app/public" \
        "${STORAGE_PATH}/framework/cache" \
        "${STORAGE_PATH}/framework/sessions" \
        "${STORAGE_PATH}/framework/views" \
        "${STORAGE_PATH}/logs" \
        "${APP_PATH}/bootstrap/cache"

    sudo chown -h "${user}:www-data" "${APP_PATH}/storage" "${APP_PATH}/public/storage" || true
    sudo chown -R "${user}:www-data" "${STORAGE_PATH}" "${APP_PATH}/bootstrap/cache"

    sudo chmod -R ug+rwX,o-rwx "${STORAGE_PATH}" "${APP_PATH}/bootstrap/cache"
    sudo find "${STORAGE_PATH}" "${APP_PATH}/bootstrap/cache" -type d -exec chmod g+s {} +

}

link_path
set_permissions

echo "✅ Storage Configured Successfully."
