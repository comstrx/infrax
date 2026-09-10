#!/usr/bin/env bash

## cluster plumbing — secrets, pull access, the gitops handover, the converge

k8s_upsert () {

    "$@" --dry-run=client -o yaml | kubectl apply -f -

}
k8s_tools_auth () {

    printf 'tools-auth'

}
## print or fetch the kubeconfig for this stack
k8s_kubeconfig () {

    if [[ "${CLUSTER_SOURCE}" == "managed" ]]; then

        cloud kubeconfig
        return 0

    fi

    server_kubeconfig

}
k8s_namespace () {

    ensure kubectl

    k8s_upsert kubectl create namespace "${1:-${K8S_NAMESPACE}}" >/dev/null

}
k8s_secret () {

    local name="${1:?k8s_secret needs a name}" file="${2:?k8s_secret needs a file}" before="" checksum=""

    before="$(kubectl -n "${K8S_NAMESPACE}" get secret "${name}" -o jsonpath='{.metadata.annotations.infrax\.io/checksum}' 2>/dev/null || true)"
    checksum="$(sha256sum "${file}" | cut -d' ' -f1)"

    k8s_upsert kubectl create secret generic "${name}" --from-env-file="${file}" -n "${K8S_NAMESPACE}" >/dev/null
    kubectl -n "${K8S_NAMESPACE}" annotate secret "${name}" "infrax.io/checksum=${checksum}" --overwrite >/dev/null

    [[ -n "${before}" && "${before}" != "${checksum}" ]]

}
k8s_secret_service () {

    local service="${1:?k8s_secret_service needs a service}" env="" bind="" deploy=""

    env="$(tmp_file)"
    bind="$(tmp_file)"

    secret_service_env "${service}" "${env}"
    printf 'INFRAX_PROJECT=%s\n' "${PROJECT}" >> "${env}"
    bind_identity "${service}" > "${bind}"

    if k8s_secret "${service}-secrets" "${env}"; then

        for deploy in $(kubectl -n "${K8S_NAMESPACE}" get deploy -l "app.kubernetes.io/name=${service}" -o name 2>/dev/null); do

            run kubectl -n "${K8S_NAMESPACE}" rollout restart "${deploy}"

        done

    fi

    [[ ! -s "${bind}" ]] || k8s_secret "${service}-bind" "${bind}" || true

    rm -f "${env}" "${bind}"

}
k8s_secret_module () {

    local module="${1:?k8s_secret_module needs a module}" file="" password="" user=""

    password="$(module_root_password "${module}")"
    user="$(module_get "${module}" ROOT_USER)"
    file="$(tmp_file)"

    printf 'ROOT_PASSWORD=%s\n' "${password}" > "${file}"
    [[ -z "${user}" ]] || printf 'ROOT_USER=%s\n' "${user}" >> "${file}"

    k8s_secret "${module}-secrets" "${file}" || true

    rm -f "${file}"

}
k8s_secret_tool () {

    local module="${1:?k8s_secret_tool needs a module}" file="" password=""

    [[ "$(module_get "${module}" ROOT_LOGIN)" == "true" ]] || return 0

    password="$(secret_require "$(model_key "${module}")_PASSWORD")"
    file="$(tmp_file)"

    printf 'PASSWORD=%s\n' "${password}" > "${file}"

    k8s_secret "${module}-secrets" "${file}" || true

    rm -f "${file}"

}
k8s_secret_gate () {

    local module="" exposed="" password="" file=""

    for module in $(model_modules tool); do

        [[ -z "$(module_get "${module}" HOST)" ]] || exposed=1

    done

    [[ -n "${exposed}" ]] || return 0

    ensure htpasswd

    password="$(secret_require TOOLS_PASSWORD)"
    file="$(tmp_file)"

    htpasswd -nis admin <<< "${password}" > "${file}" || die "Cannot hash the tools gate"

    k8s_upsert kubectl create secret generic "$(k8s_tools_auth)" --from-file=.htpasswd="${file}" -n "${K8S_NAMESPACE}" >/dev/null

    rm -f "${file}"

}
k8s_secret_backup () {

    local id="" key="" file=""

    id="$(secret_get BACKUP_AWS_ACCESS_KEY_ID)"
    key="$(secret_get BACKUP_AWS_SECRET_ACCESS_KEY)"

    [[ -n "${id}" && -n "${key}" ]] || return 0

    file="$(tmp_file)"

    printf '%s\n' "AWS_ACCESS_KEY_ID=${id}" "AWS_SECRET_ACCESS_KEY=${key}" > "${file}"

    k8s_secret backup-credentials "${file}" || true

    rm -f "${file}"

}
## apply every secret the platform reads — each service's, each module's, the gates — a service restarts only when its own changed
k8s_secrets () {

    local service="" module="" token="" scratch=""

    ensure kubectl

    k8s_namespace "${K8S_NAMESPACE}"

    for module in $(model_modules "database cache"); do k8s_secret_module "${module}"; done
    for module in $(model_modules tool); do k8s_secret_tool "${module}"; done
    for service in ${SERVICES}; do k8s_secret_service "${service}"; done

    k8s_secret_gate
    k8s_secret_backup

    token="$(secret_get CLOUDFLARE_API_TOKEN)"
    scratch="$(tmp_file)"
    chmod 600 "${scratch}"

    if [[ -n "${token}" ]]; then

        k8s_namespace "${CERT_MANAGER_NAMESPACE}"

        printf '%s' "${token}" > "${scratch}"

        k8s_upsert kubectl create secret generic cloudflare-token \
            --from-file=token="${scratch}" \
            -n "${CERT_MANAGER_NAMESPACE}" >/dev/null

    fi

    k8s_watcher_secrets "${scratch}"

    rm -f "${scratch}"

    succ "Secrets applied into '${K8S_NAMESPACE}' — every service, module and gate holds only its own."

}
k8s_watcher_secrets () {

    local scratch="${1:?Missing scratch file}" password="" token=""

    [[ "${OBSERVABILITY_ENABLED}" == "true" ]] || return 0

    password="$(secret_get GRAFANA_PASSWORD)"
    token="$(secret_get ALERT_BOT_TOKEN)"

    [[ -n "${password}" || -n "${ALERT_CHAT_ID}" ]] || return 0

    k8s_namespace "${OBSERVABILITY_NAMESPACE}"

    if [[ -n "${password}" ]]; then

        printf '%s' "${password}" > "${scratch}"

        k8s_upsert kubectl create secret generic grafana-admin \
            --from-literal=username=admin \
            --from-file=password="${scratch}" \
            -n "${OBSERVABILITY_NAMESPACE}" >/dev/null

    fi

    if [[ -n "${ALERT_CHAT_ID}" ]]; then

        [[ -n "${token}" ]] || warn "ALERT_BOT_TOKEN is empty — alertmanager will start, but nothing will reach the chat"

        printf '%s' "${token}" > "${scratch}"

        k8s_upsert kubectl create secret generic alert-sink \
            --from-file=token="${scratch}" \
            -n "${OBSERVABILITY_NAMESPACE}" >/dev/null

    fi

}
k8s_module_rotate () {

    local module="${1:?k8s_module_rotate needs a module}" script="" password=""

    script="$(module_dir "${module}")/scripts/rotate.sh"

    [[ -f "${script}" && "$(module_mode "${module}")" == "cluster" ]] || return 0

    password="$(module_root_password "${module}")"

    { printf '%s\n' "${password}"; cat "${script}"; } \
        | kubectl -n "${K8S_NAMESPACE}" exec -i "statefulset/${module}" -- sh -c 'read -r NEW_PASSWORD; export NEW_PASSWORD; exec sh -s' \
        || die "Cannot move '${module}' onto its new root password — the services would restart onto one it never took"

}
## rotate every secret and move each module and service onto it
k8s_rotate () {

    local module=""

    ensure kubectl

    for module in $(model_modules "database cache"); do k8s_module_rotate "${module}"; done

    k8s_secrets

    for module in $(model_modules "database cache"); do

        [[ "$(module_mode "${module}")" != "cluster" ]] || run kubectl -n "${K8S_NAMESPACE}" rollout restart "statefulset/${module}"

    done

    run kubectl -n "${K8S_NAMESPACE}" rollout restart deployment -l "app.kubernetes.io/managed-by=Helm"

    succ "Secrets rotated — every module took its new root and every workload restarted onto its own."

}
## apply the registry pull secret
k8s_pull_secret () {

    local password="" registry="" user=""

    ensure kubectl

    registry="$(ci_registry)"

    k8s_namespace "${K8S_NAMESPACE}"

    if [[ -n "${REGISTRY_USER}" ]]; then

        password="$(secret_require GIT_TOKEN)"
        user="${REGISTRY_USER}"

    else

        password="$(cloud registry_token)" || die "Cannot fetch a registry token"
        user="$(cloud registry_user)"

    fi

    [[ -n "${password}" && "${password}" != *[[:space:]]* ]] || die "The registry token is not a token — something wrote on stdout while minting it"

    k8s_upsert kubectl create secret docker-registry pull-secret \
        --docker-server="${registry%%/*}" \
        --docker-username="${user}" \
        --docker-password="${password}" \
        -n "${K8S_NAMESPACE}" >/dev/null

    succ "Pull secret applied for ${registry%%/*}."

}
## ONE verb, all stacks: secrets → pull access → argocd owns the cluster from git
k8s_bootstrap () {

    k8s_secrets

    if [[ "${REGISTRY_PULL}" == "true" ]]; then

        k8s_pull_secret

        [[ -n "${REGISTRY_USER}" ]] || cloud registry_refresher

    fi

    argocd_install
    argocd_repo
    argocd_bootstrap

    [[ -z "$(secret_get ARGOCD_PASSWORD)" ]] || argocd_rotate

    if dns_managed; then

        dns_sync || warn "DNS was not pointed at this stack — run '${INFRAX_NAME} dns sync' when its edge has an address"

    fi

    succ "Cluster → GitOps platform — ArgoCD owns it from git."

}
k8s_first_process () {

    local first=""

    read -r first _ <<< "$(service_processes "${1:?k8s_first_process needs a service}")"

    printf '%s' "${first}"

}
## block until argocd has every service on this release and every workload is ready
k8s_verify () {

    local left="${SERVER_ROLLOUT_TRIES}" tag="" service="" pending="" app="" tick=0 workload="" live=""

    ensure kubectl

    tag="$(helm_tag)"

    step "Waiting for ArgoCD to roll ${SERVICES} onto ${tag}"

    while (( left-- )); do

        pending=""

        for service in ${SERVICES}; do

            live="$(kubectl -n "${K8S_NAMESPACE}" get "deploy/${service}-$(k8s_first_process "${service}")" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"

            [[ "${live}" == *":${tag}" ]] || pending+=" ${service}"

        done

        [[ -n "${pending}" ]] || break

        if (( tick++ % ARGOCD_NUDGE_TICKS == 0 )); then

            for app in root ${pending}; do

                argocd_report "${app}"
                ! argocd_stalled "${app}" || argocd_sync "${app}"

            done

            k8s_unhealthy

        fi

        sleep "${SERVER_ROLLOUT_POLL}"

    done

    if [[ -n "${pending}" ]]; then

        argocd_report root
        k8s_status
        k8s_unhealthy

        die "ArgoCD never moved${pending} onto ${tag} — the report above carries the reason"

    fi

    for workload in $(kubectl -n "${K8S_NAMESPACE}" get deploy,statefulset -l "app.kubernetes.io/managed-by=Helm" -o name 2>/dev/null); do

        run kubectl -n "${K8S_NAMESPACE}" rollout status "${workload}" --timeout="${ROLLOUT_TIMEOUT}" && continue

        k8s_unhealthy

        die "'${workload}' never became ready on ${tag} — the report above carries the reason"

    done

    succ "Release ${tag} rolled out — every service and module this stack runs is live on it."

}
## converge the cluster onto this release — ssh boxes through the server, managed clusters directly
k8s_ensure () {

    if [[ "${CLUSTER_SOURCE}" != "managed" ]]; then

        server_ensure
        return 0

    fi

    k8s_kubeconfig

    if kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then

        k8s_secrets

        [[ "${REGISTRY_PULL}" != "true" ]] || k8s_pull_secret

        argocd_bootstrap

    else

        k8s_bootstrap

    fi

    k8s_verify

}
## pods, services and routes at a glance
k8s_status () {

    ensure kubectl

    run kubectl get pods,svc,httproute -n "${K8S_NAMESPACE}"

}
## every pod that is not ready, the reason it is not, and the last words it said
k8s_unhealthy () {

    local pod="" died=""

    ensure kubectl jq

    while IFS= read -r pod; do

        warn "${pod} is not ready"

        kubectl -n "${K8S_NAMESPACE}" get "${pod}" -o jsonpath='{range .status.containerStatuses[*]}  {.name}: restarts={.restartCount} now={.state.waiting.reason}{.state.terminated.reason}{.state.running.startedAt} last={.lastState.terminated.reason}/{.lastState.terminated.exitCode}{"\n"}{end}' >&2 2>/dev/null || true

        died="$(kubectl -n "${K8S_NAMESPACE}" get "${pod}" -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}' 2>/dev/null)"

        [[ -n "${died}" ]] || continue

        kubectl -n "${K8S_NAMESPACE}" logs "${pod}" --all-containers --tail="${POD_LOG_LINES}" --previous >&2 2>/dev/null || true

    done < <(kubectl -n "${K8S_NAMESPACE}" get pods -o json 2>/dev/null \
        | jq -r '.items[] | select(.status.phase != "Succeeded") | select(.status.phase == "Pending" or ([.status.containerStatuses[]? | .ready] | all | not)) | "pod/" + .metadata.name')

    return 0

}
## tail the logs of one service process — web unless named
k8s_logs () {

    local service="${1:?Usage: k8s logs <service> [process] [lines]}"

    ensure kubectl

    run kubectl logs -n "${K8S_NAMESPACE}" -l "app.kubernetes.io/name=${service},app.kubernetes.io/component=${2:-web}" --tail="${3:-100}" -f

}
## reach one service or module from this machine on its own port
k8s_forward () {

    local name="${1:?Usage: k8s forward <service|module> [local-port]}" port=""

    ensure kubectl

    if [[ " ${SERVICES:-} " == *" ${name} "* ]]; then port="$(service_get "${name}" PORT)"; else port="$(module_get "${name}" PORT)"; fi

    info "localhost:${2:-${port}} → ${name}:${port} — Ctrl-C to stop"

    kubectl -n "${K8S_NAMESPACE}" port-forward "svc/${name}" "${2:-${port}}:${port}"

}
k8s_gateway_selector () {

    printf 'gateway.envoyproxy.io/owning-gateway-name=gateway'

}
k8s_gateway_service () {

    kubectl -n "${ENVOY_NAMESPACE}" get svc -l "$(k8s_gateway_selector)" -o name 2>/dev/null | head -1 || true

}
k8s_gateway_address () {

    local field=""

    case "${1:?Missing field: hostname|ip|clusterIP}" in
        hostname  ) field='{.items[0].status.loadBalancer.ingress[0].hostname}' ;;
        ip        ) field='{.items[0].status.loadBalancer.ingress[0].ip}' ;;
        clusterIP ) field='{.items[0].spec.clusterIP}' ;;
        *         ) die "Unknown gateway address field: ${1}" ;;
    esac

    kubectl -n "${ENVOY_NAMESPACE}" get svc -l "$(k8s_gateway_selector)" -o jsonpath="${field}" 2>/dev/null

}
