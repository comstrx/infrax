#!/usr/bin/env bash

run () {

    info "$*"
    "$@"

}
lock () {

    local name="${1:-${INFRAX_NAME}}"

    ensure flock

    exec 9>"${LOCK_DIR}/${name}.lock"
    flock -n 9 || die "Another '${name}' run is already in progress"

}
