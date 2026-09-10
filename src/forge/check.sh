#!/usr/bin/env bash

## the check — syntax, shellcheck at the configured severity, payload integrity, no stray literals, a neutral core

check_literals () {

    local hits="" knobs=""

    hits="$(grep -nE 'https?://[a-z]' "${SOURCE_DIR}"/core/*.sh "${SOURCE_DIR}"/module/*.sh | grep -v '\${' || true)"
    knobs="$(grep -nE 'shellcheck .*(-e SC|-S [a-z])' "${SOURCE_DIR}"/core/*.sh "${SOURCE_DIR}"/module/*.sh || true)"

    [[ -z "${hits}" ]] || { printf '%s\n' "${hits}" >&2; die "Literal endpoints in src — every URL belongs in .env.example"; }
    [[ -z "${knobs}" ]] || { printf '%s\n' "${knobs}" >&2; die "Literal shellcheck knobs in src — SHELLCHECK_SEVERITY and SHELLCHECK_EXCLUDES belong in .env.example"; }

}
check_names () {

    find "${SOURCE_DIR}/template/${1}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort

}
check_neutral () {

    local word="" words="" clouds="" hits="" exempt=" ${NEUTRAL_EXEMPT} "

    clouds="$(check_names tofu | paste -sd '|' -)"

    for word in $(check_names runtime) $(check_names module) $(check_names tofu); do

        [[ "${exempt}" == *" ${word} "* ]] || words+="${words:+|}${word}"

    done

    [[ -n "${words}" ]] || return 0

    hits="$(grep -nowiE "${words}" "${SOURCE_DIR}"/core/*.sh "${SOURCE_DIR}"/module/*.sh | grep -vE "/module/(${clouds}|tool)\.sh:" || true)"

    [[ -z "${hits}" ]] || { printf '%s\n' "${hits}" >&2; die "The core names a runtime, a module or a cloud — that knowledge lives in src/template and in module/<cloud>.sh"; }

}
check_forge () {

    local key=""

    shellcheck -s bash -x -S "${SHELLCHECK_SEVERITY}" -e "${SHELLCHECK_EXCLUDES}" "${ROOT_DIR}/src/main.sh" "${ROOT_DIR}"/src/forge/*.sh || die "ShellCheck failed on the forge"

    for key in $(forge_key FORGE_KEYS); do

        grep -qw "${key}" "${ROOT_DIR}/src/main.sh" "${ROOT_DIR}"/src/forge/*.sh || die "FORGE_KEYS names ${key}, which the forge never reads"

    done

}
checker () {

    local code="" expected="" actual="" files=0

    ensure shellcheck

    code="$(mktemp --suffix=.sh)"
    code_of > "${code}"

    bash -n "${BIN}" || { rm -f "${code}"; die "Syntax check failed"; }
    shellcheck -s bash -x -S "${SHELLCHECK_SEVERITY}" -e "${SHELLCHECK_EXCLUDES}" "${code}" || { rm -f "${code}"; die "ShellCheck failed"; }
    rm -f "${code}"

    check_literals
    check_neutral
    check_forge

    expected="$(payload_stamp)"
    actual="$(payload_of | sha256sum | cut -c1-64)"
    files="$(payload_of | tar tzf - | grep -c -v '/$')"

    [[ "${expected}" == "${actual}" ]] || die "Payload sha drifted: header ${expected:0:12}, payload ${actual:0:12}"
    (( files > 0 )) || die "Payload carries no files"

    succ "Check passed — ${TARGET} bundle, $(wc -l < "${BIN}") lines, ${files} template files, payload ${actual:0:12}"

}
