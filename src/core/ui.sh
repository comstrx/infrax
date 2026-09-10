#!/usr/bin/env bash

input () {

    local prompt="${1:-}" fallback="${2:-}" value=""

    if is_ci || [[ ! -t 0 ]]; then

        [[ -n "${fallback}" ]] || die "Non-interactive run needs a default for: ${prompt}"

        printf '%s' "${fallback}"
        return 0

    fi

    read -r -t "${INPUT_TIMEOUT}" -p "${prompt} [${fallback}]: " value || die "Input timed out: ${prompt}"

    printf '%s' "${value:-${fallback}}"

}
confirm () {

    local prompt="${1:-Continue?}" value=""

    [[ -n "${INFRAX_YES:-}" ]] && return 0

    is_ci && die "Refusing '${prompt}' in CI without INFRAX_YES=1"

    read -r -t "${INPUT_TIMEOUT}" -p "${prompt} [y/N]: " value || die "Confirmation timed out"

    [[ "${value}" =~ ^[Yy]([Ee][Ss])?$ ]]

}
