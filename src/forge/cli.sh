#!/usr/bin/env bash
# shellcheck disable=SC2034

## the forge command line

usage () {

    printf '%s\n' \
        "Usage:" \
        "    ${0##*/} <command> [options] [args...]" \
        "" \
        "Commands:" \
        "    build                  Build the dev bundle (tests included, templates read live from src/)" \
        "    build-release          Build the release bundle (tests stripped) + SHA256SUMS" \
        "    check [--release]      bash -n, shellcheck, payload integrity, no stray literals, a neutral core" \
        "    test [glob] [--check]  Run the tests against the dev bundle (--list to see them)" \
        "    run <args...>          Run the dev bundle" \
        "    install                Build, check, verify and install the release bundle" \
        "    release [gh flags]     Build, check and publish a GitHub release of the bundle" \
        "    clean                  Remove the target dir" \
        "" \
        "Anything else is passed to the dev bundle: ${0##*/} -s light ci verify" \
        "" \
        "Meta:" \
        "    -n, --name             Print app name" \
        "    -b, --bin              Print bundle path" \
        "    -v, --version          Print version" \
        "    -t, --tag              Print release tag"

}
forge_main () {

    local cmd="${1:-}"
    shift >/dev/null 2>&1 || true

    forge_meta

    case "${cmd}" in
        ""|-h|--help)      usage; return ;;
        help)              (( $# == 0 )) || { builder; runner help "$@"; return; }; usage; return ;;
        -n|--name)         printf '%s\n' "${INFRAX_NAME}"; return ;;
        -v|--version)      printf '%s\n' "${INFRAX_VERSION}"; return ;;
        -t|--tag)          printf 'v%s\n' "${INFRAX_VERSION}"; return ;;
        -b|--bin)          prepare; printf '%s\n' "${BIN}"; return ;;
        clean)             rm -rf -- "${TARGET_DIR}"; succ "Cleaned ${TARGET_DIR}"; return ;;
        build-release|install|release) TARGET="release" ;;
        check)             [[ "${1:-}" != "--release" ]] || { TARGET="release"; shift; } ;;
    esac

    builder

    case "${cmd}" in
        build|build-release) succ "Built → ${BIN}" ;;
        check)               checker ;;
        test)                tester "$@" ;;
        run)                 runner "$@" ;;
        install)             checker; installer ;;
        release)             checker; releaser "$@" ;;
        *)                   runner "${cmd}" "$@" ;;
    esac

}
