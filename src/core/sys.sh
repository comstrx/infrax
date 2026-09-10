#!/usr/bin/env bash

has () {

    command -v "${1:-}" >/dev/null 2>&1

}
as_root () {

    if [[ "$(id -u)" == "0" ]]; then "$@"; else sudo "$@"; fi

}
pkg_install () {

    [[ -n "${1:-}" ]] || die "pkg_install needs a package"

    has apt-get || die "Cannot install '$*': no apt on this system"

    as_root apt-get update -qq || die "Failed to update apt"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" || die "Failed to install: $*"

}
is_ci () {

    [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]

}
ensure () {

    local tool=""

    for tool in "$@"; do

        has "${tool}" && continue

        info "Installing: ${tool}"

        if declare -F "tool_${tool//-/_}" >/dev/null; then "tool_${tool//-/_}" >&2; else pkg_install "${tool}" >&2; fi

        has "${tool}" || die "Cannot install: ${tool}"

    done

}
