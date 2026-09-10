#!/usr/bin/env bash

## the release — a GitHub release carrying the bundle and its SHA256SUMS, notes from the changelog

release_notes () {

    local file="${ROOT_DIR}/CHANGELOG.md"

    [[ -f "${file}" ]] || { printf '%s %s\n' "${INFRAX_NAME}" "v${INFRAX_VERSION}"; return 0; }

    sed -n "/^## ${INFRAX_VERSION}\$/,/^## /{ /^## /d; p; }" "${file}"

}
releaser () {

    local tag="v${INFRAX_VERSION}" dir="" notes=""

    ensure gh

    dir="$(dirname -- "${BIN}")"
    notes="$(release_notes)"

    [[ -n "${notes}" ]] || die "CHANGELOG.md carries no section for ${INFRAX_VERSION}"

    gh release view "${tag}" --repo "${INFRAX_REPO}" >/dev/null 2>&1 && die "Release ${tag} already exists — bump INFRAX_VERSION first"

    gh release create "${tag}" "${BIN}" "${dir}/SHA256SUMS" --repo "${INFRAX_REPO}" --title "${INFRAX_NAME} ${tag}" --notes "${notes}" "$@" \
        || die "Release failed"

    succ "Released ${tag}"

}
