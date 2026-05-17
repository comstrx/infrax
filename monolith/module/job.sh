#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="${CONFIG_DIR:-}"
SESSION_ID="${SESSION_ID:-}"

APP_PATH="${APP_PATH:-}"

START_HORIZON="${START_HORIZON:-1}"
START_REVERB="${START_REVERB:-1}"

FILES=()

[[ -n "${CONFIG_DIR}" ]] || { echo "❌ Missing CONFIG_DIR"; exit 1; }
[[ -n "${SESSION_ID}" ]] || { echo "❌ Missing SESSION_ID"; exit 1; }
[[ -n "${APP_PATH}"   ]] || { echo "❌ Missing APP_PATH"; exit 1; }

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

    for ENTRY in "${FILES[@]}"; do

        TEMPLATE="${ENTRY%%:*}"
        DEST="${ENTRY##*:}"
        NAME="$(basename "${DEST}")"

        TMP="$(mktemp)" || { echo "❌ Failed to create tmp file"; exit 1; }

        [[ -f "${TEMPLATE}" ]] || { echo "❌ Missing template: ${TEMPLATE}"; rm -f -- "${TMP}"; exit 1; }

        echo "Generating Supervisor Job: ${NAME} ..."

        SESSION_ID_SED="$(sed_escape "${SESSION_ID}")"
        APP_PATH_SED="$(sed_escape "${APP_PATH}")"

        sed \
            -e "s|__SESSION_ID__|${SESSION_ID_SED}|g" \
            -e "s|__APP_PATH__|${APP_PATH_SED}|g" \
            "${TEMPLATE}" > "${TMP}" || { echo "❌ Failed to generate job: ${NAME}"; rm -f -- "${TMP}"; exit 1; }

        sudo mv -f -- "${TMP}" "${DEST}" || { echo "❌ Failed to install job: ${NAME}"; rm -f -- "${TMP}"; exit 1; }
        sudo chmod 0644 "${DEST}"

    done

}
remove_old () {

    for file in /etc/supervisor/conf.d/"${SESSION_ID}"_*.conf; do

        [[ -e "${file}" ]] || continue
        keep=0

        for entry in "${FILES[@]}"; do
            dest="${entry##*:}"
            [[ "${file}" == "${dest}" ]] && { keep=1; break; }
        done

        if (( keep == 0 )); then
            echo "Removing old job: ${file}"
            sudo rm -f -- "${file}"
        fi

    done

}
restart () {

    sudo supervisorctl reread || { echo "❌ supervisor reread failed"; exit 1; }
    sudo supervisorctl update || { echo "❌ supervisor update failed"; exit 1; }

    for ENTRY in "${FILES[@]}"; do

        DEST="${ENTRY##*:}"
        SERVICE="$(basename "${DEST}" .conf)"
        sudo supervisorctl restart "${SERVICE}:*" || { echo "❌ Failed to restart job: ${SERVICE}"; exit 1; }

    done

}

if is_true "${START_HORIZON}"; then

    FILES+=( "${CONFIG_DIR}/super.horizon.conf:/etc/supervisor/conf.d/${SESSION_ID}_horizon.conf" )

fi
if is_true "${START_REVERB}"; then

    FILES+=( "${CONFIG_DIR}/super.reverb.conf:/etc/supervisor/conf.d/${SESSION_ID}_reverb.conf" )

fi

set_config
remove_old
restart

echo "✅ Supervisor Jobs Configured Successfully."
