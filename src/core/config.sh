#!/usr/bin/env bash

## configuration — one resolution, every source in its rank

infrax_code () {

    sed '/^#__INFRAX_PAYLOAD__$/,$d' "${INFRAX_BIN}"

}
infrax_keys () {

    { infrax_defaults; infrax_manifest; } | sed -nE 's/^([A-Z][A-Z0-9_]*)=.*/\1/p' | sort -u

}
infrax_local_keys () {

    infrax_defaults | sed -n 's/^LOCAL_KEYS=//p'

}
env_pairs () {

    local line="" key=""

    while IFS= read -r line || [[ -n "${line}" ]]; do

        [[ -n "${line}" && "${line}" != \#* && "${line}" == *=* ]] || continue

        key="${line%%=*}"
        [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        printf '%s\n' "${line}"

    done

}
env_apply () {

    local keep="${1:-}" line="" key="" value="" pairs=() i=0

    mapfile -t pairs

    for (( i = ${#pairs[@]} - 1; i >= 0; i-- )); do

        line="${pairs[i]}"
        key="${line%%=*}"
        value="${line#*=}"

        [[ -n "${value}" || -n "${keep}" ]] || continue
        [[ -z "${!key:-}" && " ${INFRAX_FLAGS:-} " != *" ${key} "* ]] || continue

        export "${key}=${value}" INFRAX_LOADED="${INFRAX_LOADED:-} ${key}"

    done

}
env_load () {

    local file="${1:-}"

    [[ -f "${file}" ]] || die "Config file not found: ${file}"

    env_apply < <(env_pairs < "${file}")

}
env_files_load () {

    local configs=() i=0

    [[ -n "${INFRAX_CONFIG:-}" ]] || return 0

    mapfile -t configs <<< "${INFRAX_CONFIG}"

    for (( i = ${#configs[@]} - 1; i >= 0; i-- )); do

        [[ -z "${configs[i]}" ]] || env_load "${configs[i]}"

    done

}
env_admits () {

    local key="${1:?env_admits needs a key}" manifest="${2:-}"

    [[ "${manifest}" == *" ${key} "* || "${key}" =~ ^SERVICE_[A-Z0-9_]+$ ]]

}
env_json_load () {

    [[ -n "${JSON_ENV:-}" ]] || return 0

    ensure jq

    local pair="" key="" value="" manifest="" local_keys=""

    manifest=" $(infrax_keys | paste -sd ' ' -) "
    local_keys=" $(infrax_local_keys) "

    while IFS= read -r pair; do

        key="${pair%%=*}"

        env_admits "${key}" "${manifest}" || continue
        [[ "${local_keys}" != *" ${key} "* && -z "${!key:-}" ]] || continue

        value="$(base64 -d <<< "${pair#*=}")"
        [[ -n "${value}" ]] || continue

        export "${key}=${value}" INFRAX_MANIFEST="${INFRAX_MANIFEST:-} ${key}"

    done < <(jq -r 'to_entries[] | "\(.key)=\(.value|@base64)"' <<< "${JSON_ENV}")

    unset JSON_ENV

}
manifest_files () {

    local base="${REPO_ROOT}/infrax.env" stack="${STACK:-}"

    [[ -n "${stack}" || ! -f "${base}" ]] || stack="$(sed -n 's/^STACK=//p' "${base}" | tail -n 1)"
    [[ -n "${stack}" ]] || stack="$(infrax_defaults | sed -n 's/^STACK=//p')"

    printf '%s\n' "${REPO_ROOT}/infrax.${stack}.env" "${base}"

}
manifest_load () {

    local file=""

    while IFS= read -r file; do

        [[ ! -f "${file}" ]] || env_apply < <(env_pairs < "${file}")

    done < <(manifest_files)

}
config_preset () {

    case "${STACK}" in

        full  ) printf '%s\n' 'cluster=managed' 'provisioner=full'  'data=managed' 'identity=true'  'storage=object' 'edge=lb' 'registry=' 'rollout=surge' ;;
        light ) printf '%s\n' 'cluster=ssh'     'provisioner=light' 'data=cluster' 'identity=true'  'storage=object' 'edge='   'registry=' 'rollout=swap' ;;
        *     ) printf '%s\n' 'cluster=ssh'     'provisioner='      'data=cluster' 'identity=false' 'storage=volume' 'edge='   "registry=${GHCR_REGISTRY}" 'rollout=surge' ;;

    esac

}
config_derive () {

    local cluster="" provisioner="" data="" identity="" storage="" edge="" registry="" rollout="" surge=1 unavailable=0 addons="" \
          class="${LOCAL_STORAGE_CLASS}" managed=false section=http pull=false ceiling="${REPLICAS_MAX_SSH}" repo="" owner="" line="" key="" derived="" \
          keys="CLUSTER_SOURCE PROVISIONER DATA_MODE CLOUD_IDENTITY STORAGE_MODE EDGE_TYPE GIT_REPO REGISTRY REGISTRY_USER CLUSTER_NAME K8S_NAMESPACE BUCKET_SUFFIX TF_STATE_BUCKET BACKUP_BUCKET BACKUP_TARGET GATEWAY_SECTION VOLUME_CLASS REPLICAS_MAX ROLLOUT_SURGE ROLLOUT_UNAVAILABLE AUTOSCALER_ENABLED METRICS_SERVER_ENABLED CLOUD_METRICS REGISTRY_PULL KUBECONFIG SERVER_PATH"

    for key in ${keys}; do

        [[ -n "${!key:-}" ]] || derived+="${derived:+ }${key}"

    done

    while IFS= read -r line; do

        declare "${line}"

    done < <(config_preset)

    export CLUSTER_SOURCE="${CLUSTER_SOURCE:-${cluster}}"
    export PROVISIONER="${PROVISIONER:-${provisioner}}"
    export DATA_MODE="${DATA_MODE:-${data}}"
    export CLOUD_IDENTITY="${CLOUD_IDENTITY:-${identity}}"
    export STORAGE_MODE="${STORAGE_MODE:-${storage}}"
    export EDGE_TYPE="${EDGE_TYPE:-${edge}}"

    if [[ "${CLUSTER_SOURCE}" == "managed" ]]; then

        managed=true
        ceiling="${REPLICAS_MAX_MANAGED}"
        class="$(cloud volume_class)"
        addons=" $(cloud managed_addons) "

    fi

    [[ "${GATEWAY_TLS}" != "true" ]] || section=https
    [[ "${rollout}" != "swap" ]] || { surge=0; unavailable=1; }

    repo="${GIT_REPO:-$(printf '%s' "${GIT_REPO_URL%.git}" | sed -E 's#^.*[:/]([^/]+/[^/]+)$#\1#')}"
    owner="${repo%%/*}"

    export GIT_REPO="${repo}"
    export REGISTRY="${REGISTRY:-${registry}}"
    export REGISTRY_USER="${REGISTRY_USER:-${REGISTRY:+${owner}}}"

    [[ -z "${REGISTRY_USER}" ]] || pull=true
    [[ -n "${REGISTRY}" || "${CLOUD_IDENTITY}" != "true" || "${managed}" == "true" ]] || pull=true

    export CLUSTER_NAME="${CLUSTER_NAME:-${PROJECT}}"
    export K8S_NAMESPACE="${K8S_NAMESPACE:-${PROJECT}}"
    export BUCKET_SUFFIX="${BUCKET_SUFFIX:-$(model_suffix)}"
    export TF_STATE_BUCKET="${TF_STATE_BUCKET:-${PROJECT}-state-${BUCKET_SUFFIX}}"
    export BACKUP_BUCKET="${BACKUP_BUCKET:-${PROJECT}-backups-${BUCKET_SUFFIX}}"
    export BACKUP_TARGET="${BACKUP_TARGET:-${STORAGE_MODE}}"
    export GATEWAY_SECTION="${GATEWAY_SECTION:-${section}}"
    export VOLUME_CLASS="${VOLUME_CLASS:-${class}}"
    export REPLICAS_MAX="${REPLICAS_MAX:-${ceiling}}"
    export ROLLOUT_SURGE="${ROLLOUT_SURGE:-${surge}}"
    export ROLLOUT_UNAVAILABLE="${ROLLOUT_UNAVAILABLE:-${unavailable}}"
    export AUTOSCALER_ENABLED="${AUTOSCALER_ENABLED:-$( [[ "${addons}" == *" autoscaler "* ]] && printf true || printf false )}"
    export METRICS_SERVER_ENABLED="${METRICS_SERVER_ENABLED:-$( [[ "${addons}" == *" metrics-server "* ]] && printf true || printf false )}"
    export CLOUD_METRICS="${CLOUD_METRICS:-$( [[ "${DATA_MODE}" == "managed" ]] && printf true || printf false )}"
    export REGISTRY_PULL="${REGISTRY_PULL:-${pull}}"
    export KUBECONFIG="${KUBECONFIG:-$(path_expand "${KUBE_DIR}")/${PROJECT:-${INFRAX_NAME}}.yaml}"
    export SERVER_PATH="${SERVER_PATH:-${SERVER_ROOT}/${PROJECT}/${INFRAX_NAME}}"
    export INFRAX_DERIVED="${derived}"

}
config_override_keys () {

    local name=""

    compgen -v SERVICE_ || true

    for name in $(model_names runtime) $(model_names module); do

        compgen -v "$(model_key "${name}")_" || true

    done

}
config_render () {

    local dst="${1:?config_render needs a destination}" key="" value="" skip=""

    umask 077

    skip=" ${LOCAL_KEYS} ${SERVER_SKIP_KEYS} "

    : > "${dst}" || die "Cannot write: ${dst}"
    chmod 600 "${dst}"

    while IFS= read -r key; do

        [[ "${skip}" != *" ${key} "* ]] || continue

        value="${!key:-}"

        [[ -n "${value}" ]] || continue
        [[ "${value}" != *$'\n'* ]] || { warn "${key} spans lines — it cannot ride a flat env file, left behind"; continue; }

        printf '%s=%s\n' "${key}" "${value}" >> "${dst}"

    done < <({ infrax_keys; config_override_keys; } | sort -u)

}
config_reset () {

    local key=""

    for key in ${INFRAX_DERIVED:-} ${INFRAX_LOADED:-}; do

        [[ " ${INFRAX_FLAGS:-} ${INFRAX_MANIFEST:-} " == *" ${key} "* ]] || unset "${key}"

    done

    INFRAX_LOADED=""

}
config_ssh_key () {

    local raw="${SSH_PRIVATE_KEY:-}"

    [[ -n "${raw}" ]] || return 0
    [[ -z "${SSH_KEY:-}" || ! -f "${SSH_KEY}" ]] || return 0

    umask 077

    SSH_KEY="$(mktemp)"

    if [[ "${raw}" == -----BEGIN* ]]; then printf '%s\n' "${raw}" > "${SSH_KEY}"; else base64 -d <<< "${raw}" > "${SSH_KEY}" || die "SSH_PRIVATE_KEY is neither a key nor base64"; fi

    export SSH_KEY

}
config_roots () {

    REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)}"
    BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/.${INFRAX_NAME}}"
    TEMPLATE_DIR="${TEMPLATE_DIR:-$(template_dir)}"

    export REPO_ROOT BUILD_DIR TEMPLATE_DIR

}
cloud () {

    local fn="${CLOUD:?Missing CLOUD — the provider this platform provisions on}_${1:?cloud needs a verb}"

    shift

    declare -F "${fn}" >/dev/null || die "Cloud '${CLOUD}' does not implement '${fn}' — teach module/${CLOUD}.sh"

    "${fn}" "$@"

}
config_load () {

    config_roots
    config_reset

    env_json_load
    env_files_load
    manifest_load
    env_apply keep < <(infrax_defaults | env_pairs)

    config_ssh_key

    export STACK="${STACK:?Missing STACK — the environment this run acts on}"
    export STACKS="${STACKS:?Missing STACKS — the stack names this platform recognises}"
    export CLOUD="${CLOUD:?Missing CLOUD — the provider this platform provisions on}"
    export DEPLOY_PATH="${DEPLOY_PATH:?Missing DEPLOY_PATH — the gitops path inside the repo, ArgoCD reads it}"

    [[ " ${STACKS} " == *" ${STACK} "* ]] || die "Unknown stack '${STACK}' — STACKS declares: ${STACKS}"
    [[ " ${CLOUDS} " == *" ${CLOUD} "* ]] || die "Unknown cloud '${CLOUD}' — CLOUDS declares: ${CLOUDS}"

    [[ -n "${AWS_PROFILE:-}" ]] || unset AWS_PROFILE
    [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] || unset AWS_PROFILE

    template_ensure
    config_derive

}
config_light () {

    config_roots

    env_json_load
    env_files_load
    env_apply keep < <(infrax_defaults | env_pairs)

}
