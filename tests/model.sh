#!/usr/bin/env bash

test_model_law_holds_on_the_fixture () {

    local root=""

    root="$(fixture_copy)"

    assert_ok "the fixture manifest holds" fixture_run "${root}" model_verify

    rm -rf "${root}"

}
test_model_law_names_every_fault () {

    local root="" output=""

    root="$(fixture_copy)"

    printf '%s\n' 'SERVICE_API_CALLS=ghost' 'SERVICE_API_USES=postgresql pgadmin4' 'SERVICE_WORKER_RUNTIME=cobol' 'SERVICE_GHOST_PORT=1' 'NOT_A_KEY=1' >> "${root}/infrax.env"

    output="$(fixture_run "${root}" model_verify 2>&1 || true)"

    assert_contains "${output}" "calls 'ghost', which SERVICES does not declare" "a call to an undeclared service is a fault"
    assert_contains "${output}" "uses the tool 'pgadmin4'" "a service cannot use a tool"
    assert_contains "${output}" "SERVICE_WORKER_RUNTIME must name one of" "an unknown runtime is a fault"
    assert_contains "${output}" "SERVICE_GHOST_PORT names no declared service" "a key for a ghost service is a fault"
    assert_contains "${output}" "NOT_A_KEY is not a key infrax reads" "a foreign key is a fault"
    assert_contains "${output}" "5 fault(s)" "every fault is counted before the law refuses"

    rm -rf "${root}"

}
test_model_last_line_wins_inside_a_file () {

    local root=""

    root="$(fixture_copy)"

    printf 'SERVICE_API_REPLICAS_MIN=3\nSERVICE_API_REPLICAS_MIN=4\n' >> "${root}/infrax.light.env"

    assert_eq "$(fixture_run "${root}" 'service_get api REPLICAS_MIN')" "4" "a key written twice takes its last value, like every dotenv reader"

    rm -rf "${root}"

}
test_bindings_follow_the_runtime_style () {

    local root="" api="" worker="" again=""

    root="$(fixture_copy)"

    api="$(fixture_run "${root}" 'bind_env api')"
    worker="$(fixture_run "${root}" 'bind_env worker')"
    again="$(fixture_run "${root}" 'bind_env worker')"

    assert_contains "${api}" "DB_CONNECTION=pgsql" "laravel binds its primary database the laravel way"
    assert_contains "${api}" "DB_HOST=postgresql" "the host is the module name"
    assert_contains "${api}" "DB_DATABASE=api" "each service owns its database"
    assert_contains "${api}" "DB_USERNAME=api" "each service owns its user"
    assert_contains "${api}" "REDIS_PREFIX=api_" "each service owns its cache prefix"
    assert_contains "${api}" "FILESYSTEM_DISK=s3" "an object stack stores in the cloud"
    assert_contains "${api}" "AWS_BUCKET=probe-api-" "each service owns its bucket"
    assert_contains "${worker}" "DATABASE_URL=postgresql://worker:" "a url service gets its primary database as DATABASE_URL"
    assert_contains "${worker}" "@postgresql:5432/worker?sslmode=disable" "in cluster the database speaks plain on the private network"
    assert_lacks "${worker}" "REDIS_" "a service is bound to what it uses, nothing else"
    assert_eq "${worker}" "${again}" "bindings are deterministic — the same manifest mints the same passwords"
    assert_ne "$(sed -n 's/^DB_PASSWORD=//p' <<< "${api}")" "$(sed -nE 's#^DATABASE_URL=postgresql://worker:([^@]*)@.*#\1#p' <<< "${worker}")" "no two services share a password"

    rm -rf "${root}"

}
test_dns_owns_only_its_names () {

    local root=""

    root="$(fixture_copy)"

    assert_ok "a service host is ours" fixture_run "${root}" 'dns_owns probe-api.probe.test'
    assert_ok "a tool host is ours" fixture_run "${root}" 'dns_owns probe-pgadmin.probe.test'
    assert_ok "the grafana host is ours" fixture_run "${root}" 'dns_owns probe-grafana.probe.test'
    assert_fails "a name outside the prefix is not ours" fixture_run "${root}" 'dns_owns api.probe.test'
    assert_fails "a name under another domain is not ours" fixture_run "${root}" 'dns_owns probe-api.other.test'
    assert_fails "a name nothing answers on is not ours" fixture_run "${root}" 'dns_owns probe-ghost.probe.test'
    assert_fails "the apex is never ours" fixture_run "${root}" 'dns_owns probe.test'

    rm -rf "${root}"

}
test_seed_writes_a_zero_trust_topology () {

    local root="" values="" api="" worker="" postgresql="" pgadmin=""

    root="$(fixture_copy)"
    values="${root}/deploy/helm/values"

    assert_ok "the seed runs on the fixture" fixture_run "${root}" "helm_seed '${root}/deploy'"

    api="$(cat "${values}/api.light.yaml")"
    worker="$(cat "${values}/worker.light.yaml")"
    postgresql="$(cat "${values}/postgresql.light.yaml")"
    pgadmin="$(cat "${values}/pgadmin4.light.yaml")"

    assert_contains "${api}" "repository: registry.probe.test/probe/api" "the image lives in the project's registry"
    assert_contains "${api}" 'hostnames: ["probe-api.probe.test"]' "a public service answers on its prefixed host"
    assert_contains "${api}" "  horizon:" "a declared process becomes a workload"
    assert_contains "${api}" "WORKER_URL: \"http://worker:8080\"" "a caller learns its callee by name"
    assert_contains "${worker}" 'callers: ["api"]' "a callee admits only its declared callers"
    assert_contains "${worker}" "enabled: false" "a private service has no route"
    assert_contains "${worker}" "min: 2" "a service without its own floor takes the global one"
    assert_contains "${worker}" "max: 2" "the stack file reaches the service"
    assert_contains "${postgresql}" 'clients: ["api", "worker", "pgadmin4"]' "a database admits its services and its tools, nothing else"
    assert_contains "${postgresql}" 'databases: ["api", "worker"]' "every user of a database gets its own"
    assert_contains "${pgadmin}" 'hostnames: ["probe-pgadmin.probe.test"]' "a tool answers on its prefixed host"
    assert_ok "the redis values exist" test -f "${values}/redis.light.yaml"
    assert_fails "storage runs no workload" test -f "${values}/storage.light.yaml"

    rm -rf "${root}"

}
