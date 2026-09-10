#!/usr/bin/env bash

## secret resolution diagnostics — never prints values

secrets_passwords () {

    local module=""

    for module in $(model_modules "database cache"); do

        printf '%s_PASSWORD\n' "$(model_key "${module}")"

    done

    for module in $(model_modules tool); do

        [[ "$(module_get "${module}" PASSWORD)" != "true" ]] || printf '%s_PASSWORD\n' "$(model_key "${module}")"
        [[ -z "$(module_get "${module}" HOST)" ]] || printf 'TOOLS_PASSWORD\n'

    done

}
## the keys this stack cannot release without — grown by what the stack provisions, reaches, runs and exposes
secrets_required () {

    local keys="PROJECT GIT_REPO_URL"

    if [[ -n "${PROVISIONER}" ]]; then keys+=" $(cloud required_secrets)"; else keys+=" SSH_HOST"; fi

    [[ "${CLUSTER_SOURCE}" != "ssh" ]] || keys+=" SSH_PRIVATE_KEY"
    [[ "${CLUSTER_SOURCE}" != "ssh" || -z "${PROVISIONER}" ]] || keys+=" SSH_PUBLIC_KEY"
    [[ -z "${REGISTRY_USER}" ]] || keys+=" GIT_TOKEN"
    [[ "${GATEWAY_TLS}" != "true" || "${GATEWAY_DNS01}" != "true" ]] || ! model_public || keys+=" CLOUDFLARE_API_TOKEN"
    [[ -z "${DNS_PROVIDER}" ]] || keys+=" CLOUDFLARE_API_TOKEN"
    ! model_public || keys+=" BASE_DOMAIN"

    keys+=" $(secrets_passwords | sort -u | paste -sd ' ' -)"

    printf ' %s ' "${keys}"

}
## which expected secrets resolve and which are missing — a missing required one refuses the release
secrets_check () {

    local key="" value="" missing=0 broken=0 required=""

    required="$(secrets_required)"

    info "Manifest for '${STACK}' — provisioner: ${PROVISIONER:-none} · cluster: ${CLUSTER_SOURCE} · cloud: ${CLOUD}"

    while IFS= read -r key; do

        [[ -n "${key}" ]] || continue

        value="$(secret_get "${key}")"

        if [[ -n "${value}" ]]; then

            succ "${key}"

        elif [[ "${required}" == *" ${key} "* ]]; then

            err "${key} — REQUIRED, missing"
            broken=1

        else

            warn "${key} — missing"
            missing=1

        fi

    done < <({ tr ' ' '\n' <<< "${required}"; secret_keys; } | sort -u)

    (( broken == 0 )) || die "Required secrets are missing — the platform cannot run without them."

    if (( missing == 0 )); then succ "All secrets resolve."; else warn "Optional secrets are missing — their features stay dark until filled."; fi

    secrets_drift

}
## every service environment must carry what its runtime demands, and must not smuggle placeholders or bound keys
secrets_drift () {

    local service="" line="" key="" value="" demanded="" seen="" loose=0 lacking=0

    for service in ${SERVICES:-}; do

        seen=" "

        while IFS= read -r line; do

            key="${line%%=*}"
            value="${line#*=}"
            seen+="${key} "

            [[ ! "${value}" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]] \
                || { err "${service}: ${key} names \${${BASH_REMATCH[1]}} — this becomes a kubernetes secret, and kubernetes expands nothing"; loose=$(( loose + 1 )); }

        done < <(secret_env_pairs "$(service_var "${service}" ENV_FILE)")

        for demanded in $(service_get "${service}" SECRETS); do

            [[ "${seen}" == *" ${demanded} "* ]] || { err "${service}: its runtime needs ${demanded} in $(service_var "${service}" ENV_FILE)"; lacking=$(( lacking + 1 )); }

        done

    done

    (( loose == 0 )) || die "Service environments ship ${loose} placeholder(s) the pods would receive as literal text"
    (( lacking == 0 )) || die "Service environments lack ${lacking} key(s) their runtimes cannot boot without"

    succ "Every service environment carries what its runtime demands."

}
## the key names one service receives — its bindings and its own environment, never values
secrets_env () {

    local service="${1:?Usage: secrets env <service>}" file="" n=0 key=""

    file="$(tmp_file)"

    secret_service_env "${service}" "${file}"

    while IFS= read -r key; do printf '  %s\n' "${key%%=*}"; n=$(( n + 1 )); done < "${file}"

    rm -f "${file}"

    succ "${n} keys ride into ${service}."

}
## mint every missing password this stack needs into a secret file — random, never printed
secrets_mint () {

    local file="${1:?Usage: secrets mint <file>}" key="" minted=0

    umask 077
    touch "${file}"
    chmod 600 "${file}"

    for key in $(secrets_passwords | sort -u) GRAFANA_PASSWORD ARGOCD_PASSWORD; do

        [[ -z "$(secret_get "${key}")" ]] || continue
        ! grep -qE "^${key}=." "${file}" || continue

        printf '%s=%s\n' "${key}" "$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')" >> "${file}"
        minted=$(( minted + 1 ))

    done

    succ "${minted} password(s) minted into ${file}."

}
## law: the two examples are disjoint, and every key they name is read by the platform
secrets_example () {

    local key="" code="" shared="" unread=""

    code="$(infrax_code | sed '/^infrax_manifest () {/,/^}/d' | sed '/^infrax_defaults () {/,/^}/d')"
    shared="$(comm -12 <(infrax_defaults | sed -nE 's/^([A-Z][A-Z0-9_]*)=.*/\1/p' | sort) <(secret_keys | sort) | paste -sd ' ' -)"

    [[ -z "${shared}" ]] || die "A key lives in both examples — pick one home: ${shared}"

    while IFS= read -r key; do

        [[ " ${FORGE_KEYS} " != *" ${key} "* ]] || continue

        grep -qE "\b${key}\b" <<< "${code}" || grep -rqE "\b${key}\b" "${TEMPLATE_DIR}" || unread+=" ${key}"

    done < <(infrax_keys)

    [[ -z "${unread}" ]] || die "The examples name keys nobody reads:${unread}"

    succ "Examples are disjoint and every key they name is read by the platform."

}
## the full list of keys this platform expects from outside
secrets_keys () {

    secret_keys

}
