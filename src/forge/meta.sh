#!/usr/bin/env bash
# shellcheck disable=SC2034

## the forge's identity — read from the same defaults the bundle ships, never a second source

forge_key () {

    sed -n "s/^${1}=//p" "${ROOT_DIR}/.env.example" | head -1

}
forge_meta () {

    INFRAX_NAME="$(forge_key INFRAX_NAME)"
    INFRAX_VERSION="$(forge_key INFRAX_VERSION)"
    INFRAX_REPO="$(forge_key INFRAX_REPO)"
    INFRAX_INSTALL_DIR="$(path_expand "$(forge_key INFRAX_INSTALL_DIR)")"
    TARGET_DIR="${ROOT_DIR}/$(forge_key TARGET_DIR)"
    SHELLCHECK_EXCLUDES="$(forge_key SHELLCHECK_EXCLUDES)"
    SHELLCHECK_SEVERITY="$(forge_key SHELLCHECK_SEVERITY)"
    NEUTRAL_EXEMPT="$(forge_key NEUTRAL_EXEMPT)"

    SOURCE_DIR="${ROOT_DIR}/src"
    TEST_DIR="${ROOT_DIR}/tests"
    TARGET="dev"
    BIN=""

    [[ -n "${INFRAX_NAME}" && -n "${INFRAX_VERSION}" ]] || die "The defaults file names no INFRAX_NAME / INFRAX_VERSION"

}
prepare () {

    BIN="${TARGET_DIR}/${TARGET}/${INFRAX_NAME}.sh"

    ensure_dir "$(dirname -- "${BIN}")"

}
