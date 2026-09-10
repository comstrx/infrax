#!/usr/bin/env bash

## the build — header, embedded defaults and manifest, core, modules, tests (dev only), entry, payload

build_header () {

    local sha="${1}" dev=""

    [[ "${TARGET}" != "dev" ]] || dev="${SOURCE_DIR}/template"

    printf '%s\n' \
        '#!/usr/bin/env bash' \
        "# shellcheck disable=${SHELLCHECK_EXCLUDES}" \
        'set -Eeuo pipefail' \
        'shopt -s inherit_errexit' \
        '' \
        "INFRAX_NAME=\"${INFRAX_NAME}\"" \
        "INFRAX_VERSION=\"${INFRAX_VERSION}\"" \
        "INFRAX_TEMPLATE_SHA=\"${sha}\"" \
        "INFRAX_DEV_TEMPLATE=\"\${INFRAX_DEV_TEMPLATE-${dev}}\"" \
        'INFRAX_BIN="${INFRAX_BIN:-$(realpath -- "${BASH_SOURCE[0]}")}"' \
        '' \
        'export INFRAX_NAME INFRAX_VERSION INFRAX_TEMPLATE_SHA INFRAX_DEV_TEMPLATE INFRAX_BIN' \
        ''

}
build_body () {

    local file=""

    emit_env infrax_defaults "${ROOT_DIR}/.env.example"
    emit_env infrax_manifest "${ROOT_DIR}/.secret.example"

    for file in $(sources "${SOURCE_DIR}/core"); do emit core "${file}"; done
    for file in $(sources "${SOURCE_DIR}/module"); do emit module "${file}"; done

    [[ "${TARGET}" != "dev" || ! -d "${TEST_DIR}" ]] || for file in $(sources "${TEST_DIR}"); do emit test "${file}"; done

}
build_entry () {

    printf '%s\n' \
        '# @entry main' \
        'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; exit $?; fi' \
        '' \
        '#__INFRAX_PAYLOAD__'

}
build_payload () {

    base64 "${1}" | sed 's/^/#/'

}
builder () {

    local tmp="" payload="" sha=""

    prepare

    tmp="$(mktemp "$(dirname -- "${BIN}")/.${INFRAX_NAME}.XXXXXX")" || die "Cannot create temp file"
    payload="$(tmp_file)"

    payload_pack "${payload}" || die "Cannot pack the templates"
    sha="$(payload_sha "${payload}")"

    {

        build_header "${sha}"
        build_body
        build_entry
        build_payload "${payload}"

    } > "${tmp}" || { rm -f "${tmp}" "${payload}"; die "Cannot build: ${BIN}"; }

    rm -f "${payload}"

    bash -n "${tmp}" || { rm -f "${tmp}"; die "Syntax error in the bundle"; }

    mv -f -- "${tmp}" "${BIN}" || die "Cannot place: ${BIN}"
    chmod +x -- "${BIN}"

    [[ "${TARGET}" != "release" ]] || ( cd "$(dirname -- "${BIN}")" && sha256sum "$(basename -- "${BIN}")" > SHA256SUMS )

}
