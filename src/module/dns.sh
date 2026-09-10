#!/usr/bin/env bash

## managed names — point every public name at the stack edge, and never touch a name this stack does not own

dns_call () {

    local method="${1:?Missing method}" path="${2:?Missing path}" body="${3:-}" token=""

    token="$(secret_require CLOUDFLARE_API_TOKEN)"

    curl -sS -X "${method}" "${CLOUDFLARE_API}${path}" \
        -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" \
        ${body:+--data "${body}"}

}
## the zone this stack answers in — CLOUDFLARE_DOMAIN_ID when the manifest names it, looked up by BASE_DOMAIN otherwise
dns_zone () {

    [[ "${DNS_PROVIDER}" == "cloudflare" ]] || die "DNS_PROVIDER '${DNS_PROVIDER}' is not one infrax speaks — cloudflare"

    if [[ -z "${CLOUDFLARE_DOMAIN_ID}" ]]; then

        ensure curl jq

        CLOUDFLARE_DOMAIN_ID="$(dns_call GET "/zones?name=${BASE_DOMAIN}" | jq -r '.result[0].id // empty')"

        [[ -n "${CLOUDFLARE_DOMAIN_ID}" ]] || die "No zone answers for ${BASE_DOMAIN} — the token cannot see it, or the zone is not there"

        export CLOUDFLARE_DOMAIN_ID

    fi

    printf '%s' "${CLOUDFLARE_DOMAIN_ID}"

}
dns_api () {

    local method="${1:?Missing method}" path="${2:?Missing path}" body="${3:-}" zone=""

    zone="$(dns_zone)"

    dns_call "${method}" "/zones/${zone}${path}" "${body}"

}
## true when this stack owns its names
dns_managed () {

    [[ -n "${DNS_PROVIDER}" ]]

}
## the names this stack owns — every public host, nothing else
dns_names () {

    model_hosts | sort -u

}
## the ownership law: a name is ours only when this stack answers on it, inside our prefix, under our domain
dns_owns () {

    local name="${1:?dns_owns needs a name}"

    [[ "${name}" == *".${BASE_DOMAIN}" && "${name}" == "${HOST_PREFIX:-}"* ]] || return 1
    [[ " $(dns_names | paste -sd ' ' -) " == *" ${name} "* ]]

}
## resolve the current edge address
dns_edge () {

    local address=""

    if [[ -n "${EDGE_TYPE}" ]]; then

        ensure kubectl

        address="$(k8s_gateway_address hostname)"

        if [[ -n "${address}" ]]; then printf 'CNAME %s' "${address}"; return 0; fi

        address="$(k8s_gateway_address ip)"

        if [[ -n "${address}" ]]; then printf 'A %s' "${address}"; return 0; fi

        warn "The gateway has no load balancer address yet — run '${INFRAX_NAME} dns sync' once it does"

        return 1

    fi

    address="$(server_host)"

    printf 'A %s' "${address}"

}
## upsert one record this stack owns
dns_record () {

    local name="${1:?Missing name}" type="${2:?Missing type}" content="${3:?Missing content}" id="" body=""

    ensure curl jq

    dns_owns "${name}" || die "Refusing to write ${name} — this stack does not own it (prefix '${HOST_PREFIX:-}', domain '${BASE_DOMAIN}')"

    id="$(dns_api GET "/dns_records?name=${name}" | jq -r '.result[0].id // empty')"

    body="$(jq -nc --arg type "${type}" --arg name "${name}" --arg content "${content}" \
        '{type: $type, name: $name, content: $content, proxied: false, ttl: 60}')"

    if [[ -n "${id}" ]]; then

        dns_api PUT "/dns_records/${id}" "${body}" | jq -e '.success' >/dev/null || die "Cannot update record: ${name}"

        info "${name} → ${type} ${content}"

        return 0

    fi

    dns_api POST "/dns_records" "${body}" | jq -e '.success' >/dev/null || die "Cannot create record: ${name}"

    info "${name} → ${type} ${content} (new)"

}
## point every name this stack owns at the current edge
dns_sync () {

    local edge="" type="" content="" name=""

    dns_managed || die "Missing DNS_PROVIDER — no stack owns names without one"

    edge="$(dns_edge)"
    type="${edge%% *}"
    content="${edge#* }"

    for name in $(dns_names); do

        dns_record "${name}" "${type}" "${content}"

    done

    succ "DNS points at this stack — every name it owns resolves to its edge."

}
## converge the edge names when this stack owns any — silent otherwise
dns_ensure () {

    dns_managed || { info "No DNS provider for this stack — names stay as they are."; return 0; }
    dns_edge >/dev/null 2>&1 || { warn "The edge has no address yet — names stay as they are until it does."; return 0; }

    dns_sync

}
## show the live records this stack owns
dns_show () {

    local owned=""

    ensure curl jq

    owned="$(dns_names | paste -sd ' ' -)"

    dns_api GET "/dns_records?per_page=500" \
        | jq -r --arg owned " ${owned} " '.result[] | select($owned | contains(" " + .name + " ")) | "\(.type)\t\(.name)\t\(.content)\tproxied=\(.proxied)"'

}
## remove every record this stack owns (confirmed) — for a stack that is going away
dns_purge () {

    local name="" id=""

    ensure curl jq

    confirm "Delete every DNS record the '${STACK}' stack owns?"

    for name in $(dns_names); do

        dns_owns "${name}" || continue

        id="$(dns_api GET "/dns_records?name=${name}" | jq -r '.result[0].id // empty')"

        [[ -n "${id}" ]] || continue

        dns_api DELETE "/dns_records/${id}" | jq -e '.success' >/dev/null || die "Cannot delete record: ${name}"

        info "${name} removed"

    done

    succ "Every name this stack owned is released."

}
