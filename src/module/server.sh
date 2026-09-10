#!/usr/bin/env bash

## any linux over ssh — the standard road: credentials in, platform out

server_host () {

    if [[ -z "${SSH_HOST}" ]]; then

        SSH_HOST="$(tofu_output server_ip 2>/dev/null)" || true
        export SSH_HOST

    fi

    [[ -n "${SSH_HOST}" ]] || die "Missing SSH_HOST — set it in your config or apply a stack that builds a server"

    printf '%s' "${SSH_HOST}"

}
server_path () {

    local path="${SERVER_PATH}" root="" ok=0

    for root in ${SERVER_ALLOWED_ROOTS}; do

        [[ "${path}" != "${root}"/*/* ]] || ok=1

    done

    (( ok )) || die "Refusing SERVER_PATH '${path}' — use a dedicated directory two levels under one of: ${SERVER_ALLOWED_ROOTS}"

    printf '%s' "${path}"

}
server_session () {

    local tool="${1:?Missing tool}" flag="${2:?Missing port flag}" password="" options=()

    shift 2

    password="$(secret_get SSH_PASSWORD)"

    if [[ -n "${SSH_HOST_KEY}" ]]; then

        ensure_dir "${BUILD_DIR}"
        printf '%s\n' "${SSH_HOST_KEY}" > "${BUILD_DIR}/known_hosts"

        options=( -o StrictHostKeyChecking=yes -o UserKnownHostsFile="${BUILD_DIR}/known_hosts" "${flag}" "${SSH_PORT}" )

    else

        options=( -o StrictHostKeyChecking=accept-new "${flag}" "${SSH_PORT}" )

    fi

    options+=( -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" -o ServerAliveInterval="${SSH_ALIVE_INTERVAL}" -o ServerAliveCountMax="${SSH_ALIVE_COUNT}" )
    [[ -z "${SSH_KEY}" ]] || options+=( -i "${SSH_KEY}" )

    if [[ -n "${password}" ]]; then

        ensure sshpass

        SSHPASS="${password}" sshpass -e "${tool}" "${options[@]}" "$@"

    else

        "${tool}" "${options[@]}" "$@"

    fi

}
## block until the server accepts ssh — a freshly built box needs a minute to boot
server_wait () {

    local waited=0 host=""

    host="$(server_host)"

    while (( waited < SERVER_WAIT )); do

        server_run true >/dev/null 2>&1 && return 0
        sleep "${SERVER_POLL}"
        waited=$(( waited + SERVER_POLL ))

    done

    die "Server ${host} never accepted ssh within ${SERVER_WAIT}s"

}
## true when the platform already runs on the server — the converge check
server_ready () {

    server_run "sudo k3s kubectl get namespace '${ARGOCD_NAMESPACE}' >/dev/null 2>&1" 2>/dev/null

}
server_remote () {

    printf "cd '%s' && ./%s --config .env -s %s -y%s" "$(server_path)" "${INFRAX_NAME}" "${STACK}" "$(server_overrides)"

}
## push the current config and re-apply every secret — pods restart only when their own changed
server_refresh () {

    local remote=""

    remote="$(server_remote)"

    server_wait
    server_push
    server_run "${remote} k8s secrets && ${remote} argocd bootstrap && ${remote} k8s verify"

    succ "Server config refreshed — secrets reconciled, the app-of-apps re-applied, this release rolled out."

}
## converge the server: bootstrap it when the platform is not there yet, otherwise refresh its config
server_ensure () {

    if server_ready; then

        server_refresh
        return 0

    fi

    server_deploy

}
## run a command on the server over ssh
server_run () {

    server_session ssh -p "${SSH_USER}@$(server_host)" "$@"

}
## copy a local file onto the server
server_copy () {

    local source="${1:?Usage: server copy <source> <destination>}" destination="${2:?Missing destination}"

    server_session scp -P -r "${source}" "${SSH_USER}@$(server_host):${destination}"

}
server_installer () {

    local pin="INSTALL_K3S_VERSION=${K3S_VERSION}"

    [[ -n "${K3S_VERSION}" ]] || pin="INSTALL_K3S_CHANNEL=v${K8S_VERSION:?Missing K8S_VERSION — the channel the installer pins to}"

    printf 'printf "fs.inotify.max_user_instances = %s\\nfs.inotify.max_user_watches = %s\\n" | sudo tee %s >/dev/null && sudo sysctl -q --system; command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y curl; } || { sudo apt-get update -qq && sudo apt-get install -y curl; }; curl -sfL %s | %q sh -s - %s%s' \
        "${INOTIFY_INSTANCES}" "${INOTIFY_WATCHES}" "${INOTIFY_CONF}" "${K3S_INSTALL_URL}" "${pin}" "${K3S_INSTALL_ARGS}" "${1:+ --tls-san $1}"

}
## install k3s on the server (confirmed)
server_setup () {

    local host=""

    host="$(server_host)"

    confirm "Install k3s on '${SSH_USER}@${host}'?"

    server_run "$(server_installer "${host}")"

    succ "k3s ready on ${host}."

}
## sync this bundle, the resolved config and the stack values to the server — the box reads the image tag from the same files CI bumped
server_push () {

    local config="" path="" values="" file=""

    path="$(server_path)"
    config="$(tmp_file)"
    values="${DEPLOY_PATH}/helm/values"

    [[ -f "$(helm_values "${SERVICES%% *}")" ]] || die "Missing stack values under ${values} — a release seeds them"

    config_render "${config}"

    server_run "rm -rf '${path:?}' 2>/dev/null || sudo rm -rf '${path:?}'; mkdir -p '${path}' 2>/dev/null || { sudo mkdir -p '${path}' && sudo chown -R \$(id -un): '${path}'; }; mkdir -p '${path}/${values}'"

    server_copy "${INFRAX_BIN}" "${path}/${INFRAX_NAME}"
    server_copy "${config}" "${path}/.env"

    for file in "$(helm_values_dir)"/*."${STACK}".yaml; do

        server_copy "${file}" "${path}/${values}/${file##*/}"

    done

    server_run "chmod 700 '${path}/${INFRAX_NAME}' && chmod 600 '${path}/.env'"

    rm -f "${config}"

    succ "Bundle + config synced to ${path}."

}
server_overrides () {

    local key="" out="" keys=()

    read -ra keys <<< "${INFRAX_FLAGS:-}"

    for key in "${keys[@]}"; do

        secret_name "${key}" || out+=" -e ${key}='${!key}'"

    done

    printf '%s' "${out}"

}
## the ONE verb: push everything and bootstrap the whole platform remotely
server_deploy () {

    local host="" remote=""

    host="$(server_host)"
    remote="$(server_remote)"

    confirm "Deploy the '${STACK}' stack on '${SSH_USER}@${host}'?"

    server_wait
    server_push

    server_run "${remote} -e SSH_HOST='${host}' server bootstrap"

    succ "Stack '${STACK}' live on ${host} — grab access with: ${INFRAX_NAME} k8s kubeconfig"

}
server_node () {

    local left="${NODE_REGISTER_TRIES}"

    while (( left-- )); do

        [[ -z "$(kubectl get nodes -o name 2>/dev/null)" ]] || return 0

        sleep "${NODE_REGISTER_POLL}"

    done

    die "k3s never registered a node — inspect: journalctl -u k3s"

}
## run the on-box side: k3s, secrets, gitops handover, verify
server_bootstrap () {

    ensure curl

    bash -c "$(server_installer "${SSH_HOST}")"

    ensure_dir "$(dirname "${KUBECONFIG}")"

    as_root cat ${K3S_KUBECONFIG} > "${KUBECONFIG}"
    chmod 600 "${KUBECONFIG}"

    server_node

    run kubectl wait --for=condition=Ready node --all --timeout="${NODE_READY_TIMEOUT}"

    k8s_bootstrap
    k8s_verify

}
## fetch the k3s kubeconfig over the wire
server_kubeconfig () {

    local host=""

    host="$(server_host)"

    ensure_dir "$(dirname "${KUBECONFIG}")"

    server_run "sudo cat ${K3S_KUBECONFIG}" \
        | sed "s|https://127.0.0.1:${K3S_API_PORT}|https://${host}:${K3S_API_PORT}|" > "${KUBECONFIG}"

    chmod 600 "${KUBECONFIG}"

    succ "Kubeconfig written: ${KUBECONFIG}"

}
## quick node + pod glance over ssh
server_status () {

    server_run "systemctl is-active k3s && sudo k3s kubectl get nodes"

}
