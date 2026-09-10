#!/usr/bin/env bash

## source assembly — every file becomes a banner-marked section of the bundle

sources () {

    find "${1}" -type f -name '*.sh' ! -name '_*' | sort

}
emit () {

    local kind="${1}" file="${2}"

    printf '# @%s %s\n' "${kind}" "$(basename "${file}" .sh)"
    grep -v '^#!' "${file}"
    printf '\n'

}
emit_env () {

    local fn="${1}" file="${2}" mark=""

    mark="__INFRAX_${fn##infrax_}__"
    mark="${mark^^}"

    printf '%s () {\n\n    cat <<'"'"'%s'"'"'\n' "${fn}" "${mark}"
    cat "${file}"
    printf '%s\n\n}\n\n' "${mark}"

}
code_of () {

    sed '/^#__INFRAX_PAYLOAD__$/,$d' "${1:-${BIN}}"

}
