#!/usr/bin/env bash

## database backups — take, list, pull, restore (never over the live database)

backup_module () {

    local module="${1:-}"

    [[ -n "${module}" && " $(model_modules database | paste -sd ' ' -) " == *" ${module} "* ]] \
        || die "Name one of this project's databases: $(model_modules database | paste -sd ' ' -)"

    printf '%s' "${module}"

}
backup_wait () {

    local name="${1:?Missing job name}" left="${BACKUP_JOB_TRIES}"

    step "Waiting for ${name}"

    while (( left-- )); do

        [[ -z "$(kubectl -n "${K8S_NAMESPACE}" get "job/${name}" -o jsonpath='{.status.conditions[*].type}' 2>/dev/null)" ]] || break

        sleep "${BACKUP_JOB_POLL}"

    done

    kubectl -n "${K8S_NAMESPACE}" logs "job/${name}" --all-containers --tail=-1 2>/dev/null || true

    [[ "$(kubectl -n "${K8S_NAMESPACE}" get "job/${name}" -o jsonpath='{.status.succeeded}')" == "1" ]] \
        || die "Job '${name}' failed — the pod log above says why"

}
## take a backup right now — of one database module, or of every one
backup_now () {

    local module="" modules=() name=""

    ensure kubectl

    if [[ -n "${1:-}" ]]; then modules=( "$(backup_module "${1}")" ); else mapfile -t modules < <(model_modules database); fi

    for module in "${modules[@]}"; do

        name="${module}-backup-manual-$(date -u +%s)"

        run kubectl -n "${K8S_NAMESPACE}" create job "${name}" --from="cronjob/${module}-backup" >/dev/null \
            || die "Cannot schedule '${name}' — is the ${module} backup cronjob deployed?"

        backup_wait "${name}"

    done

    succ "Backup complete — '${INFRAX_NAME} backup list <module>' shows it."

}
## list the stored backups of one database module
backup_list () {

    local module=""

    module="$(backup_module "${1:-}")"

    if [[ "${BACKUP_TARGET}" == "object" ]]; then

        cloud backup_list "${PROJECT}/${module}/"
        return 0

    fi

    ensure kubectl

    kubectl run "${module}-backup-list-$(date -u +%s)" -n "${K8S_NAMESPACE}" --rm --attach --quiet --restart=Never \
        --image="$(module_get "${module}" IMAGE)" \
        --labels="app.kubernetes.io/name=${module}-backup" \
        --overrides="{\"spec\":{\"securityContext\":{\"runAsNonRoot\":true,\"runAsUser\":$(module_get "${module}" USER)},\"volumes\":[{\"name\":\"backups\",\"persistentVolumeClaim\":{\"claimName\":\"${module}-backups\"}}],\"containers\":[{\"name\":\"list\",\"image\":\"$(module_get "${module}" IMAGE)\",\"command\":[\"sh\",\"-c\",\"find /backups -type f | sort\"],\"volumeMounts\":[{\"name\":\"backups\",\"mountPath\":\"/backups\"}]}]}}"

}
## download one stored backup to this machine — <module> <database> <stamp>
backup_pull () {

    local module="" database="${2:?Usage: backup pull <module> <database> <stamp>}" stamp="${3:?Missing stamp}" file=""

    module="$(backup_module "${1:-}")"

    [[ "${BACKUP_TARGET}" == "object" ]] || die "Backups of '${STACK}' live on a cluster volume — '${INFRAX_NAME} backup list ${module}' shows them in place"

    file="${database}/${stamp}.$(module_get "${module}" DUMP)"

    ensure_dir "${BUILD_DIR}/backups/${module}/${database}"

    cloud backup_pull "${PROJECT}/${module}/${file}" "${BUILD_DIR}/backups/${module}/${file}"

    succ "Pulled → ${BUILD_DIR}/backups/${module}/${file}"

}
## restore a stamp into a SIDE database — <module> <database> <stamp> [target]; promote deliberately, never over the live one
backup_restore () {

    local module="" database="${2:?Usage: backup restore <module> <database> <stamp> [target]}" stamp="${3:?Missing stamp}" target="" key="" value="" file=""

    module="$(backup_module "${1:-}")"
    target="${4:-${database}_restore}"

    [[ "${target}" != "${database}" ]] || die "Refusing to restore over '${database}' — promotion is a deliberate act"

    confirm "Restore ${module} '${database}' ${stamp} into the side database '${target}'?"

    file="$(tmp_file)"

    RESTORE_NAME="${module}-restore-$(date -u +%s)"
    RESTORE_MODULE="${module}"
    RESTORE_USER="$(module_get "${module}" USER)"
    RESTORE_IMAGE="$(module_get "${module}" IMAGE)"
    RESTORE_PORT="$(module_get "${module}" PORT)"
    RESTORE_SOURCE="${database}"
    RESTORE_TARGET="${target}"
    RESTORE_STAMP="${stamp}"
    RESTORE_FILE="${database}/${stamp}.$(module_get "${module}" DUMP)"
    RESTORE_FETCH_IMAGE="${RESTORE_IMAGE}"
    RESTORE_FETCH_COMMAND='["true"]'
    RESTORE_FETCH_ENV="[]"
    RESTORE_WORK="persistentVolumeClaim: {claimName: ${module}-backups}"

    if [[ "${BACKUP_TARGET}" == "object" ]]; then

        RESTORE_WORK="emptyDir: {}"

        while IFS='=' read -r key value; do

            case "${key}" in
                IMAGE   ) RESTORE_FETCH_IMAGE="${value}" ;;
                COMMAND ) RESTORE_FETCH_COMMAND="${value}" ;;
                ENV     ) RESTORE_FETCH_ENV="${value}" ;;
            esac

        done < <(cloud backup_fetcher "${PROJECT}/${module}/${RESTORE_FILE}" "/work/${RESTORE_FILE}")

    fi

    export RESTORE_NAME RESTORE_MODULE RESTORE_USER RESTORE_IMAGE RESTORE_PORT RESTORE_SOURCE RESTORE_TARGET RESTORE_STAMP RESTORE_FILE \
        RESTORE_FETCH_IMAGE RESTORE_FETCH_COMMAND RESTORE_FETCH_ENV RESTORE_WORK

    render "${TEMPLATE_DIR}/k8s/restore.yaml" "${file}"

    ensure kubectl

    run kubectl apply -f "${file}" >/dev/null

    rm -f "${file}"

    backup_wait "${RESTORE_NAME}"

    succ "Restored ${module} '${database}' ${stamp} into '${target}' — verify it, then promote deliberately."

}
