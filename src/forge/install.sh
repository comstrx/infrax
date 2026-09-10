#!/usr/bin/env bash

## the install — the checked release bundle, verified against its SHA256SUMS, into the install dir

installer () {

    local dst=""

    dst="${INFRAX_INSTALL_DIR}/${INFRAX_NAME}"

    ( cd "$(dirname -- "${BIN}")" && sha256sum --check --quiet SHA256SUMS ) || die "SHA256SUMS does not match the bundle"

    ensure_dir "${INFRAX_INSTALL_DIR}"
    install -m 0755 -- "${BIN}" "${dst}" || die "Cannot install: ${dst}"

    succ "Installed → ${dst}"
    info "Run: ${INFRAX_NAME} --help"

}
runner () {

    "${BIN}" "$@"

}
