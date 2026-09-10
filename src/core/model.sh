#!/usr/bin/env bash

## the project model — services, modules, runtimes and bindings, every answer derived from the manifest and the templates

model_key () {

    local name="${1:?model_key needs a name}"

    name="${name^^}"

    printf '%s' "${name//-/_}"

}
model_ident () {

    local name="${1:?model_ident needs a name}"

    printf '%s' "${name//-/_}"

}
model_names () {

    local kind="${1:?model_names needs a kind}" entry=""

    for entry in "${TEMPLATE_DIR}/${kind}"/*/; do

        [[ -d "${entry}" ]] || continue

        entry="${entry%/}"
        printf '%s\n' "${entry##*/}"

    done

}
model_read () {

    local file="${1:?model_read needs a file}" key="${2:?model_read needs a key}"

    [[ -f "${file}" ]] || return 0

    sed -n "s/^${key}=//p" "${file}" | tail -n 1

}
model_keys () {

    local file="${1:?model_keys needs a file}"

    [[ -f "${file}" ]] || return 0

    sed -nE 's/^([A-Z][A-Z0-9_]*)=.*/\1/p' "${file}"

}
model_fqdn () {

    printf '%s%s.%s' "${HOST_PREFIX:-}" "${1:?model_fqdn needs a label}" "${BASE_DOMAIN:?Missing BASE_DOMAIN — every public name lives under it}"

}
model_suffix () {

    printf '%s/%s' "${BASE_DOMAIN:-}" "${PROJECT:-}" | sha256sum | cut -c1-6

}
model_bucket () {

    printf '%s-%s-%s' "${PROJECT:?Missing PROJECT}" "${1:?model_bucket needs a purpose}" "${BUCKET_SUFFIX}"

}
runtime_dir () {

    local runtime="${1:?runtime_dir needs a runtime}"

    [[ -f "${TEMPLATE_DIR}/runtime/${runtime}/profile.env" ]] \
        || die "Unknown runtime '${runtime}' — infrax runs: $(model_names runtime | paste -sd ' ' -)"

    printf '%s' "${TEMPLATE_DIR}/runtime/${runtime}"

}
runtime_get () {

    local runtime="${1:?runtime_get needs a runtime}" key="${2:?runtime_get needs a key}" override=""

    override="$(model_key "${runtime}")_${key}"

    if [[ -n "${!override:-}" ]]; then

        printf '%s' "${!override}"
        return 0

    fi

    model_read "$(runtime_dir "${runtime}")/profile.env" "${key}"

}
service_var () {

    printf 'SERVICE_%s_%s' "$(model_key "${1:?service_var needs a service}")" "${2:?service_var needs a key}"

}
service_runtime () {

    local service="${1:?service_runtime needs a service}" name=""

    name="$(service_var "${service}" RUNTIME)"

    [[ -n "${!name:-}" ]] || die "Service '${service}' declares no runtime — set ${name} to one of: $(model_names runtime | paste -sd ' ' -)"

    printf '%s' "${!name}"

}
service_get () {

    local service="${1:?service_get needs a service}" key="${2:?service_get needs a key}" name="" value=""

    name="$(service_var "${service}" "${key}")"
    value="${!name:-}"

    [[ -n "${value}" ]] || value="$(runtime_get "$(service_runtime "${service}")" "${key}")"

    if [[ -z "${value}" ]]; then

        case "${key}" in
            REPLICAS_MIN | REPLICAS_MAX | CPU_TARGET ) value="${!key:-}" ;;
        esac

    fi

    [[ "${value}" != "none" ]] || value=""

    printf '%s' "${value}"

}
service_path () {

    local service="${1:?service_path needs a service}" path=""

    path="$(service_get "${service}" PATH)"

    printf '%s' "${path:-${service}}"

}
service_processes () {

    local service="${1:?service_processes needs a service}" processes=""

    processes="$(service_get "${service}" PROCESSES)"

    printf '%s' "${processes:-web}"

}
service_hosts () {

    local service="${1:?service_hosts needs a service}" label="" host=""

    for label in $(service_get "${service}" HOST); do

        host="$(model_fqdn "${label}")"
        printf '%s\n' "${host}"

    done

}
service_host () {

    local hosts=()

    mapfile -t hosts < <(service_hosts "${1:?service_host needs a service}")

    printf '%s' "${hosts[0]:-}"

}
service_url () {

    local service="${1:?service_url needs a service}" host=""

    host="$(service_host "${service}")"

    if [[ -n "${host}" ]]; then

        printf 'https://%s' "${host}"
        return 0

    fi

    printf 'http://%s:%s' "${service}" "$(service_get "${service}" PORT)"

}
service_uses () {

    service_get "${1:?service_uses needs a service}" USES

}
service_calls () {

    service_get "${1:?service_calls needs a service}" CALLS

}
service_callers () {

    local service="${1:?service_callers needs a service}" other="" callee=""

    for other in ${SERVICES:-}; do

        for callee in $(service_calls "${other}"); do

            [[ "${callee}" != "${service}" ]] || printf '%s\n' "${other}"

        done

    done

}
service_bucket () {

    model_bucket "${1:?service_bucket needs a service}"

}
service_storage () {

    local service="${1:?service_storage needs a service}" module=""

    for module in $(service_uses "${service}"); do

        [[ "$(module_kind "${module}")" != "storage" ]] || { printf '%s' "${module}"; return 0; }

    done

}
module_dir () {

    local module="${1:?module_dir needs a module}"

    [[ -f "${TEMPLATE_DIR}/module/${module}/module.env" ]] \
        || die "Unknown module '${module}' — infrax carries: $(model_names module | paste -sd ' ' -)"

    printf '%s' "${TEMPLATE_DIR}/module/${module}"

}
module_get () {

    local module="${1:?module_get needs a module}" key="${2:?module_get needs a key}" override=""

    override="$(model_key "${module}")_${key}"

    if [[ -n "${!override:-}" ]]; then

        printf '%s' "${!override}"
        return 0

    fi

    model_read "$(module_dir "${module}")/module.env" "${key}"

}
module_kind () {

    module_get "${1:?module_kind needs a module}" KIND

}
module_mode () {

    local module="${1:?module_mode needs a module}" mode="" kind=""

    mode="$(module_get "${module}" MODE)"
    kind="$(module_kind "${module}")"

    if [[ -z "${mode}" ]]; then

        case "${kind}" in
            storage  ) mode="${STORAGE_MODE}" ;;
            database ) mode="cluster"; [[ "${DATA_MODE}" != "managed" || "$(module_get "${module}" MANAGED)" != "true" ]] || mode="managed" ;;
            *        ) mode="cluster" ;;
        esac

    fi

    [[ " $(module_get "${module}" MODES) " == *" ${mode} "* ]] \
        || die "Module '${module}' runs as: $(module_get "${module}" MODES) — '${mode}' is not one of them"

    printf '%s' "${mode}"

}
module_host () {

    printf '%s' "${1:?module_host needs a module}"

}
module_users () {

    local module="${1:?module_users needs a module}" service="" used=""

    for service in ${SERVICES:-}; do

        for used in $(service_uses "${service}"); do

            [[ "${used}" != "${module}" ]] || printf '%s\n' "${service}"

        done

    done

}
module_root_password () {

    secret_require "$(model_key "${1:?module_root_password needs a module}")_PASSWORD"

}
model_modules () {

    local kind="${1:-}" module=""

    for module in ${MODULES:-}; do

        [[ -z "${kind}" || " ${kind} " == *" $(module_kind "${module}") "* ]] && printf '%s\n' "${module}"

    done

    return 0

}
model_hosts () {

    local service="" module="" label="" host=""

    for service in ${SERVICES:-}; do

        service_hosts "${service}"

    done

    for module in $(model_modules tool); do

        for label in $(module_get "${module}" HOST); do

            host="$(model_fqdn "${label}")"
            printf '%s\n' "${host}"

        done

    done

    if [[ "${OBSERVABILITY_ENABLED}" == "true" && -n "${GRAFANA_HOST:-}" && -n "${SERVICES:-}" ]]; then

        host="$(model_fqdn "${GRAFANA_HOST}")"
        printf '%s\n' "${host}"

    fi

}
model_public () {

    local service="" module=""

    for service in ${SERVICES:-}; do

        [[ -z "$(service_get "${service}" HOST)" ]] || return 0

    done

    for module in $(model_modules tool); do

        [[ -z "$(module_get "${module}" HOST)" ]] || return 0

    done

    return 1

}
bind_password () {

    local module="${1:?bind_password needs a module}" service="${2:?bind_password needs a service}" root=""

    root="$(module_root_password "${module}")"

    printf 'infrax:%s:%s:%s:%s' "${PROJECT}" "${module}" "${service}" "${root}" | sha256sum | cut -c1-32

}
bind_file () {

    local module="${1:?bind_file needs a module}" style="${2:?bind_file needs a style}" mode="${3:?bind_file needs a mode}" dir="" name=""

    dir="$(module_dir "${module}")"

    for name in "bind.${style}.${mode}.env" "bind.${style}.env" "bind.url.${mode}.env" "bind.url.env"; do

        [[ -f "${dir}/${name}" ]] || continue

        printf '%s' "${dir}/${name}"
        return 0

    done

}
bind_facts () {

    local service="${1:?bind_facts needs a service}" module="${2:?bind_facts needs a module}" mode="${3:?bind_facts needs a mode}" primary="${4:-false}" url="" key="" value=""

    export BIND_SERVICE="${service}" BIND_HOST="" BIND_PORT="" BIND_USER="" BIND_DATABASE="" BIND_PASSWORD="" BIND_PASSWORD_URI=""
    export BIND_SSLMODE="" BIND_URL="" BIND_PRIMARY_URL="" BIND_PREFIX="" BIND_BUCKET="" BIND_REGION="" BIND_ENDPOINT="" BIND_SCHEME="" BIND_PATH=""

    case "$(module_kind "${module}")" in

        database )
            BIND_HOST="$(module_host "${module}")"
            BIND_PORT="$(module_get "${module}" PORT)"
            BIND_USER="$(model_ident "${service}")"
            BIND_DATABASE="${BIND_USER}"
            BIND_PASSWORD="$(bind_password "${module}" "${service}")"
            BIND_PASSWORD_URI="${BIND_PASSWORD}"
            BIND_SSLMODE="$(module_get "${module}" "SSLMODE_${mode^^}")" ;;

        cache )
            BIND_HOST="$(module_host "${module}")"
            BIND_PORT="$(module_get "${module}" PORT)"
            BIND_PASSWORD="$(module_root_password "${module}")"
            BIND_PASSWORD_URI="$(uri_encode "${BIND_PASSWORD}")"
            BIND_PREFIX="$(model_ident "${service}")_" ;;

        storage )
            BIND_BUCKET="$(service_bucket "${service}")"
            BIND_PATH="$(service_get "${service}" MOUNT)"

            while IFS='=' read -r key value; do

                [[ -n "${key}" ]] || continue
                export "BIND_${key}=${value}"

            done < <(cloud storage_facts) ;;

    esac

    url="$(model_read "$(module_dir "${module}")/module.env" URL | render_text)"

    export BIND_URL="${url}"

    [[ "${primary}" != "true" ]] || export BIND_PRIMARY_URL="${url}"

}
bind_module () {

    local service="${1}" module="${2}" style="${3}" primary="${4}" mode="" file=""

    mode="$(module_mode "${module}")"
    file="$(bind_file "${module}" "${style}" "${mode}")"

    [[ -n "${file}" ]] || return 0

    (

        bind_facts "${service}" "${module}" "${mode}" "${primary}"
        render_text < "${file}"
        printf '\n'

    )

}
bind_env () {

    local service="${1:?bind_env needs a service}" style="" module="" primary=""

    style="$(service_get "${service}" BIND)"

    for module in $(service_uses "${service}"); do

        if [[ "$(module_kind "${module}")" != "database" ]]; then

            bind_module "${service}" "${module}" "${style}" false

        elif [[ -z "${primary}" ]]; then

            primary="${module}"
            bind_module "${service}" "${module}" "${style}" true

        else

            bind_module "${service}" "${module}" url false

        fi

    done

}
model_tools_for () {

    local target="${1:?model_tools_for needs a module}" module=""

    for module in $(model_modules tool); do

        [[ "$(module_get "${module}" TARGET)" != "${target}" ]] || printf '%s\n' "${module}"

    done

}
model_reserved () {

    printf '%s ' root gateway observability log-shipper envoy-gateway cert-manager cluster-autoscaler metrics-server cloud-metrics \
        "${METRICS_RELEASE}" "${LOGS_RELEASE}" registry-refresher load

}
model_label () {

    [[ "${1:-}" =~ ^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$ ]]

}
model_fail () {

    err "Manifest: $*"
    MODEL_FAULTS=$(( ${MODEL_FAULTS:-0} + 1 ))

}
model_verify_service () {

    local service="${1}" runtime="" key="" value="" process="" module="" callee="" label=""

    model_label "${service}" || model_fail "service '${service}' is not a lowercase dns label"
    [[ " $(model_reserved) " != *" ${service} "* ]] || model_fail "service '${service}' takes a name the platform reserves"
    [[ " ${MODULES:-} " != *" ${service} "* ]] || model_fail "service '${service}' shares its name with a module"

    key="$(service_var "${service}" RUNTIME)"
    runtime="${!key:-}"

    if [[ -z "${runtime}" || ! -f "${TEMPLATE_DIR}/runtime/${runtime}/profile.env" ]]; then

        model_fail "${key} must name one of: $(model_names runtime | paste -sd ' ' -)"
        return 0

    fi

    [[ -d "${REPO_ROOT}/$(service_path "${service}")" ]] || model_fail "service '${service}' builds from $(service_path "${service}")/, which does not exist"

    value="$(service_get "${service}" PORT)"
    [[ "${value}" =~ ^[0-9]+$ ]] || model_fail "service '${service}' needs a numeric PORT"

    for process in $(service_processes "${service}"); do

        model_label "${process}" || model_fail "service '${service}' runs a process named '${process}', which is not a dns label"
        [[ "${process}" == "web" || -n "$(service_get "${service}" "$(model_key "${process}")_COMMAND")" ]] \
            || model_fail "service '${service}' runs '${process}' without a command — set $(service_var "${service}" "$(model_key "${process}")_COMMAND")"

    done

    for module in $(service_uses "${service}"); do

        [[ " ${MODULES:-} " == *" ${module} "* ]] || { model_fail "service '${service}' uses '${module}', which MODULES does not declare"; continue; }
        [[ "$(module_kind "${module}")" != "tool" ]] || model_fail "service '${service}' uses the tool '${module}' — tools serve people, not services"

    done

    for callee in $(service_calls "${service}"); do

        [[ " ${SERVICES:-} " == *" ${callee} "* ]] || model_fail "service '${service}' calls '${callee}', which SERVICES does not declare"
        [[ "${callee}" != "${service}" ]] || model_fail "service '${service}' calls itself"

    done

    for label in $(service_get "${service}" HOST); do

        model_label "${label}" || model_fail "service '${service}' answers on '${label}', which is not a dns label"

    done

}
model_verify_module () {

    local module="${1}" target=""

    [[ -f "${TEMPLATE_DIR}/module/${module}/module.env" ]] || { model_fail "module '${module}' is not one infrax carries: $(model_names module | paste -sd ' ' -)"; return 0; }

    [[ " $(module_get "${module}" MODES) " == *" $(module_mode "${module}") "* ]] || model_fail "module '${module}' cannot run as $(module_mode "${module}")"

    target="$(module_get "${module}" TARGET)"

    [[ -z "${target}" || " ${MODULES:-} " == *" ${target} "* ]] || model_fail "tool '${module}' administers '${target}', which MODULES does not declare"

}
model_verify_keys () {

    local file="" key="" known="" service="" rest="" name=""

    known=" $(infrax_keys | paste -sd ' ' -) "

    for file in "${REPO_ROOT}"/infrax.env "${REPO_ROOT}"/infrax.*.env; do

        [[ -f "${file}" ]] || continue

        while IFS= read -r key; do

            [[ "${known}" != *" ${key} "* ]] || continue

            if [[ "${key}" == SERVICE_* ]]; then

                rest="${key#SERVICE_}"

                for service in ${SERVICES:-}; do

                    name="$(model_key "${service}")_"
                    [[ "${rest}" != "${name}"* ]] || { rest=""; break; }

                done

                [[ -z "${rest}" ]] || model_fail "$(basename "${file}"): ${key} names no declared service"
                continue

            fi

            for name in $(model_names runtime) $(model_names module); do

                [[ "${key}" != "$(model_key "${name}")_"* ]] || { key=""; break; }

            done

            [[ -z "${key}" ]] || model_fail "$(basename "${file}"): ${key} is not a key infrax reads"

        done < <(model_keys "${file}")

    done

}
## the manifest law — names, runtimes, modules, uses, calls and keys are what infrax can honour, or nothing runs
model_verify () {

    local service="" module=""

    MODEL_FAULTS=0

    [[ -n "${PROJECT:-}" ]] || model_fail "PROJECT is empty — every name infrax mints starts from it"
    [[ -z "${PROJECT:-}" ]] || model_label "${PROJECT}" || model_fail "PROJECT '${PROJECT}' is not a lowercase dns label"
    [[ -n "${SERVICES:-}" ]] || model_fail "SERVICES is empty — a platform runs at least one service"
    [[ -n "${BASE_DOMAIN:-}" ]] || ! model_public || model_fail "BASE_DOMAIN is empty and something answers publicly — every public name lives under it"

    for service in ${SERVICES:-}; do model_verify_service "${service}"; done
    for module in ${MODULES:-}; do model_verify_module "${module}"; done

    [[ "$(printf '%s\n' ${SERVICES:-} ${MODULES:-} | sort | uniq -d)" == "" ]] || model_fail "a name is declared twice across SERVICES and MODULES"

    model_verify_keys

    (( MODEL_FAULTS == 0 )) || die "The manifest carries ${MODEL_FAULTS} fault(s) — the lines above say which"

    succ "Manifest holds — $(wc -w <<< "${SERVICES}") service(s), $(wc -w <<< "${MODULES:-}") module(s)."

}
bind_identity () {

    local service="${1:?bind_identity needs a service}" module="" key="" password=""

    for module in $(service_uses "${service}"); do

        [[ "$(module_kind "${module}")" == "database" ]] || continue

        key="$(model_key "${module}")"
        password="$(bind_password "${module}" "${service}")"

        printf '%s_USER=%s\n' "${key}" "$(model_ident "${service}")"
        printf '%s_DATABASE=%s\n' "${key}" "$(model_ident "${service}")"
        printf '%s_PASSWORD=%s\n' "${key}" "${password}"

    done

}
