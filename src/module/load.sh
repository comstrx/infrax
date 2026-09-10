#!/usr/bin/env bash

## load testing with k6 inside the cluster — any public service, any paths

load_target () {

    local service="${1}" host=""

    app_service "${service}" >/dev/null

    host="$(service_host "${service}")"

    [[ -n "${host}" ]] || die "'${service}' answers on no public host — load reaches a service through its edge"

    LOAD_TARGET_HOST="${host}"
    LOAD_TARGET_IP="$(k8s_gateway_address clusterIP)"

    [[ -n "${LOAD_TARGET_IP}" ]] || die "No envoy gateway service — is the gateway app synced?"

    export LOAD_TARGET_HOST LOAD_TARGET_IP

}
## fire the load at one public service — <service> [path,path…], at LOAD_RATE across LOAD_PODS
load_run () {

    local service="${1:?Usage: load run <service> [path,path…]}" file=""

    ensure kubectl envsubst

    load_target "${service}"

    LOAD_PATHS="${2:-$(service_get "${service}" HEALTH)}"
    LOAD_RATE_PER_POD=$(( LOAD_RATE / LOAD_PODS ))

    (( LOAD_RATE_PER_POD > 0 )) || die "LOAD_RATE must be at least LOAD_PODS"

    export LOAD_PATHS LOAD_RATE_PER_POD

    kubectl -n "${K8S_NAMESPACE}" delete job load --ignore-not-found >/dev/null

    k8s_upsert kubectl -n "${K8S_NAMESPACE}" create configmap load-script \
        --from-file=load.js="${TEMPLATE_DIR}/k8s/load.js" >/dev/null

    file="$(tmp_file)"

    render "${TEMPLATE_DIR}/k8s/load.yaml" "${file}"
    run kubectl apply -f "${file}"

    rm -f "${file}"

    succ "Load running on ${LOAD_TARGET_HOST} — ${LOAD_RATE} rps across ${LOAD_PODS} pod(s)."

}
## watch the run live
load_watch () {

    ensure kubectl

    kubectl -n "${K8S_NAMESPACE}" get pods -l job-name=load --no-headers
    kubectl -n "${K8S_NAMESPACE}" get hpa --no-headers
    kubectl get nodes --no-headers

}
## summarise the last run
load_report () {

    ensure kubectl

    kubectl -n "${K8S_NAMESPACE}" logs job/load --tail=-1 | sed -n '/TOTAL RESULTS/,$p'

}
## remove every load artifact
load_clean () {

    ensure kubectl

    kubectl -n "${K8S_NAMESPACE}" delete job load --ignore-not-found
    kubectl -n "${K8S_NAMESPACE}" delete configmap load-script --ignore-not-found

    succ "Load artifacts removed."

}
