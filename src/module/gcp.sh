#!/usr/bin/env bash

## the gcp provider — every gcp byte lives here, dispatched through `cloud <verb>`

GCP_KEY_FILE=""

gcp_release_key () {

    [[ -z "${GCP_KEY_FILE}" ]] || rm -f "${GCP_KEY_FILE}"

}
gcp_auth () {

    local raw="${GCP_CREDENTIALS:-}"

    ensure gcloud

    [[ -n "${raw}" && -z "${GCP_KEY_FILE}" ]] || return 0

    umask 077

    GCP_KEY_FILE="$(mktemp)"

    if [[ "${raw}" == \{* ]]; then printf '%s' "${raw}" > "${GCP_KEY_FILE}"; else base64 -d <<< "${raw}" > "${GCP_KEY_FILE}" || die "GCP_CREDENTIALS is neither json nor base64"; fi

    trap gcp_release_key EXIT

    export GOOGLE_APPLICATION_CREDENTIALS="${GCP_KEY_FILE}" CLOUDSDK_CORE_PROJECT="${GCP_PROJECT}"

    gcloud auth activate-service-account --key-file="${GCP_KEY_FILE}" --quiet >/dev/null 2>&1 || die "GCP_CREDENTIALS does not authenticate"

}
## show the active account, project and region
gcp_whoami () {

    gcp_auth

    run gcloud auth list --filter=status:ACTIVE --format='value(account)'
    info "Project: ${GCP_PROJECT} · Region: ${GCP_REGION}"

}
gcp_region () {

    printf '%s' "${GCP_REGION}"

}
gcp_required_secrets () {

    printf '%s' "GCP_PROJECT GCP_REGION GCP_CREDENTIALS"

}
gcp_managed_addons () {

    printf ''

}
gcp_volume_class () {

    printf 'standard-rwo'

}
gcp_account_id () {

    local id=""

    id="$(printf '%s-%s' "${PROJECT}" "${1:?gcp_account_id needs a name}" | cut -c1-30)"

    printf '%s' "${id%-}"

}
## create a hardened gcs bucket: uniform access, public prevention, versioning, optional lifecycle
gcp_bucket () {

    local name="${1:?Missing bucket name}" expire="${2:-}" file=""

    gcp_auth

    if gcloud storage buckets describe "gs://${name}" >/dev/null 2>&1; then

        info "Bucket exists: ${name}"

    else

        step "Creating bucket: ${name}"

        gcloud storage buckets create "gs://${name}" --location="${GCP_REGION}" --uniform-bucket-level-access \
            --public-access-prevention --quiet >/dev/null || die "Cannot create bucket: ${name}"

    fi

    gcloud storage buckets update "gs://${name}" --versioning --quiet >/dev/null

    if [[ -n "${expire}" ]]; then

        file="$(tmp_file)"

        printf '{"rule":[{"action":{"type":"Delete"},"condition":{"age":%s}},{"action":{"type":"Delete"},"condition":{"daysSinceNoncurrentTime":%s}}]}' "${expire}" "${expire}" > "${file}"

        gcloud storage buckets update "gs://${name}" --lifecycle-file="${file}" --quiet >/dev/null

        rm -f "${file}"

    fi

    succ "Bucket ready: ${name}"

}
gcp_tofu_prereqs () {

    gcp_bucket "${TF_STATE_BUCKET}"
    gcp_bucket "${BACKUP_BUCKET}" "${BACKUP_KEEP_DAYS}"
    gcp_stale_lock

}
gcp_backend_flags () {

    printf '%s\n' \
        "-backend-config=bucket=${TF_STATE_BUCKET}" \
        "-backend-config=prefix=${PROJECT}/${STACK}"

}
gcp_stale_lock () {

    local lock="gs://${TF_STATE_BUCKET}/${PROJECT}/${STACK}/default.tflock" born="" age=0

    born="$(gcloud storage objects describe "${lock}" --format='value(creation_time)' 2>/dev/null)" || true

    [[ -n "${born}" ]] || return 0

    age=$(( $(date +%s) - $(date -d "${born}" +%s) ))

    (( age > TOFU_LOCK_STALE )) || die "The '${STACK}' state is locked by a run ${age}s old — let it finish, or free it: ${INFRAX_NAME} tofu unlock"

    warn "Dropping a ${age}s-old state lock — no run lives that long"

    gcp_unlock

}
gcp_unlock () {

    gcp_auth

    run gcloud storage rm "gs://${TF_STATE_BUCKET}/${PROJECT}/${STACK}/default.tflock" --quiet

}
gcp_db_unguard () {

    local module="${1:?gcp_db_unguard needs a module}" instance="${PROJECT}-${1}"

    gcp_auth

    gcloud sql instances describe "${instance}" >/dev/null 2>&1 || return 0

    step "Lowering the deletion guard of ${module} — this destroy names it on purpose"

    run gcloud sql instances patch "${instance}" --no-deletion-protection --quiet >/dev/null \
        || die "Cannot lower deletion protection on '${instance}' — the destroy would die against it"

}
gcp_registry () {

    printf '%s-docker.pkg.dev/%s' "${GCP_REGION:?Missing GCP_REGION}" "${GCP_PROJECT:?Missing GCP_PROJECT}"

}
gcp_registry_login () {

    gcp_auth
    ensure docker

    gcloud auth print-access-token | docker login --username oauth2accesstoken --password-stdin "https://${1:?Missing registry}" \
        || die "Artifact Registry login failed"

}
gcp_registry_criticals () {

    local image=""

    image="$(ci_image "${1:?Missing service}"):${2:?Missing image tag}"

    ci_trivy "${image}"

}
gcp_registry_refresher () {

    local registry=""

    ensure kubectl

    registry="$(ci_registry)"

    REGISTRY_HOST="${registry%%/*}"
    export REGISTRY_HOST

    render "${TEMPLATE_DIR}/gcp/registry-refresher.yaml" "${BUILD_DIR}/k8s/registry-refresher.yaml"

    run kubectl apply -f "${BUILD_DIR}/k8s/registry-refresher.yaml"

    succ "Artifact Registry pull-secret refresher scheduled — the node identity mints the token."

}
gcp_registry_user () {

    printf 'oauth2accesstoken'

}
gcp_registry_token () {

    gcp_auth

    gcloud auth print-access-token

}
gcp_edge_annotations () {

    [[ -n "${EDGE_TYPE}" && -n "${EDGE_EIPS}" ]] || { printf '{}'; return 0; }

    printf '{"networking.gke.io/load-balancer-ip-addresses":"%s"}' "${EDGE_EIPS}"

}
gcp_storage_facts () {

    printf '%s\n' "REGION=${GCP_REGION}" "ENDPOINT=${STORAGE_ENDPOINT:-https://storage.googleapis.com}" "SCHEME=gs"

}
gcp_database_address () {

    local module="${1:?gcp_database_address needs a module}" address=""

    address="$(module_get "${module}" ADDRESS)"

    [[ -n "${address}" ]] || address="$(tofu_output_json database_addresses 2>/dev/null | jq -r --arg module "${module}" '.[$module] // empty')" || true

    [[ -n "${address}" ]] || die "The managed ${module} has no address yet — apply the stack first"

    printf '%s' "${address}"

}
gcp_account_annotations () {

    local name="${1:?gcp_account_annotations needs a name}" storage=""

    [[ "${CLUSTER_SOURCE}" == "managed" ]] || { printf '{}'; return 0; }

    if [[ "${name}" != *-backup ]]; then

        storage="$(service_storage "${name}")"

        [[ -n "${storage}" ]] || { printf '{}'; return 0; }

    fi

    printf '{"iam.gke.io/gcp-service-account": "%s@%s.iam.gserviceaccount.com"}' "$(gcp_account_id "${name}")" "${GCP_PROJECT}"

}
gcp_backup_uploader () {

    printf '%s\n' \
        "IMAGE=${GCLOUD_IMAGE}" \
        'COMMAND=["sh", "-c", "gcloud storage cp -r --no-user-output-enabled \"$WORK\"/* \"gs://$BUCKET/$PREFIX/\""]' \
        "ENV={\"BUCKET\": \"${BACKUP_BUCKET}\", \"CLOUDSDK_CONFIG\": \"/tmp/gcloud\"}"

}
gcp_backup_fetcher () {

    local object="${1:?Missing object}" file="${2:?Missing file}"

    printf '%s\n' \
        "IMAGE=${GCLOUD_IMAGE}" \
        'COMMAND=["sh", "-c", "mkdir -p \"$(dirname \"$FILE\")\" && gcloud storage cp --no-user-output-enabled \"gs://$BUCKET/$OBJECT\" \"$FILE\""]' \
        "ENV=[{\"name\": \"BUCKET\", \"value\": \"${BACKUP_BUCKET}\"}, {\"name\": \"OBJECT\", \"value\": \"${object}\"}, {\"name\": \"FILE\", \"value\": \"${file}\"}, {\"name\": \"CLOUDSDK_CONFIG\", \"value\": \"/tmp/gcloud\"}, {\"name\": \"HOME\", \"value\": \"/tmp\"}]"

}
gcp_backup_list () {

    gcp_auth

    run gcloud storage ls -l -r "gs://${BACKUP_BUCKET}/${1:?Missing prefix}"

}
gcp_backup_pull () {

    gcp_auth

    run gcloud storage cp "gs://${BACKUP_BUCKET}/${1:?Missing object}" "${2:?Missing destination}"

}
gcp_metrics_file () {

    printf ''

}
gcp_kubeconfig () {

    gcp_auth
    ensure kubectl

    ensure_dir "$(dirname "${KUBECONFIG}")"

    KUBECONFIG="${KUBECONFIG}" run gcloud container clusters get-credentials "${CLUSTER_NAME}" --region "${GCP_REGION}" --project "${GCP_PROJECT}"

}
gcp_hcl_buckets () {

    local service="" storage="" out=""

    for service in ${SERVICES:-}; do

        storage="$(service_storage "${service}")"

        [[ -n "${storage}" ]] || continue
        [[ "$(module_mode "${storage}")" == "object" ]] || continue

        out+="\"$(service_bucket "${service}")\" = { service = \"${service}\", account = \"$(gcp_account_id "${service}")\", public = $( [[ "$(service_get "${service}" PUBLIC)" == "true" ]] && printf true || printf false ) }, "

    done

    printf '{ %s}' "${out}"

}
gcp_hcl_databases () {

    local module="" version="" out=""

    for module in $(tofu_managed); do

        version="$(module_get "${module}" ENGINE_VERSION)"
        version="${version%.*}"

        [[ "$(module_get "${module}" ENGINE)" != "postgres" ]] || version="${version%%.*}"

        out+="${module} = { version = \"$(module_get "${module}" ENGINE | tr '[:lower:]' '[:upper:]')_${version//./_}\", user = \"$(module_get "${module}" ROOT_USER)\" }, "

    done

    printf '{ %s}' "${out}"

}
gcp_hcl_backups () {

    local module="" out=""

    for module in $(model_modules database); do

        [[ -z "$(module_users "${module}")" ]] || out+="\"${module}-backup\" = \"$(gcp_account_id "${module}-backup")\", "

    done

    printf '{ %s}' "${out}"

}
gcp_tofu_vars () {

    printf 'name          = "%s"\n' "${PROJECT}"
    printf 'project       = "%s"\n' "${GCP_PROJECT}"
    printf 'region        = "%s"\n' "${GCP_REGION}"
    printf 'zone          = "%s"\n' "${GCP_ZONE:-${GCP_REGION}-a}"
    printf 'vpc_cidr      = "%s"\n' "${VPC_CIDR}"
    printf 'repository    = "%s"\n' "${PROJECT}"
    printf 'keep_images   = %s\n'   "${REGISTRY_KEEP_IMAGES}"
    printf 'buckets       = %s\n'   "$(gcp_hcl_buckets)"
    printf 'backup_bucket = "%s"\n' "${BACKUP_BUCKET}"
    printf 'admin_cidrs   = %s\n'   "$(tofu_hcl_list "${ADMIN_CIDRS}")"

    if [[ "${CLUSTER_SOURCE}" != "managed" ]]; then

        printf 'machine_type   = "%s"\n' "${GCE_TYPE}"
        printf 'disk_gb        = %s\n'   "${GCE_DISK_GB}"
        printf 'image          = "%s"\n' "${GCE_IMAGE}"
        printf 'ssh_user       = "%s"\n' "${SSH_USER}"
        printf 'ssh_public_key = "%s"\n' "${SSH_PUBLIC_KEY}"

        return 0

    fi

    printf 'cluster_name    = "%s"\n' "${CLUSTER_NAME}"
    printf 'node_type       = "%s"\n' "${GKE_NODE_TYPE}"
    printf 'node_disk_gb    = %s\n'   "${NODE_DISK_GB}"
    printf 'node_min        = %s\n'   "${NODE_MIN}"
    printf 'node_max        = %s\n'   "${NODE_MAX}"
    printf 'databases       = %s\n'   "$(gcp_hcl_databases)"
    printf 'db_tier         = "%s"\n' "${CLOUDSQL_TIER}"
    printf 'db_disk_gb      = %s\n'   "${DB_DISK_GB}"
    printf 'db_backup_days  = %s\n'   "${DB_BACKUP_DAYS}"
    printf 'db_multi_az     = %s\n'   "${DB_MULTI_AZ}"
    printf 'k8s_namespace   = "%s"\n' "${K8S_NAMESPACE}"
    printf 'backup_accounts = %s\n'   "$(gcp_hcl_backups)"

}
