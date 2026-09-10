#!/usr/bin/env bash

## the bundle itself — version, location, update

## the running version and the template stamp it carries
self_version () {

    printf '%s %s\ntemplates %s\n' "${INFRAX_NAME}" "${INFRAX_VERSION}" "${INFRAX_TEMPLATE_SHA:0:12}"

}
## where the running bundle lives and where its templates unpack
self_where () {

    printf '%s\n%s\n' "${INFRAX_BIN}" "${TEMPLATE_DIR}"

}
## every key the bundle reads — names only, defaults then secrets
self_keys () {

    infrax_defaults | sed -nE 's/^([A-Z][A-Z0-9_]*)=.*/\1/p'
    secret_keys

}
## replace this bundle with a released one — latest, or a tag — verified against its SHA256SUMS
self_update () {

    local tag="${1:-latest}" base="" dir="" version=""

    ensure curl

    [[ -n "${INFRAX_REPO}" ]] || die "INFRAX_REPO is empty — nowhere to update from"

    if [[ "${tag}" == "latest" ]]; then base="${GITHUB_URL}/${INFRAX_REPO}/releases/latest/download"; else base="${GITHUB_URL}/${INFRAX_REPO}/releases/download/${tag}"; fi

    dir="$(tmp_dir)"

    curl -fsSL "${base}/${INFRAX_NAME}.sh" -o "${dir}/${INFRAX_NAME}.sh" || die "Cannot download ${tag} from ${INFRAX_REPO}"
    curl -fsSL "${base}/SHA256SUMS" -o "${dir}/SHA256SUMS" || die "Cannot download the checksums of ${tag}"

    ( cd "${dir}" && sha256sum --check --quiet SHA256SUMS ) || die "Checksum mismatch — refusing ${tag}"

    bash -n "${dir}/${INFRAX_NAME}.sh" || die "The downloaded bundle does not parse"

    version="$(sed -n 's/^INFRAX_VERSION="\(.*\)"$/\1/p' "${dir}/${INFRAX_NAME}.sh")"

    if [[ -w "${INFRAX_BIN}" ]]; then install -m 0755 "${dir}/${INFRAX_NAME}.sh" "${INFRAX_BIN}"; else as_root install -m 0755 "${dir}/${INFRAX_NAME}.sh" "${INFRAX_BIN}"; fi

    rm -rf "${dir}"

    succ "${INFRAX_NAME} ${INFRAX_VERSION} → ${version} at ${INFRAX_BIN}"

}
