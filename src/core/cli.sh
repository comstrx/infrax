#!/usr/bin/env bash

## the command line — flags, modules, dispatch, help

cli_modules () {

    infrax_code | sed -n 's/^# @module //p'

}
cli_section () {

    infrax_code | sed -n "/^# @module ${1}\$/,/^# @[a-z]/p"

}
cli_is_test () {

    declare -F "${1}" >/dev/null && [[ -n "$(infrax_code | sed -n '/^# @test /,/^# @entry/p' | grep -E "^${1} \(\)")" ]]

}
cli_has_module () {

    [[ " $(cli_modules | paste -sd ' ' -) " == *" ${1} "* ]]

}
module_doc () {

    cli_section "${1}" | sed -n '2,4{ s/^## //p; }' | head -1

}
commands_of () {

    local name="${1}" indent="${2}" doc="" line="" fn=""

    while IFS= read -r line; do

        if [[ "${line}" == "## "* ]]; then doc="${line#\#\# }"; continue; fi

        if [[ "${line}" =~ ^${name}_([a-z_]+)\ \(\) && -n "${doc}" ]]; then

            fn="$(tr '_' '-' <<< "${BASH_REMATCH[1]}")"
            printf "${indent}%-22s %s\n" "${fn}" "${doc}"

        fi

        doc=""

    done < <(cli_section "${name}")

}
command_help () {

    local name="${1}" command="${2}" fn="" section="" doc="" usage="" needs=""

    fn="${name}_${command//-/_}"
    section="$(cli_section "${name}" | sed -n "/^${fn} ()/,/^}/p")"

    [[ -n "${section}" ]] || { printf '❌ Unknown command: %s %s\n' "${name}" "${command}" >&2; exit 1; }

    doc="$(cli_section "${name}" | grep -B1 "^${fn} ()" | sed -n 's/^## //p' || true)"
    usage="$(grep -oE 'Usage: [^}"]*' <<< "${section}" | head -1 || true)"
    needs="$(grep -oE '\$\{[0-9]:\?[^}]*\}' <<< "${section}" | sed -E 's/^\$\{([0-9]):\?(Usage: )?([^}]*)\}$/\1: \3/' | paste -sd ';' - || true)"

    printf '%s %s %s — %s\n' "${INFRAX_NAME}" "${name}" "${command}" "${doc:-undocumented}"

    [[ -z "${usage}" ]] || printf '  %s\n' "${usage}"
    [[ -z "${needs}" || -n "${usage}" ]] || printf '  arguments — %s\n' "${needs}"

    exit 0

}
module_help () {

    cli_has_module "${1}" || { printf '❌ Unknown module: %s\n' "${1}" >&2; exit 1; }

    [[ -z "${2:-}" ]] || command_help "${1}" "${2}"

    printf '%s\n\n' "${INFRAX_NAME} ${1} — $(module_doc "${1}")"
    commands_of "${1}" "  "

    exit 0

}
usage () {

    local name=""

    printf '%s\n' \
        "${INFRAX_NAME} ${INFRAX_VERSION} — one manifest, one production platform" \
        "" \
        "Usage: ${INFRAX_NAME} [options] <module> <command> [args...]" \
        "" \
        "Options:" \
        "  -s, --stack <name>       the environment to act on (see STACKS)" \
        "  -c, --config <file>      load this env file — repeatable, the last one wins" \
        "  -r, --repo <dir>         the project repo to act on (default: the one around you)" \
        "  -y, --yes                auto-approve every confirmation" \
        "  -e, --env <KEY=VALUE>    override any config variable (repeatable)" \
        "  -l, --list               every module with every command" \
        "  -h, --help               this overview — '${INFRAX_NAME} help <module> [command]' goes deeper" \
        "  -V, --version            show version" \
        "" \
        "Config precedence: flags > process env > JSON_ENV > --config files > infrax.<stack>.env > infrax.env > built-in defaults" \
        "" \
        "Modules:"

    for name in $(cli_modules); do

        printf '  %-10s %s\n' "${name}" "$(module_doc "${name}")"

    done

    printf '%s\n' \
        "" \
        "Examples:" \
        "  ${INFRAX_NAME} -s light ci release                    converge, build, prove, push, scan, vendor, bump — argocd deploys" \
        "  ${INFRAX_NAME} -s standard -y server deploy           any linux over ssh becomes the platform" \
        "  ${INFRAX_NAME} -s light app run api -- php artisan about   one command on the live release of one service" \
        "  ${INFRAX_NAME} audit all                              every live production check in one sweep" \
        "  ${INFRAX_NAME} self update                            the latest release, checksum verified"

    exit "${1:-0}"

}
listing () {

    local name=""

    for name in $(cli_modules); do

        printf '%s\n' "  ${name} — $(module_doc "${name}")"
        commands_of "${name}" "    "
        printf '\n'

    done

    exit 0

}
flags () {

    while [[ $# -gt 0 ]]; do

        if (( ${#ARGS[@]} )); then

            ARGS+=( "${1}" )
            shift
            continue

        fi

        case "${1}" in

            -- )
                shift
                ARGS+=( "$@" )
                break ;;

            -s | --stack )
                [[ -n "${2:-}" ]] || { printf '❌ Missing stack name\n' >&2; exit 1; }
                export STACK="${2}" INFRAX_FLAGS="${INFRAX_FLAGS:-} STACK"
                shift 2 ;;

            -c | --config )
                [[ -f "${2:-}" ]] || { printf '❌ Config file not found: %s\n' "${2:-}" >&2; exit 1; }
                INFRAX_CONFIG="${INFRAX_CONFIG:+${INFRAX_CONFIG}$'\n'}$(realpath "${2}")"
                export INFRAX_CONFIG
                shift 2 ;;

            -r | --repo )
                [[ -d "${2:-}" ]] || { printf '❌ Repo directory not found: %s\n' "${2:-}" >&2; exit 1; }
                REPO_ROOT="$(realpath "${2}")"
                export REPO_ROOT
                shift 2 ;;

            -y | --yes )
                export INFRAX_YES=1
                shift ;;

            -e | --env )
                [[ "${2:-}" == *=* ]] || { printf '❌ Invalid override: %s\n' "${2:-}" >&2; exit 1; }
                export "${2?}"
                export INFRAX_FLAGS="${INFRAX_FLAGS:-} ${2%%=*}"
                shift 2 ;;

            -l | --list )
                listing ;;

            -h | --help )
                usage ;;

            -V | --version )
                printf '%s %s\n' "${INFRAX_NAME}" "${INFRAX_VERSION}"
                exit 0 ;;

            -* )
                printf '❌ Unknown option: %s\n' "${1}" >&2
                usage 1 ;;

            * )
                ARGS+=( "${1}" )
                shift ;;

        esac

    done

}
main () {

    local module="" command="" fn=""

    ARGS=()
    flags "$@"

    module="${ARGS[0]:-}"
    command="${ARGS[1]:-}"

    if [[ "${module}" == "help" ]]; then

        if [[ -n "${command}" ]]; then module_help "${command}" "${ARGS[2]:-}"; else usage; fi

    fi

    [[ -n "${module}" ]] || usage 1

    if cli_is_test "${module}"; then

        "${module}" "${ARGS[@]:1}"
        return

    fi

    cli_has_module "${module}" || die "Unknown module: ${module}"

    if [[ "${module}" == "self" ]]; then config_light; else config_load; fi

    if [[ -z "${command}" ]]; then

        commands_of "${module}" "  "
        exit 1

    fi

    fn="${module}_${command//-/_}"

    declare -F "${fn}" >/dev/null || die "Unknown function: ${module} ${command}"

    "${fn}" "${ARGS[@]:2}"

}
