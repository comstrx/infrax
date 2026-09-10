#!/usr/bin/env bash

## live production checks — read-only, loud verdicts

AUDIT_FAILED=0

audit_check () {

    local label="${1:?Missing label}" ok="${2:-}" detail="${3:-}"

    if [[ "${ok}" == "true" ]]; then

        succ "${label}${detail:+ — ${detail}}"

        return 0

    fi

    err "${label}${detail:+ — ${detail}}"
    AUDIT_FAILED=1

}
audit_probe () {

    local script="${1:?Missing script}" name="" phase="" left="${AUDIT_PROBE_TRIES}" out=""

    name="audit-$(date -u +%s)-${RANDOM}"

    kubectl -n "${OBSERVABILITY_NAMESPACE}" run "${name}" \
        --restart=Never --image="${AUDIT_IMAGE}" --command -- sh -c "${script}" >/dev/null 2>&1

    while (( left-- )); do

        phase="$(kubectl -n "${OBSERVABILITY_NAMESPACE}" get "pod/${name}" -o jsonpath='{.status.phase}' 2>/dev/null)"

        [[ "${phase}" != "Succeeded" && "${phase}" != "Failed" ]] || break

        sleep "${AUDIT_PROBE_POLL}"

    done

    out="$(kubectl -n "${OBSERVABILITY_NAMESPACE}" logs "${name}" 2>/dev/null | head -1 | tr -d '\r\n')"

    kubectl -n "${OBSERVABILITY_NAMESPACE}" delete "pod/${name}" --wait=false >/dev/null 2>&1

    printf '%s' "${out}"

}
audit_metric () {

    local query="${1:?Missing query}"

    audit_probe "curl -sG http://${METRICS_RELEASE}-kube-prometheus-st-prometheus:${PROMETHEUS_PORT}/api/v1/query --data-urlencode 'query=${query}' \
        | sed -n 's/.*\"value\":\[[0-9.]*,\"\([0-9.e+-]*\)\"\].*/\1/p' | head -1"

}
## argocd apps all synced + healthy
audit_apps () {

    local total="" healthy=""

    ensure kubectl

    total="$(kubectl get application -n "${ARGOCD_NAMESPACE}" --no-headers 2>/dev/null | wc -l)"
    healthy="$(kubectl get application -n "${ARGOCD_NAMESPACE}" --no-headers 2>/dev/null | grep -c "Synced.*Healthy")"

    audit_check "Every application reconciles from git" "$( [[ "${total}" -gt 0 && "${total}" == "${healthy}" ]] && echo true )" "${healthy}/${total} synced and healthy"

}
## prometheus targets all up
audit_targets () {

    local down=""

    down="$(audit_metric 'count(up == 0)')"

    audit_check "Everything the platform measures answers" "$( [[ -z "${down}" ]] && echo true )" "${down:-0} target(s) down"

}
## no alerts firing
audit_alerts () {

    local firing=""

    firing="$(audit_metric 'count(ALERTS{alertstate="firing", alertname!="Watchdog"})')"

    audit_check "Nothing is alerting" "$( [[ -z "${firing}" ]] && echo true )" "${firing:-0} alert(s) firing"

}
## alert rules loaded
audit_rules () {

    local rules=""

    rules="$(audit_metric 'count(count by (alertname) (ALERTS_FOR_STATE)) or vector(0)')"

    audit_check "Alert rules are loaded" "$( [[ -n "${rules}" ]] && (( ${rules%.*} > 0 )) && echo true )" "${rules:-no} rule(s) evaluating"

}
## a recent backup exists for every database module
audit_backup () {

    local module="" age=""

    for module in $(model_modules database); do

        [[ -n "$(module_users "${module}")" ]] || continue

        age="$(audit_metric "round((time() - max(kube_job_status_completion_time{namespace=\"${K8S_NAMESPACE}\", job_name=~\"${module}-backup-.+\"})) / 3600)")"

        audit_check "A recent backup of ${module} exists" "$( [[ -n "${age}" ]] && (( ${age%.*} < 36 )) && echo true )" "${age:-no} hour(s) old"

    done

}
## the edge serves the expected certificate
audit_serves_tls () {

    [[ -n "$(kubectl -n "${GATEWAY_NAMESPACE}" get gateway gateway \
        -o jsonpath='{.spec.listeners[?(@.protocol=="HTTPS")].name}' 2>/dev/null)" ]]

}
## cert validity window
audit_certificate () {

    local days=""

    audit_serves_tls || return 0

    days="$(audit_metric 'round(min(certmanager_certificate_expiration_timestamp_seconds - time()) / 86400)')"

    audit_check "The certificate has life left" "$( [[ -n "${days}" ]] && (( ${days%.*} > 14 )) && echo true )" "${days:-no} day(s) remaining"

}
## loki receives logs
audit_logs () {

    local lines=""

    [[ "${LOGS_ENABLED}" == "true" ]] || return 0

    lines="$(audit_probe "curl -sG http://${LOGS_RELEASE}-loki:${LOKI_PORT}/loki/api/v1/query \
        --data-urlencode 'query=sum(count_over_time({namespace=\"${K8S_NAMESPACE}\"}[10m]))' \
        | sed -n 's/.*\"value\":\[[0-9.]*,\"\([0-9.]*\)\"\].*/\1/p' | head -1")"

    audit_check "Logs are reaching the store" "$( [[ -n "${lines}" ]] && echo true )" "${lines:-0} line(s) in ten minutes"

}
## every public service answers its health path through the platform's own edge
audit_edge () {

    local address="" code="" scheme=http port=80 service="" host="" health=""

    ! audit_serves_tls || { scheme=https; port=443; }

    address="$(k8s_gateway_address clusterIP)"

    if [[ -z "${address}" ]]; then

        audit_check "The platform answers on its own address" "" "the gateway has no service"

        return 0

    fi

    for service in ${SERVICES:-}; do

        host="$(service_host "${service}")"

        [[ -n "${host}" ]] || continue

        health="$(service_get "${service}" HEALTH)"
        code="$(audit_probe "curl -sk -o /dev/null -w '%{http_code}' -m 15 --resolve ${host}:${port}:${address} ${scheme}://${host}${health:-/}")"

        audit_check "${service} answers through its own edge" "$( [[ "${code}" == "200" ]] && echo true )" "${scheme}://${host}${health:-/} → ${code:-no answer}"

    done

}
## run every audit in one sweep
audit_all () {

    ensure kubectl

    step "Auditing the '${STACK}' stack"

    audit_apps
    audit_targets
    audit_rules
    audit_alerts
    audit_edge
    audit_backup
    audit_certificate
    audit_logs

    (( AUDIT_FAILED == 0 )) || die "The stack is not in the shape it claims — the lines above say where"

    succ "Stack '${STACK}' audited — reconciled, measured, alerting, answering, backed up."

}
audit_targets_of () {

    local service="" host="" health=""

    if [[ -n "${WATCH_TARGETS}" ]]; then

        printf '%s\n' ${WATCH_TARGETS}
        return 0

    fi

    for service in ${SERVICES:-}; do

        host="$(service_host "${service}")"

        [[ -n "${host}" ]] || continue

        health="$(service_get "${service}" HEALTH)"
        printf '%s%s\n' "${host}" "${health}"

    done

}
## probe every public service from outside: its health path answers 200 and its certificate is not dying
audit_watch () {

    local target="" host="" code="" expiry="" left="" report=""

    for target in $(audit_targets_of); do

        host="${target%%/*}"
        code="$(curl -sS -o /dev/null -m 15 -w '%{http_code}' "https://${target}" || echo 000)"

        if [[ "${code}" != "200" ]]; then

            report+="🔴 ${target} answered ${code}"$'\n'
            continue

        fi

        expiry="$(echo | openssl s_client -connect "${host}:443" -servername "${host}" 2>/dev/null \
            | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)"

        [[ -n "${expiry}" ]] || continue

        left=$(( ( $(date -d "${expiry}" +%s) - $(date +%s) ) / 86400 ))

        (( left > WATCH_CERT_DAYS )) || report+="🟠 ${host} certificate expires in ${left} days"$'\n'

    done

    if [[ -z "${report}" ]]; then

        succ "Every watched target answers."
        return 0

    fi

    log "${report}"
    audit_alarm "${report}"

    return 1

}
audit_alarm () {

    local token=""

    token="$(secret_get ALERT_BOT_TOKEN)"

    [[ -n "${token}" && -n "${ALERT_CHAT_ID}" ]] || return 0

    curl -sS -o /dev/null -X POST "${TELEGRAM_API}/bot${token}/sendMessage" \
        --data-urlencode "chat_id=${ALERT_CHAT_ID}" \
        --data-urlencode "text=${1:?audit_alarm needs a message}"

}
