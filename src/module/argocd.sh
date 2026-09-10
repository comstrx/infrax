#!/usr/bin/env bash

## gitops — argocd installation and the app-of-apps

## install argocd at the pinned version
argocd_install () {

    ensure kubectl

    k8s_namespace "${ARGOCD_NAMESPACE}"

    run kubectl apply -n "${ARGOCD_NAMESPACE}" --server-side --force-conflicts \
        -f "${ARGOCD_MANIFESTS}/${ARGOCD_VERSION}/manifests/install.yaml"

    run kubectl -n "${ARGOCD_NAMESPACE}" patch configmap argocd-cm --patch-file "${TEMPLATE_DIR}/argocd/health.yaml"

    run kubectl -n "${ARGOCD_NAMESPACE}" rollout status deploy/argocd-server --timeout=300s

    succ "ArgoCD ${ARGOCD_VERSION} installed."

}
## print the current admin password
argocd_password () {

    ensure kubectl

    kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    log ""

}
## move admin onto ARGOCD_PASSWORD and drop the bootstrap secret
argocd_rotate () {

    local hash="" password=""

    ensure kubectl htpasswd

    password="$(secret_require ARGOCD_PASSWORD)"
    hash="$(htpasswd -niBC 10 "" <<< "${password}" | tr -d ':\n')"
    hash="${hash/#\$2y/\$2a}"

    kubectl -n "${ARGOCD_NAMESPACE}" patch secret argocd-secret --type merge \
        -p "{\"stringData\":{\"admin.password\":\"${hash}\",\"admin.passwordMtime\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}" >/dev/null \
        || die "Cannot move the ArgoCD admin onto ARGOCD_PASSWORD"

    run kubectl -n "${ARGOCD_NAMESPACE}" delete secret argocd-initial-admin-secret --ignore-not-found

    succ "ArgoCD admin moved onto ARGOCD_PASSWORD — the bootstrap secret is gone."

}
## apply the app-of-apps — argocd owns the cluster from git
argocd_bootstrap () {

    local services=() stores=() tools=() hosts=()

    ensure kubectl

    if [[ "${AUTOSCALER_ENABLED}" == "true" && -z "${AUTOSCALER_ROLE_ARN}" ]]; then

        AUTOSCALER_ROLE_ARN="$(tofu_output autoscaler_role_arn 2>/dev/null)" || die "Missing AUTOSCALER_ROLE_ARN — apply the stack first"

    fi

    if [[ -n "${EDGE_TYPE}" && -n "${PROVISIONER}" && "${EDGE_FIXED_IPS}" == "true" && -z "${EDGE_EIPS}" ]]; then

        EDGE_EIPS="$(tofu_output edge_eips 2>/dev/null)" || die "Missing EDGE_EIPS — the edge holds fixed addresses, apply the stack first"

    fi

    export AUTOSCALER_ROLE_ARN EDGE_EIPS

    read -ra services <<< "${SERVICES}"
    mapfile -t stores < <(model_modules "database cache")
    mapfile -t tools < <(model_modules tool)
    mapfile -t hosts < <(model_hosts)

    EDGE_ANNOTATIONS="$(cloud edge_annotations)"
    IMAGE_TAG="$(helm_tag)"
    APPS_SERVICES="$(yaml_list "${services[@]}")"
    APPS_DATA="$(yaml_list "${stores[@]}")"
    APPS_TOOLS="$(yaml_list "${tools[@]}")"
    APPS_HOSTNAMES="$(yaml_list "${hosts[@]}")"
    CLOUD_REGION="$(cloud region)"
    GRAFANA_HOSTNAME=""

    [[ "${OBSERVABILITY_ENABLED}" != "true" || -z "${GRAFANA_HOST}" ]] || GRAFANA_HOSTNAME="$(model_fqdn "${GRAFANA_HOST}")"

    export EDGE_ANNOTATIONS IMAGE_TAG APPS_SERVICES APPS_DATA APPS_TOOLS APPS_HOSTNAMES CLOUD_REGION GRAFANA_HOSTNAME

    render "${TEMPLATE_DIR}/argocd/project.yaml" "${BUILD_DIR}/argocd/project.yaml"
    render "${TEMPLATE_DIR}/argocd/root.yaml" "${BUILD_DIR}/argocd/root.yaml"

    run kubectl apply -f "${BUILD_DIR}/argocd/project.yaml"

    run kubectl delete application root -n "${ARGOCD_NAMESPACE}" --cascade=orphan --ignore-not-found

    run kubectl apply -f "${BUILD_DIR}/argocd/root.yaml"

    succ "App-of-apps bootstrapped — ArgoCD now owns the cluster from git."

}
## apply the git repository credentials — a public repository needs none
argocd_repo () {

    local token=""

    ensure kubectl

    token="$(secret_get GIT_TOKEN)"

    [[ -n "${token}" ]] || { info "No GIT_TOKEN — ArgoCD reads ${GIT_REPO_URL} as a public repository."; return 0; }

    k8s_upsert kubectl create secret generic repo-creds \
        -n "${ARGOCD_NAMESPACE}" \
        --from-literal=type=git \
        --from-literal=url="${GIT_REPO_URL}" \
        --from-literal=username=git \
        --from-literal=password="${token}" >/dev/null

    kubectl label secret repo-creds -n "${ARGOCD_NAMESPACE}" \
        argocd.argoproj.io/secret-type=repository --overwrite >/dev/null

    succ "Repository credentials applied."

}
## true when an application gave up on its revision, or has held one operation longer than any sync should — a retrying operation pins argocd to the revision it started on, so the newest commit is never even looked at
argocd_stalled () {

    local app="${1:-root}" phase="" started="" age=0 terminate='{"status":{"operationState":{"phase":"Terminating"}}}'

    read -r phase started < <(kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" -o jsonpath='{.status.sync.status}/{.status.operationState.phase} {.status.operationState.startedAt}' 2>/dev/null)

    case "${phase}" in

        */Failed | */Error ) return 0 ;;
        */Running ) [[ -n "${started}" ]] || return 1 ;;
        * ) return 1 ;;

    esac

    age=$(( $(date +%s) - $(date -d "${started}" +%s) ))

    (( age > ARGOCD_SYNC_STALL )) || return 1

    warn "Sync of '${app}' has run ${age}s — terminating it so the newest revision can take over"

    kubectl -n "${ARGOCD_NAMESPACE}" patch application "${app}" --type merge -p "${terminate}" >/dev/null 2>&1 \
        || kubectl -n "${ARGOCD_NAMESPACE}" patch application "${app}" --subresource=status --type merge -p "${terminate}" >/dev/null 2>&1 \
        || true

}
## what argocd thinks of an application right now — sync, health, the revision it sits on, and why its last operation stopped
argocd_report () {

    local app="${1:-root}" report=""

    ensure kubectl

    report="$(kubectl -n "${ARGOCD_NAMESPACE}" get application "${app}" \
        -o jsonpath='{.metadata.name}: sync={.status.sync.status} health={.status.health.status} phase={.status.operationState.phase} revision={.status.sync.revision}{"\n"}  reason: {.status.operationState.message}{"\n"}{range .status.conditions[*]}  {.type}: {.message}{"\n"}{end}' 2>/dev/null || true)"

    [[ -n "${report}" ]] || return 0

    printf '%s\n' "${report}" >&2

}
## force-sync an application now
argocd_sync () {

    ensure kubectl

    run kubectl -n "${ARGOCD_NAMESPACE}" patch application "${1:-root}" \
        --type merge -p "{\"operation\":{\"initiatedBy\":{\"username\":\"${INFRAX_NAME}\"},\"sync\":{}}}"

}
