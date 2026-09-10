#!/usr/bin/env bash

ensure_dir () {

    local dir="${1:-}"

    [[ -d "${dir}" ]] || mkdir -p "${dir}" || die "Cannot mkdir: ${dir}"

}
tmp_file () {

    mktemp || die "Cannot create temp file"

}
tmp_dir () {

    mktemp -d || die "Cannot create temp dir"

}
placeholders () {

    local file="${1:-}"

    grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "${file}" 2>/dev/null | sort -u | tr -d "\${}"

}
render_text () {

    local text="" key="" list=""

    ensure envsubst

    text="$(cat)"

    for key in $({ grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' <<< "${text}" || true; } | sort -u | tr -d "\${}"); do

        [[ -n "${!key+x}" ]] || die "Render missing: ${key}"

        list+="\${${key}} "

    done

    envsubst "${list}" <<< "${text}"

}
render () {

    local src="${1:-}" dst="${2:-}"

    [[ -f "${src}" ]] || die "Missing template: ${src}"

    ensure_dir "$(dirname "${dst}")"

    render_text < "${src}" > "${dst}" || die "Cannot render: ${src}"

}
yaml_str () {

    ensure jq

    jq -Rn --arg value "${1:-}" '$value'

}
yaml_list () {

    local item="" out=""

    for item in "$@"; do

        out+="${out:+, }$(yaml_str "${item}")"

    done

    printf '[%s]' "${out}"

}
uri_encode () {

    ensure jq

    jq -rn --arg value "${1:-}" '$value | @uri'

}
argv_list () {

    local word="" out=""

    for word in "$@"; do

        out+="${out:+, }$(yaml_str "${word}")"

    done

    printf '[%s]' "${out}"

}
argv_json () {

    local text="${1:-}" words=()

    [[ "${text}" != \[* ]] || { printf '%s' "${text}"; return 0; }

    read -ra words <<< "${text}"

    argv_list "${words[@]}"

}
indent () {

    local width="${1:?indent needs a width}" pad=""

    printf -v pad '%*s' "${width}" ''

    sed "s/^/${pad}/"

}
path_expand () {

    printf '%s' "${1/#\~/${HOME}}"

}
