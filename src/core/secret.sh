#!/usr/bin/env bash

secret_keys () {

    infrax_manifest | sed -nE 's/^([A-Z][A-Z0-9_]*)=.*/\1/p'

}
secret_get () {

    local key="${1:?secret_get needs a key}"

    printf '%s' "${!key-}"

}
secret_name () {

    local key="${1:?secret_name needs a key}"

    [[ " $(secret_keys | paste -sd ' ' -) " == *" ${key} "* || "${key}" == SECRET_* || "${key}" =~ (PASSWORD|SECRET|TOKEN|_KEY|_ENV_FILE|CREDENTIALS)$ ]]

}
secret_require () {

    local key="${1:-}" value=""

    value="$(secret_get "${key}")"

    [[ -n "${value}" ]] || die "Missing secret: ${key}"

    printf '%s' "${value}"

}
secret_env_pairs () {

    local name="${1:?secret_env_pairs needs a variable}" raw="" line="" key="" value=""

    raw="$(secret_get "${name}")"
    [[ -n "${raw}" ]] || return 0

    while IFS= read -r line; do

        key="${line%%=*}"
        value="${line#*=}"

        [[ -n "${value}" ]] || continue
        [[ "${value}" =~ ^\"(.*)\"$ || "${value}" =~ ^\'(.*)\'$ ]] && value="${BASH_REMATCH[1]}"

        printf '%s=%s\n' "${key}" "${value}"

    done < <(base64 -d <<< "${raw}" 2>/dev/null | env_pairs || die "${name} is not base64")

}
secret_service_env () {

    local service="${1:?secret_service_env needs a service}" dst="${2:?secret_service_env needs a destination}" line="" key="" bound=""

    umask 077

    : > "${dst}" || die "Cannot write: ${dst}"
    chmod 600 "${dst}"

    bind_env "${service}" | env_pairs | grep -vE '^[A-Za-z_][A-Za-z0-9_]*=$' >> "${dst}" || true

    bound=" $(sed -n 's/=.*//p' "${dst}" | paste -sd ' ' -) "

    while IFS= read -r line; do

        key="${line%%=*}"

        if [[ "${bound}" == *" ${key} "* ]]; then warn "${service}: ${key} is bound by infrax — the environment file cannot override it"; continue; fi

        printf '%s\n' "${line}" >> "${dst}"

    done < <(secret_env_pairs "$(service_var "${service}" ENV_FILE)")

}
