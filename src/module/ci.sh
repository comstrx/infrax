#!/usr/bin/env bash

## the release line and the verify wall

ci_tag () {

    if [[ -n "${IMAGE_TAG_OVERRIDE:-}" ]]; then

        printf '%s' "${IMAGE_TAG_OVERRIDE}"
        return 0

    fi

    printf '%s' "${GITHUB_SHA:-$(git -C "${REPO_ROOT}" rev-parse HEAD)}" | cut -c1-"${IMAGE_TAG_LENGTH}"

}
ci_registry () {

    local registry="${REGISTRY:-}"

    [[ -n "${registry}" ]] || registry="$(cloud registry)"

    [[ -n "${registry}" ]] || die "Missing REGISTRY — set it, or give credentials for a cloud that hosts one"

    printf '%s' "${registry}"

}
ci_image () {

    local registry=""

    registry="$(ci_registry)"

    printf '%s/%s/%s' "${registry}" "${PROJECT:?Missing PROJECT}" "${1:?ci_image needs a service}"

}
ci_pick () {

    local service=""

    CI_TARGETS=()

    if (( $# == 0 )); then

        read -ra CI_TARGETS <<< "${SERVICES:?Missing SERVICES}"
        return 0

    fi

    for service in "$@"; do

        app_service "${service}" >/dev/null
        CI_TARGETS+=( "${service}" )

    done

}
## print one resolved setting — the value the release line acts on (secrets refused)
ci_setting () {

    local key="${1:?Missing setting name}"

    ! secret_name "${key}" || die "Refusing to print '${key}' — it is a secret"

    printf '%s\n' "${!key:-}"

}
ci_login () {

    local registry=""

    ensure docker

    registry="$(ci_registry)"

    if [[ -n "${REGISTRY_USER}" ]]; then

        secret_require GIT_TOKEN \
            | docker login --username "${REGISTRY_USER}" --password-stdin "${registry%%/*}" \
            || die "Registry login failed"

        return 0

    fi

    cloud registry_login "${registry%%/*}"

}
ci_dockerfile () {

    local service="${1}" file="" dir=""

    file="$(service_get "${service}" DOCKERFILE)"

    if [[ -n "${file}" ]]; then

        printf '%s' "${REPO_ROOT}/${file}"
        return 0

    fi

    dir="$(runtime_dir "$(service_runtime "${service}")")"

    printf '%s' "${dir}/Dockerfile"

}
ci_build_args () {

    local service="${1}" key="" value=""

    for key in $(service_get "${service}" BUILD_ARGS); do

        value="$(service_get "${service}" "${key}")"
        printf '%s\n' --build-arg "${key}=${value}"

    done

}
## build the image of every service (or the named ones) for this stack
ci_build () {

    local service="" image="" tag="" dockerfile="" context="" args=()

    ensure docker

    tag="$(ci_tag)"

    ci_pick "$@"

    for service in "${CI_TARGETS[@]}"; do

        image="$(ci_image "${service}")"
        dockerfile="$(ci_dockerfile "${service}")"
        context="${REPO_ROOT}/$(service_path "${service}")"

        mapfile -t args < <(ci_build_args "${service}")

        step "Building ${service} → ${image}:${tag}"

        run docker build \
            -f "${dockerfile}" \
            "${args[@]}" \
            --label "org.opencontainers.image.source=${GIT_REPO_URL%.git}" \
            --label "org.opencontainers.image.revision=${tag}" \
            --label "io.infrax.service=${service}" \
            -t "${image}:${tag}" \
            ${DOCKER_NETWORK:+--network=${DOCKER_NETWORK}} \
            "${context}"

    done

}
ci_answers () {

    local address="${1}" health="${2}" code=""

    if [[ -n "${health}" ]]; then

        code="$(curl -s -o /dev/null -m 3 -w '%{http_code}' "http://${address}${health}" || true)"
        [[ "${code}" == "200" ]]
        return

    fi

    ( : > "/dev/tcp/${address%:*}/${address##*:}" ) 2>/dev/null

}
## boot every built image and prove it before it ships — its runtime's own checks, then its health path answering
ci_prove () {

    local service="" image="" port="" health="" prove="" dir="" id="" address="" pair="" waited=0 flags=() pairs=()

    ensure docker curl

    ci_pick "$@"

    for service in "${CI_TARGETS[@]}"; do

        image="$(ci_image "${service}"):$(ci_tag)"
        port="$(service_get "${service}" PORT)"
        health="$(service_get "${service}" HEALTH)"
        dir="$(runtime_dir "$(service_runtime "${service}")")"
        prove="${dir}/prove.sh"
        flags=( -e "PORT=${port}" )

        read -ra pairs <<< "$(service_get "${service}" PROVE_ENV)"

        for pair in "${pairs[@]}"; do

            flags+=( -e "${pair}" )

        done

        if [[ -f "${prove}" ]]; then

            docker run --rm --entrypoint sh "${image}" -c "$(cat "${prove}")" || die "${service}: the image does not carry what its runtime needs"

        fi

        id="$(docker run -d --rm "${flags[@]}" -p "127.0.0.1::${port}" "${image}")" || die "${service}: ${image} does not start"
        address="$(docker port "${id}" "${port}/tcp" | sed -n '1p')"
        waited=0

        until ci_answers "${address}" "${health}"; do

            if (( waited >= PROVE_WAIT )); then

                docker logs "${id}" 2>&1 | tail -n "${POD_LOG_LINES}" >&2
                docker rm -f "${id}" >/dev/null 2>&1 || true

                die "${service}: ${image} never answered ${health:-its port} within ${PROVE_WAIT}s"

            fi

            sleep 2
            waited=$(( waited + 2 ))

        done

        docker rm -f "${id}" >/dev/null 2>&1 || true

        succ "${service}: proven — it boots and answers ${health:-on its port} after ${waited}s."

    done

}
ci_shipped () {

    docker manifest inspect "${1}" >/dev/null 2>&1

}
## push every image — an immutable tag already in the registry is reused, never fought
ci_push () {

    local service="" ref="" tag=""

    tag="$(ci_tag)"

    ci_login
    ci_pick "$@"

    for service in "${CI_TARGETS[@]}"; do

        ref="$(ci_image "${service}"):${tag}"

        if ci_shipped "${ref}"; then info "Already in the registry — ${ref##*/} is immutable and reused"; continue; fi

        run docker push "${ref}"

    done

}
ci_accept () {

    local finding="${1:?Missing finding}"

    [[ "${CVE_ALLOW}" == "true" ]] \
        || die "${finding} — review them, then re-release with CVE_ALLOW=true to accept"

    warn "${finding} accepted via CVE_ALLOW."

}
## count the fixable CRITICAL findings of one image with trivy
ci_trivy () {

    local image="${1:?Usage: ci trivy <image>}"

    ensure trivy jq

    trivy image --scanners vuln --severity CRITICAL --ignore-unfixed --format json --quiet "${image}" \
        | jq '[.Results[]?.Vulnerabilities // [] | length] | add // 0'

}
## the CVE gate — every image scanned, trivy where the registry is ours, the cloud's scanner where it is theirs; CRITICAL blocks unless accepted
ci_scan () {

    local service="" tag="" critical="" image=""

    tag="$(ci_tag)"

    ci_pick "$@"

    for service in "${CI_TARGETS[@]}"; do

        image="$(ci_image "${service}"):${tag}"

        step "Scanning ${image}"

        if [[ -n "${REGISTRY}" ]]; then critical="$(ci_trivy "${image}")"; else critical="$(cloud registry_criticals "${service}" "${tag}")"; fi

        [[ "${critical}" =~ ^[0-9]+$ ]] || critical=0

        if (( critical > 0 )); then

            ci_accept "${service}: ${critical} CRITICAL finding(s) on ${tag}"
            continue

        fi

        succ "${service}: scan clean — zero fixable CRITICAL findings."

    done

}
## derive the stack values from the manifest, write the new image tag, commit what argocd reads
ci_bump () {

    local tag=""

    tag="$(ci_tag)"

    helm_seed
    helm_bump "${tag}"

    is_ci || return 0

    git -C "${REPO_ROOT}" config user.name "${CI_BOT_NAME}"
    git -C "${REPO_ROOT}" config user.email "${CI_BOT_EMAIL}"
    git -C "${REPO_ROOT}" add "$(helm_deploy_dir)"

    if git -C "${REPO_ROOT}" diff --cached --quiet; then

        info "Values already carry this topology — nothing to bump."
        return 0

    fi

    git -C "${REPO_ROOT}" commit --quiet -m "chore(${INFRAX_NAME}): ${STACK} topology for ${tag}" || die "GitOps bump commit failed"

    if ! git -C "${REPO_ROOT}" push --quiet; then

        warn "GitOps bump raced another push — rebasing onto the remote"

        git -C "${REPO_ROOT}" pull --rebase --quiet || die "GitOps bump rebase failed — the release is NOT live"
        git -C "${REPO_ROOT}" push --quiet || die "GitOps bump push failed — the release is NOT live"

    fi

    succ "Stack values committed — the image tag itself rides the application, not the file."

}
## refuse a release the manifest cannot carry — before a single byte is built
ci_preflight () {

    model_verify
    secrets_check

    succ "Preflight clear — the manifest carries this release."

}
## wait until every public service answers its health path on its own name
ci_deployed () {

    local service="" host="" health="" code="" waited=0

    if ! dns_managed; then

        warn "This stack does not own its names — the release is live on the cluster; point its hosts at the edge yourself."
        return 0

    fi

    for service in ${SERVICES}; do

        host="$(service_host "${service}")"

        [[ -n "${host}" ]] || continue

        health="$(service_get "${service}" HEALTH)"
        waited=0
        code=""

        step "Waiting for https://${host}${health} to answer"

        while (( waited < RELEASE_WAIT )); do

            code="$(curl -sS -o /dev/null -m 15 -w '%{http_code}' "https://${host}${health}" 2>/dev/null || true)"

            [[ "${code}" != "200" ]] || break

            sleep "${RELEASE_POLL}"
            waited=$(( waited + RELEASE_POLL ))

        done

        [[ "${code}" == "200" ]] || die "${service} does not answer on https://${host}${health} after ${RELEASE_WAIT}s (last: ${code:-nothing})"

        succ "${service} is live on ${host} after ${waited}s."

    done

}
## tell the alert channel how the release ended — success|failure, called by the workflow when the job settles
ci_outcome () {

    local status="${1:?ci outcome needs the job status}" tag="" run=""

    tag="$(ci_tag)"
    run="${GITHUB_SERVER_URL:-${GITHUB_URL}}/${GITHUB_REPOSITORY:-${GIT_REPO}}/actions/runs/${GITHUB_RUN_ID:-}"

    case "${status}" in
        success) audit_alarm "🚀 ${PROJECT} ${tag} is live on '${STACK}' — ${SERVICES}" ;;
        *)       audit_alarm "🔴 ${PROJECT} release ${tag} on '${STACK}' ${status} — ${run}" ;;
    esac

    succ "Outcome ${status} reported."

}
## the ONE entry point: converge cloud → build → prove → push → scan → vendor → bump → converge cluster + names → wait for the edge
ci_release () {

    ci_preflight
    tofu_ensure
    ci_build
    ci_prove
    ci_push
    ci_scan
    helm_vendor
    ci_bump
    k8s_ensure
    dns_ensure
    ci_deployed

    succ "Release $(ci_tag) delivered to '${STACK}' — ${SERVICES}."

}
ci_rendered () {

    local file="${1}" kind="${2}" name="${3}"

    awk -v kind="${kind}" -v name="${name}" '
        /^---/ { k = ""; n = "" }
        /^kind: / { k = $2 }
        /^  name: / && n == "" { n = $2 }
        k == kind && n == name { found = 1 }
        END { exit found ? 0 : 1 }
    ' "${file}"

}
ci_matrix_stack () {

    local stack="${1}" root="" rendered="" name="" chart="" host="" args=() hosts=() services=() stores=() tools=()

    root="${BUILD_DIR}/matrix/${stack}"
    rendered="${root}/rendered.yaml"
    args=( -s "${stack}" -y -e "INFRAX_YES=1" )

    rm -rf "${root}"
    ensure_dir "${root}"

    for name in $(model_modules database); do

        args+=( -e "$(model_key "${name}")_ADDRESS=${MATRIX_HOST}" )

    done

    "${INFRAX_BIN}" "${args[@]}" helm seed "${root}" >/dev/null || die "Matrix seed failed for '${stack}'"
    "${INFRAX_BIN}" "${args[@]}" helm lint "${root}" >/dev/null || die "Matrix lint failed for '${stack}'"

    : > "${rendered}"

    for name in ${SERVICES} $(model_modules "database cache tool"); do

        chart="$(helm_chart_of "${name}")"

        helm template "${name}" "$(helm_charts)/${chart}" -f "${root}/helm/values/${name}.${stack}.yaml" -n "${K8S_NAMESPACE}" >> "${rendered}" \
            || die "Matrix render failed for '${name}' on '${stack}'"

    done

    kubeconform -strict -summary -ignore-missing-schemas -kubernetes-version "${K8S_VERSION}.0" "${rendered}" >/dev/null \
        || die "Matrix schema check failed for '${stack}'"

    for name in ${SERVICES}; do

        ci_rendered "${rendered}" Deployment "${name}-$(k8s_first_process "${name}")" || die "Matrix: '${stack}' renders no workload for ${name}"
        ci_rendered "${rendered}" NetworkPolicy "${name}" || die "Matrix: '${stack}' leaves ${name} without a network policy"
        ci_rendered "${rendered}" ServiceAccount "${name}" || die "Matrix: '${stack}' gives ${name} no identity"

        for chart in $(service_uses "${name}"); do

            [[ "$(module_kind "${chart}")" != "database" ]] || ci_rendered "${rendered}" Job "${name}-provision-${chart}" \
                || die "Matrix: '${stack}' never provisions ${name}'s own ${chart} database"

        done

        [[ -z "$(service_get "${name}" MIGRATE)" ]] || ci_rendered "${rendered}" Job "${name}-migrate" || die "Matrix: '${stack}' drops the migration of ${name}"

        mapfile -t hosts < <(service_hosts "${name}")

        (( ${#hosts[@]} == 0 )) || ci_rendered "${rendered}" HTTPRoute "${name}" || die "Matrix: '${stack}' answers for ${name} on no route"

    done

    for name in $(model_modules "database cache"); do

        if [[ "$(awk '/^mode: /{print $2; exit}' "${root}/helm/values/${name}.${stack}.yaml")" == "managed" ]]; then

            grep -q "externalName: ${MATRIX_HOST}" "${rendered}" || die "Matrix: '${stack}' runs ${name} managed but never names its address"

        else

            ci_rendered "${rendered}" StatefulSet "${name}" || die "Matrix: '${stack}' lost the StatefulSet named ${name} — state keeps its name for life"

        fi

    done

    ! grep -rlE '^  tag: "?(latest)?"?$' "$(helm_values_dir)"/*."${stack}".yaml 2>/dev/null \
        || die "Deploy truth carries a floating tag on '${stack}' — every service ships an immutable git sha"

    for name in "$(helm_values_dir)"/*."${stack}".yaml; do

        [[ -f "${name}" ]] || continue

        diff <(grep '^  repository: ' "${name}") <(grep '^  repository: ' "${root}/helm/values/${name##*/}") >/dev/null \
            || die "Matrix: '${stack}' is committed against a registry this project does not own (${name##*/})"

    done

    mapfile -t hosts < <(model_hosts)

    for host in "${hosts[@]}"; do

        [[ "${host}" == "${HOST_PREFIX:-}"*".${BASE_DOMAIN}" ]] || die "Matrix: '${stack}' answers on ${host}, outside ${HOST_PREFIX:-}*.${BASE_DOMAIN}"

    done

    read -ra services <<< "${SERVICES}"
    mapfile -t stores < <(model_modules "database cache")
    mapfile -t tools < <(model_modules tool)

    rm -rf "${root}/apps"
    cp -R "${TEMPLATE_DIR}/argocd/apps" "${root}/apps"
    [[ ! -d "${root}/argocd/apps/files" ]] || cp -R "${root}/argocd/apps/files" "${root}/apps/files"

    helm template apps "${root}/apps" --set stack="${stack}" --set imageTag=probe \
        --set-json "services=$(yaml_list "${services[@]}")" --set-json "data=$(yaml_list "${stores[@]}")" --set-json "tools=$(yaml_list "${tools[@]}")" \
        > "${root}/apps.yaml" || die "Matrix: '${stack}' app-of-apps does not render"

    for name in "${services[@]}" "${stores[@]}" "${tools[@]}"; do

        ci_rendered "${root}/apps.yaml" Application "${name}" || die "Matrix: '${stack}' app-of-apps forgets ${name}"

    done

    grep -q 'value: "probe"' "${root}/apps.yaml" || die "Matrix: '${stack}' drops the release tag on its way to the services"

    succ "Matrix '${stack}' — ${#services[@]} service(s), ${#stores[@]} data module(s), ${#tools[@]} tool(s) render, validate and keep their contract."

}
## law: every stack renders a coherent platform — workloads, identities, policies, state names, routes, apps
ci_matrix () {

    local stack=""

    ensure helm kubeconform

    ensure_dir "${BUILD_DIR}/matrix"

    for stack in ${STACKS}; do

        ci_matrix_stack "${stack}"

    done

    ci_certs
    ci_edge
    ci_dashboards

    succ "Render matrix proven — every stack keeps the contract its manifest implies."

}
## law: the certificate covers exactly the names the routes answer on
ci_certs () {

    local gateway="${BUILD_DIR}/matrix/gateway.yaml" hosts=() routed="" certified=""

    ensure helm

    mapfile -t hosts < <(model_hosts)

    (( ${#hosts[@]} )) || { info "No public name — the certificate law has nothing to hold."; return 0; }

    run helm template gateway "$(helm_charts)/gateway" \
        --set tlsEnabled=true --set dns01=true --set sslEmail="${SSL_EMAIL:-${LINT_EMAIL}}" \
        --set-json "hostnames=$(yaml_list "${hosts[@]}")" > "${gateway}" \
        || die "Gateway render failed"

    certified="$(awk '/dnsNames:/{on=1; next} on && /^    - /{gsub(/^    - |"/, ""); print; next} {on=0}' "${gateway}" | sort -u | paste -sd ' ' -)"
    routed="$(printf '%s\n' "${hosts[@]}" | sort -u | paste -sd ' ' -)"

    [[ "${certified}" == "${routed}" ]] || die "TLS gap: routes answer on [${routed}] but the certificate covers [${certified}]"

    succ "TLS contract proven — every routed name is a certified name, and nothing else is."

}
## law: edge wiring renders any annotations and the cloud mints exactly its own
ci_edge () {

    local rendered=""

    ensure helm

    rendered="$(helm template gateway "$(helm_charts)/gateway" --set sslEmail="${LINT_EMAIL}" --set-json "hostnames=[\"${LINT_DOMAIN}\"]" \
        --set edgeType=lb --set-string 'edgeAnnotations.fixed/addresses=probe-a\,probe-b')" \
        || die "Edge render failed"

    grep -q 'fixed/addresses: "probe-a,probe-b"' <<< "${rendered}" \
        || die "Edge: the balancer forgets the annotations it was given"

    rendered="$(EDGE_TYPE=lb EDGE_EIPS='' cloud edge_annotations)"

    jq -e . <<< "${rendered}" >/dev/null || die "Edge: the ${CLOUD} annotations are not a json object"

    succ "Edge contract proven — the chart renders any annotations, ${CLOUD} mints a clean object."

}
## law: grafana dashboards parse
ci_dashboards () {

    local file=""

    ensure helm python3

    python3 -c 'import yaml' 2>/dev/null || pkg_install python3-yaml

    file="${BUILD_DIR}/matrix/dashboards.yaml"

    helm template observability "$(helm_charts)/observability" \
        --set host="${LINT_DOMAIN}" --set appNamespace="${K8S_NAMESPACE}" \
        --set metricsRelease="${METRICS_RELEASE}" > "${file}" \
        || die "Observability render failed"

    python3 -c "
import sys, yaml, json
maps = [d for d in yaml.safe_load_all(open('${file}')) if d and d.get('kind') == 'ConfigMap']
assert maps, 'no dashboard shipped'
for m in maps:
    for name, body in m['data'].items():
        json.loads(body)
" || die "A dashboard this bundle ships is not valid json"

    succ "Dashboards proven — every panel this bundle ships parses."

}
ci_github () {

    local method="${1:?Missing method}" path="${2:?Missing path}" body="${3:-}" token=""

    token="$(secret_require GIT_TOKEN)"

    curl -sS -o /dev/null -w '%{http_code}' -X "${method}" "${GITHUB_API}/repos/${GIT_REPO}${path}" \
        -H "Authorization: Bearer ${token}" \
        -H "Accept: application/vnd.github+json" \
        ${body:+--data "${body}"}

}
## arm or disarm the external github watcher for this stack
ci_guard () {

    local state="${1:-on}" code=""

    ensure curl

    if [[ "${state}" == "off" ]]; then

        code="$(ci_github PUT "/actions/workflows/watch.yml/disable")"

        [[ "${code}" == 2* ]] || die "Cannot disable the watcher (HTTP ${code})"

        succ "External guard disarmed — nothing probes from GitHub anymore."

        return 0

    fi

    code="$(ci_github PUT "/actions/workflows/watch.yml/enable")"

    [[ "${code}" == 2* ]] || die "Cannot enable the watcher (HTTP ${code})"

    [[ -n "$(secret_get ALERT_BOT_TOKEN)" ]] || warn "ALERT_BOT_TOKEN repo secret is yours to set once — without it the guard sees but cannot speak"

    succ "External guard armed — GitHub probes every public service every ten minutes."

}
ci_probe () {

    printf '%s\n' "${GIT_TOKEN:+manifest}" "${EC2_TYPE:+knob}" "${SERVICE_PROBE_RUNTIME:+service}" "${FOREIGN_KEY:+foreign}" | paste -sd ' ' -

}
## law: the repo secrets reach the release line — manifest keys, knobs and service keys load, foreign keys never do
ci_loader () {

    local seen=""

    seen="$(JSON_ENV='{"GIT_TOKEN":"probe","EC2_TYPE":"probe","SERVICE_PROBE_RUNTIME":"go","FOREIGN_KEY":"probe"}' "${INFRAX_BIN}" -y ci probe)"

    [[ "${seen}" == "manifest knob service " ]] || die "The secrets loader is wrong — it saw [${seen}], expected [manifest knob service ]"

    succ "Secrets loader proven — manifest keys, knobs and service keys load, foreign keys stay out."

}
## law: every rendered template resolves — names computed at render time are read from the scripts themselves
ci_templates () {

    local file="" key="" computed=""

    computed=" $(infrax_code | grep -oE '\b[A-Z][A-Z0-9_]*=' | tr -d = | sort -u | paste -sd ' ' -) "

    for file in "${TEMPLATE_DIR}"/argocd/project.yaml "${TEMPLATE_DIR}"/argocd/root.yaml "${TEMPLATE_DIR}"/*/*.yaml "${TEMPLATE_DIR}"/k8s/*.yaml \
        "${TEMPLATE_DIR}"/helm/values/*.tpl "${TEMPLATE_DIR}"/module/*/values.tpl "${TEMPLATE_DIR}"/module/*/app.yaml "${TEMPLATE_DIR}"/module/*/*.env \
        "${TEMPLATE_DIR}"/runtime/*/env; do

        [[ -f "${file}" && "${file}" != */helm/*/templates/* && "${file}" != */argocd/apps/* ]] || continue

        for key in $(placeholders "${file}"); do

            [[ -n "${!key+x}" || "${computed}" == *" ${key} "* ]] || die "Template ${file#"${TEMPLATE_DIR}"/} names ${key} — nothing defines it"

        done

    done

    succ "Templates resolve — every placeholder has a source."

}
## law: workflow files lint clean
ci_workflows () {

    local workflows=()

    ensure actionlint

    mapfile -t workflows < <(find "${REPO_ROOT}/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)

    (( ${#workflows[@]} )) || { info "No workflows to lint."; return 0; }

    run actionlint "${workflows[@]}"

    succ "Workflows lint clean."

}
## law: no secret material in tracked files
ci_leaks () {

    local config="" path=""

    ensure gitleaks

    config="$(tmp_file)"

    cat > "${config}" <<'TOML'
[extend]
useDefault = true

[allowlist]
paths = ['''\.infrax/''', '''\.terraform/''']
regexes = ['''^[A-Z][A-Z0-9_]*=$''']
TOML

    for path in "${REPO_ROOT}/.github" "$(helm_deploy_dir)" "${REPO_ROOT}"/infrax*.env "${REPO_ROOT}/.env.example" "${REPO_ROOT}/.secret.example"; do

        [[ -e "${path}" ]] || continue

        run gitleaks dir "${path}" --no-banner --redact -c "${config}"

    done

    rm -f "${config}"

    succ "No secret material in the workflows, the gitops path, the manifest or the examples."

}
## the wall: shellcheck, the manifest law, the render matrix, the loader, templates, workflows, leaks, tofu
ci_verify () {

    local file="" code="" failed=0

    ensure shellcheck helm tofu

    code="$(tmp_file)"
    infrax_code > "${code}"

    while IFS= read -r file; do

        shellcheck -s bash -x -S "${SHELLCHECK_SEVERITY}" -e "${SHELLCHECK_EXCLUDES}" "${file}" || failed=1

    done < <(find "${TEMPLATE_DIR}" -name '*.sh' ! -path '*/module/*/scripts/*'; printf '%s\n' "${code}")

    rm -f "${code}"

    (( failed == 0 )) || die "Shell lint failed"

    model_verify
    ci_matrix
    ci_loader
    ci_templates
    ci_workflows
    ci_leaks
    secrets_example
    tofu_fmt -check
    tofu_validate

    succ "${INFRAX_NAME} verification passed."

}
## refuse to proceed unless the CI run for this commit is green (waits out an in-flight one)
ci_gate () {

    local attempt="" verdict=""

    ensure gh

    for attempt in $(seq 1 "${CI_GATE_ATTEMPTS}"); do

        verdict="$(gh run list --repo "${GITHUB_REPOSITORY:-${GIT_REPO}}" --workflow=CI --commit "$(git -C "${REPO_ROOT}" rev-parse HEAD)" \
            --json status,conclusion --jq '.[0] | .status + "/" + (.conclusion // "")')"

        case "${verdict}" in

            completed/success ) succ "CI is green for this commit."; return 0 ;;
            completed/*       ) die "CI concluded '${verdict}' — refused" ;;
            ""                ) die "No CI run found for this commit — refused" ;;
            *                 ) info "CI is '${verdict}' — waiting (${attempt}/${CI_GATE_ATTEMPTS})"; sleep "${CI_GATE_POLL}" ;;

        esac

    done

    die "CI never concluded — refused"

}
