#!/usr/bin/env bash

## the tests — discovered by name or marker, run one per process inside the dev bundle

tests_of () {

    local file="" line="" probe="" fn="" mark=0 skip=0

    [[ -d "${TEST_DIR}" ]] || return 0

    for file in $(sources "${TEST_DIR}"); do

        while IFS= read -r line || [[ -n "${line}" ]]; do

            probe="${line//[[:space:]]/}"
            probe="${probe,,}"

            if [[ "${probe}" =~ ^#@?(\[no-test\]|no-test|\[no_test\]|no_test)$ ]]; then mark=0; skip=1; continue; fi
            if [[ "${probe}" =~ ^#@?(\[test\]|test)$ ]]; then mark=1; skip=0; continue; fi

            if [[ "${line}" =~ ^[[:space:]]*(function[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*(\(\))?[[:space:]]*\{ ]]; then

                fn="${BASH_REMATCH[2]}"

                if (( ! skip )) && { (( mark )) || [[ "${fn}" == test_* ]]; }; then printf '%s\n' "${fn}"; fi

                mark=0; skip=0
                continue

            fi

            [[ "${line}" =~ ^[[:space:]]*$ ]] && continue

            mark=0; skip=0

        done < "${file}"

    done | sort -u

}
tester () {

    local fn="" only="" result="" started=0 took=0 pass=0 fail=0 total=0 check=0 list=0
    local -a tests=()

    for arg in "$@"; do

        case "${arg}" in
            --check|-c) check=1 ;;
            --list|-l)  list=1 ;;
            *)          only="${arg}" ;;
        esac

    done

    mapfile -t tests < <(tests_of)

    if (( list )); then

        printf '%s\n' "${tests[@]}"
        return 0

    fi

    (( check == 0 )) || checker

    for fn in "${tests[@]}"; do

        # shellcheck disable=SC2053
        [[ -z "${only}" ]] || [[ "${fn}" == ${only} || "${fn#test_}" == ${only} || "${fn}" == *${only}* ]] || continue

        total=$(( total + 1 ))
        started="$(date +%s%N)"

        if result="$("${BIN}" "${fn}" 2>&1)"; then

            took=$(( ( $(date +%s%N) - started ) / 1000000 ))
            pass=$(( pass + 1 ))
            succ "${fn} (${took}ms)"

        else

            took=$(( ( $(date +%s%N) - started ) / 1000000 ))
            fail=$(( fail + 1 ))
            err "${fn} (${took}ms)"
            [[ -z "${result}" ]] || printf '%s\n' "${result}" | sed 's/^/    /' >&2

        fi

    done

    (( total > 0 )) || die "No test matched${only:+: ${only}}"

    if (( fail == 0 )); then succ "Pass: ${pass}, Fail: ${fail}, Total: ${total}"; else die "Pass: ${pass}, Fail: ${fail}, Total: ${total}"; fi

}
