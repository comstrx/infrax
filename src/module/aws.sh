#!/usr/bin/env bash

## the aws provider — every aws byte lives here, dispatched through `cloud <verb>`

aws_auth () {

    ensure aws

}
## show the caller identity and region
aws_whoami () {

    ensure aws

    run aws sts get-caller-identity --output table
    info "Region: ${AWS_REGION}"

}
aws_region () {

    printf '%s' "${AWS_REGION}"

}
aws_required_secrets () {

    printf '%s' "AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"

}
aws_managed_addons () {

    printf '%s' "autoscaler metrics-server"

}
aws_volume_class () {

    printf 'gp2'

}
## create a hardened s3 bucket: versioning, encryption, public block, optional lifecycle
aws_bucket () {

    local name="${1:?Missing bucket name}" region="${2:-${AWS_REGION}}" expire="${3:-}"

    ensure aws

    if aws s3api head-bucket --bucket "${name}" 2>/dev/null; then

        info "Bucket exists: ${name}"

    else

        step "Creating bucket: ${name}"

        if [[ "${region}" == "us-east-1" ]]; then

            aws s3api create-bucket --bucket "${name}" --region "${region}" >/dev/null \
                || die "Cannot create bucket: ${name}"

        else

            aws s3api create-bucket --bucket "${name}" --region "${region}" \
                --create-bucket-configuration "LocationConstraint=${region}" >/dev/null \
                || die "Cannot create bucket: ${name}"

        fi

    fi

    aws s3api put-bucket-versioning --bucket "${name}" \
        --versioning-configuration Status=Enabled

    aws s3api put-bucket-encryption --bucket "${name}" \
        --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

    aws s3api put-public-access-block --bucket "${name}" \
        --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    [[ -z "${expire}" ]] || aws s3api put-bucket-lifecycle-configuration --bucket "${name}" \
        --lifecycle-configuration "{\"Rules\":[{\"ID\":\"hygiene\",\"Status\":\"Enabled\",\"Filter\":{},\"Expiration\":{\"Days\":${expire}},\"NoncurrentVersionExpiration\":{\"NoncurrentDays\":${expire}},\"AbortIncompleteMultipartUpload\":{\"DaysAfterInitiation\":7}}]}"

    succ "Bucket ready: ${name}"

}
aws_state_bucket () {

    aws_bucket "${TF_STATE_BUCKET}" "${TF_STATE_REGION:-${AWS_REGION}}"

}
aws_backup_bucket () {

    aws_bucket "${BACKUP_BUCKET}" "${AWS_REGION}" "${BACKUP_KEEP_DAYS}"

}
## drop a state lock no run can hold anymore — a killed run leaves one behind, every later run would wait then die
aws_stale_lock () {

    local key="${PROJECT}/${STACK}.tfstate.tflock" born="" age=0

    ensure aws jq

    born="$(aws s3 cp "s3://${TF_STATE_BUCKET}/${key}" - 2>/dev/null | jq -r '.Created // empty' 2>/dev/null)" || true

    [[ -n "${born}" ]] || return 0

    age=$(( $(date +%s) - $(date -d "${born}" +%s) ))

    (( age > TOFU_LOCK_STALE )) || die "The '${STACK}' state is locked by a run ${age}s old — let it finish, or free it: ${INFRAX_NAME} tofu unlock"

    warn "Dropping a ${age}s-old state lock — no run lives that long"

    aws_unlock

}
aws_unlock () {

    ensure aws

    run aws s3 rm "s3://${TF_STATE_BUCKET}/${PROJECT}/${STACK}.tfstate.tflock"

}
aws_tofu_prereqs () {

    aws_state_bucket
    aws_backup_bucket
    aws_stale_lock

}
aws_backend_flags () {

    printf '%s\n' \
        "-backend-config=bucket=${TF_STATE_BUCKET}" \
        "-backend-config=key=${PROJECT}/${STACK}.tfstate" \
        "-backend-config=region=${TF_STATE_REGION:-${AWS_REGION}}" \
        "-backend-config=encrypt=true" \
        "-backend-config=use_lockfile=true"

}
aws_db_unguard () {

    local module="${1:?aws_db_unguard needs a module}" identifier="${PROJECT}-${1}"

    ensure aws

    aws rds describe-db-instances --db-instance-identifier "${identifier}" >/dev/null 2>&1 || return 0

    step "Lowering the deletion guard of ${module} — this destroy names it on purpose"

    run aws rds modify-db-instance --db-instance-identifier "${identifier}" \
        --no-deletion-protection --apply-immediately >/dev/null \
        || die "Cannot lower deletion protection on '${identifier}' — the destroy would die against it"

}
## the account these credentials act in — asked once, remembered under the build dir
aws_account () {

    local file="${BUILD_DIR}/aws/account" account=""

    if [[ -s "${file}" ]]; then

        cat "${file}"
        return 0

    fi

    ensure aws

    account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" || return 1

    ensure_dir "$(dirname "${file}")"
    printf '%s' "${account}" > "${file}"
    printf '%s' "${account}"

}
aws_registry () {

    local account=""

    if [[ -n "${ECR_REGISTRY}" ]]; then

        printf '%s' "${ECR_REGISTRY}"
        return 0

    fi

    account="$(aws_account)" || return 0

    printf '%s.dkr.ecr.%s.amazonaws.com' "${account}" "${AWS_REGION:?Missing AWS_REGION}"

}
aws_registry_login () {

    ensure aws docker

    aws ecr get-login-password --region "${AWS_REGION}" \
        | docker login --username AWS --password-stdin "${1:?Missing registry}" \
        || die "ECR login failed"

}
aws_registry_criticals () {

    local service="${1:?Missing service}" tag="${2:?Missing image tag}" critical="" repository="${PROJECT}/${1}"

    ensure aws

    aws ecr wait image-scan-complete --repository-name "${repository}" \
        --image-id imageTag="${tag}" --region "${AWS_REGION}" \
        || die "ECR scan never completed for ${service}:${tag}"

    critical="$(aws ecr describe-image-scan-findings --repository-name "${repository}" \
        --image-id imageTag="${tag}" --region "${AWS_REGION}" --no-paginate \
        --query 'imageScanFindings.findingSeverityCounts.CRITICAL' --output text | sed -n '1p')"

    [[ "${critical}" =~ ^[0-9]+$ ]] || critical=0

    printf '%s' "${critical}"

}
aws_registry_refresher () {

    local registry=""

    ensure kubectl

    registry="$(ci_registry)"

    REGISTRY_HOST="${registry%%/*}"
    export REGISTRY_HOST

    render "${TEMPLATE_DIR}/aws/registry-refresher.yaml" "${BUILD_DIR}/k8s/registry-refresher.yaml"

    run kubectl apply -f "${BUILD_DIR}/k8s/registry-refresher.yaml"

    succ "ECR pull-secret refresher scheduled — 6h cadence against the 12h token."

}
aws_registry_user () {

    printf 'AWS'

}
aws_registry_token () {

    ensure aws

    aws ecr get-login-password --region "${AWS_REGION}"

}
aws_edge_annotations () {

    [[ -n "${EDGE_TYPE}" ]] || { printf '{}'; return 0; }

    printf '{"service.beta.kubernetes.io/aws-load-balancer-type":"nlb","service.beta.kubernetes.io/aws-load-balancer-scheme":"internet-facing","service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled":"true"%s}' \
        "${EDGE_EIPS:+,\"service.beta.kubernetes.io/aws-load-balancer-eip-allocations\":\"${EDGE_EIPS}\"}"

}
aws_storage_facts () {

    printf '%s\n' "REGION=${AWS_REGION}" "ENDPOINT=${STORAGE_ENDPOINT}" "SCHEME=s3"

}
aws_database_address () {

    local module="${1:?aws_database_address needs a module}" address=""

    address="$(module_get "${module}" ADDRESS)"

    [[ -n "${address}" ]] || address="$(tofu_output_json database_addresses 2>/dev/null | jq -r --arg module "${module}" '.[$module] // empty')" || true

    [[ -n "${address}" ]] || die "The managed ${module} has no address yet — apply the stack first"

    printf '%s' "${address}"

}
aws_account_annotations () {

    printf '{}'

}
aws_backup_uploader () {

    printf '%s\n' \
        "IMAGE=${AWS_CLI_IMAGE}" \
        'COMMAND=["sh", "-c", "aws s3 cp --recursive --only-show-errors \"$WORK\" \"s3://$BUCKET/$PREFIX/\""]' \
        "ENV={\"BUCKET\": \"${BACKUP_BUCKET}\", \"AWS_DEFAULT_REGION\": \"${AWS_REGION}\"}"

}
aws_backup_fetcher () {

    local object="${1:?Missing object}" file="${2:?Missing file}"

    printf '%s\n' \
        "IMAGE=${AWS_CLI_IMAGE}" \
        'COMMAND=["sh", "-c", "mkdir -p \"$(dirname \"$FILE\")\" && aws s3 cp --only-show-errors \"s3://$BUCKET/$OBJECT\" \"$FILE\""]' \
        "ENV=[{\"name\": \"BUCKET\", \"value\": \"${BACKUP_BUCKET}\"}, {\"name\": \"OBJECT\", \"value\": \"${object}\"}, {\"name\": \"FILE\", \"value\": \"${file}\"}, {\"name\": \"AWS_DEFAULT_REGION\", \"value\": \"${AWS_REGION}\"}, {\"name\": \"HOME\", \"value\": \"/tmp\"}]"

}
aws_backup_list () {

    ensure aws

    run aws s3 ls "s3://${BACKUP_BUCKET}/${1:?Missing prefix}" --recursive --human-readable

}
aws_backup_pull () {

    ensure aws

    run aws s3 cp --only-show-errors "s3://${BACKUP_BUCKET}/${1:?Missing object}" "${2:?Missing destination}"

}
aws_metrics_file () {

    printf '%s' "${TEMPLATE_DIR}/aws/metrics.yaml"

}
aws_kubeconfig () {

    ensure aws kubectl

    ensure_dir "$(dirname "${KUBECONFIG}")"

    run aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --kubeconfig "${KUBECONFIG}"

}
aws_hcl_buckets () {

    local service="" storage="" out=""

    for service in ${SERVICES:-}; do

        storage="$(service_storage "${service}")"

        [[ -n "${storage}" ]] || continue
        [[ "$(module_mode "${storage}")" == "object" ]] || continue

        out+="\"$(service_bucket "${service}")\" = { service = \"${service}\", public = $( [[ "$(service_get "${service}" PUBLIC)" == "true" ]] && printf true || printf false ) }, "

    done

    printf '{ %s}' "${out}"

}
aws_hcl_databases () {

    local module="" out=""

    for module in $(tofu_managed); do

        out+="${module} = { engine = \"$(module_get "${module}" ENGINE)\", version = \"$(module_get "${module}" ENGINE_VERSION)\", port = $(module_get "${module}" PORT), user = \"$(module_get "${module}" ROOT_USER)\" }, "

    done

    printf '{ %s}' "${out}"

}
aws_hcl_backups () {

    local module="" out=""

    for module in $(model_modules database); do

        [[ -z "$(module_users "${module}")" ]] || out+="\"${module}-backup\", "

    done

    printf '[%s]' "${out%, }"

}
aws_hcl_repositories () {

    local service="" out=""

    for service in ${SERVICES:-}; do

        out+="\"${PROJECT}/${service}\", "

    done

    printf '[%s]' "${out%, }"

}
aws_tofu_vars () {

    printf 'name             = "%s"\n' "${PROJECT}"
    printf 'region           = "%s"\n' "${AWS_REGION}"
    printf 'vpc_cidr         = "%s"\n' "${VPC_CIDR}"
    printf 'az_count         = %s\n'   "${AZ_COUNT}"
    printf 'repositories     = %s\n'   "$(aws_hcl_repositories)"
    printf 'keep_images      = %s\n'   "${REGISTRY_KEEP_IMAGES}"
    printf 'buckets          = %s\n'   "$(aws_hcl_buckets)"
    printf 'backup_bucket    = "%s"\n' "${BACKUP_BUCKET}"

    if [[ "${CLUSTER_SOURCE}" != "managed" ]]; then

        printf 'ec2_type       = "%s"\n' "${EC2_TYPE}"
        printf 'ec2_disk_gb    = %s\n'   "${EC2_DISK_GB}"
        printf 'ec2_ubuntu     = "%s"\n' "${EC2_UBUNTU}"
        printf 'admin_cidrs    = %s\n'   "$(tofu_hcl_list "${ADMIN_CIDRS}")"
        printf 'ssh_public_key = "%s"\n' "${SSH_PUBLIC_KEY}"

        return 0

    fi

    printf 'cluster_name       = "%s"\n' "${CLUSTER_NAME}"
    printf 'k8s_version        = "%s"\n' "${K8S_VERSION}"
    printf 'node_type          = "%s"\n' "${EKS_NODE_TYPE}"
    printf 'node_disk_gb       = %s\n'   "${NODE_DISK_GB}"
    printf 'node_min           = %s\n'   "${NODE_MIN}"
    printf 'node_desired       = %s\n'   "${NODE_DESIRED}"
    printf 'node_max           = %s\n'   "${NODE_MAX}"
    printf 'node_max_pods      = %s\n'   "${NODE_MAX_PODS}"
    printf 'databases          = %s\n'   "$(aws_hcl_databases)"
    printf 'db_instance_class  = "%s"\n' "${DB_INSTANCE_CLASS}"
    printf 'db_disk_gb         = %s\n'   "${DB_DISK_GB}"
    printf 'db_max_disk_gb     = %s\n'   "${DB_MAX_DISK_GB}"
    printf 'db_backup_days     = %s\n'   "${DB_BACKUP_DAYS}"
    printf 'db_multi_az        = %s\n'   "${DB_MULTI_AZ}"
    printf 'db_replicas        = %s\n'   "${DB_REPLICAS}"
    printf 'db_apply_now       = %s\n'   "${DB_APPLY_NOW}"
    printf 'db_alarm_cpu       = %s\n'   "${DB_ALARM_CPU}"
    printf 'db_alarm_free_gb   = %s\n'   "${DB_ALARM_FREE_GB}"
    printf 'k8s_namespace      = "%s"\n' "${K8S_NAMESPACE}"
    printf 'backup_accounts    = %s\n'   "$(aws_hcl_backups)"
    printf 'edge_fixed_ips     = %s\n'   "${EDGE_FIXED_IPS}"
    printf 'log_retention_days = %s\n'   "${LOG_RETENTION_DAYS}"
    printf 'alarm_email        = "%s"\n' "${ALARM_EMAIL}"

}
