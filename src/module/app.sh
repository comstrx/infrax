#!/usr/bin/env bash

## the services themselves — one-off commands inside the live release, wherever the cluster lives

app_service () {

    local service="${1:-}"

    [[ -n "${service}" && " ${SERVICES:-} " == *" ${service} "* ]] || die "Name one of this project's services: ${SERVICES:-none}"

    printf '%s' "${service}"

}
app_image () {

    local service="${1:?app_image needs a service}"

    kubectl -n "${K8S_NAMESPACE}" get "deploy/${service}-$(k8s_first_process "${service}")" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true

}
app_reachable () {

    command -v kubectl >/dev/null 2>&1 && kubectl get --raw=/readyz --request-timeout="${RUN_REACH}s" >/dev/null 2>&1

}
## hand the verb to the bundle on the server when the cluster is out of reach from here
app_forward () {

    local verb="${1:?Missing verb}"

    shift

    [[ "${CLUSTER_SOURCE}" != "managed" ]] || die "No cluster reach — run: ${INFRAX_NAME} k8s kubeconfig"

    server_run "$(server_remote) app ${verb} $(printf '%q ' "$@")"

}
app_phase () {

    kubectl -n "${K8S_NAMESPACE}" get pod -l "job-name=${1}" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || true

}
app_outcome () {

    kubectl -n "${K8S_NAMESPACE}" get "job/${1}" -o jsonpath='{.status.succeeded}/{.status.failed}' 2>/dev/null || true

}
app_settled () {

    [[ "${1}" != "/" ]]

}
app_verdict () {

    [[ "${1}" == 1/* ]]

}
## render the job that runs one command on a service's release — its image, env, secrets and storage
app_manifest () {

    local dst="${1:?Missing destination}" name="${2:?Missing job name}" service="${3:?Missing service}" image="${4:?Missing image}" storage=""

    shift 4

    RUN_COMMAND="$(argv_list "$@")"
    [[ $# -ne 1 || "${1}" != \[* ]] || RUN_COMMAND="${1}"

    RUN_NAME="${name}"
    RUN_SERVICE="${service}"
    RUN_IMAGE="${image}"
    RUN_USER="$(service_get "${service}" USER)"
    RUN_PORT="$(service_get "${service}" PORT)"
    RUN_PULL_SECRETS="[]"
    RUN_MOUNTS="[]"
    RUN_VOLUMES="[]"

    [[ "${REGISTRY_PULL}" != "true" ]] || RUN_PULL_SECRETS="[{name: pull-secret}]"

    storage="$(service_storage "${service}")"

    if [[ -n "${storage}" ]] && [[ "$(module_mode "${storage}")" == "volume" ]]; then

        RUN_MOUNTS="[{name: storage, mountPath: $(service_get "${service}" MOUNT)}]"
        RUN_VOLUMES="[{name: storage, persistentVolumeClaim: {claimName: ${service}-storage}}]"

    fi

    export RUN_COMMAND RUN_NAME RUN_SERVICE RUN_IMAGE RUN_USER RUN_PORT RUN_PULL_SECRETS RUN_MOUNTS RUN_VOLUMES

    render "${TEMPLATE_DIR}/k8s/run.yaml" "${dst}"

}
## run one command as a job on the live release of one service — its image, env and secrets; the job's exit code is yours
app_run () {

    local service="" name="" image="" file="" phase="" waited=0

    service="$(app_service "${1:-}")"

    shift
    [[ "${1:-}" != "--" ]] || shift

    (( $# )) || die "Usage: app run <service> -- <command...>"

    if ! app_reachable; then app_forward run "${service}" "$@"; return $?; fi

    ensure kubectl envsubst

    image="$(app_image "${service}")"

    [[ -n "${image}" ]] || die "No live release of '${service}' in '${K8S_NAMESPACE}' — is it deployed?"

    name="${service}-run-$(date +%s)"
    file="$(tmp_file)"

    app_manifest "${file}" "${name}" "${service}" "${image}" "$@"

    step "Running on ${service} ${image##*:} — $*"

    kubectl apply -f "${file}" >/dev/null || die "Cannot create job ${name}"

    phase="$(app_phase "${name}")"

    while [[ -z "${phase}" || "${phase}" == "Pending" ]]; do

        if (( waited >= RUN_START )); then

            kubectl -n "${K8S_NAMESPACE}" describe pod -l "job-name=${name}" | tail -n "${POD_LOG_LINES}"
            die "Job ${name} never started within ${RUN_START}s — the events above carry the reason"

        fi

        sleep "${RUN_POLL}"
        waited=$(( waited + RUN_POLL ))
        phase="$(app_phase "${name}")"

    done

    kubectl -n "${K8S_NAMESPACE}" logs -f "job/${name}" 2>/dev/null || true

    until app_settled "$(app_outcome "${name}")"; do sleep "${RUN_POLL}"; done

    app_verdict "$(app_outcome "${name}")" || die "Job ${name} failed — kubectl -n ${K8S_NAMESPACE} describe job/${name}"

    succ "Job ${name} succeeded."

}
## list the one-off runs still on the cluster — of one service, or all
app_runs () {

    local selector="app.kubernetes.io/component=run"

    if ! app_reachable; then app_forward runs "$@"; return $?; fi

    ensure kubectl

    [[ -z "${1:-}" ]] || selector+=",app.kubernetes.io/name=$(app_service "${1}")"

    kubectl -n "${K8S_NAMESPACE}" get jobs -l "${selector}" --no-headers

}
