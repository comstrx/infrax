#!/usr/bin/env bash

## render one chart from the payload the bundle carries — the API server's rules, not only the schema
chart_render () {

    local chart="${1:?chart_render needs a chart}" file="" build="" dir=""

    shift

    file="$(mktemp)"
    build="$(mktemp -d)"

    printf 'STACK=light\n' > "${file}"

    dir="$(BUILD_DIR="${build}" "${INFRAX_BIN}" --config "${file}" ci setting TEMPLATE_DIR)"

    helm template probe "${dir}/helm/${chart}" "$@"

    rm -rf "${file}" "${build}"

}
test_data_probe_has_exactly_one_handler () {

    local values="" out=""

    values="$(mktemp)"

    printf 'name: probe\nport: 5432\nprobe:\n  exec:\n    command: [pg_isready]\n' > "${values}"

    out="$(chart_render data -f "${values}")"

    assert_contains "${out}" "pg_isready" "the module's own probe renders"
    assert_lacks "${out}" "tcpSocket" "the chart's fallback never joins a probe the module gave — two handlers are refused by the api server"
    assert_contains "$(chart_render data --set name=probe)" "tcpSocket" "a module with no probe falls back to its port"

    rm -f "${values}"

}
test_issuer_omits_an_empty_email () {

    assert_lacks "$(chart_render gateway --set tlsEnabled=true --set-json 'hostnames=["a.probe.test"]')" "email:" "no email renders as no email, never null"
    assert_contains "$(chart_render gateway --set tlsEnabled=true --set sslEmail=ops@probe.test --set-json 'hostnames=["a.probe.test"]')" 'email: "ops@probe.test"' "an email renders quoted"

}
test_service_renders_only_the_processes_it_declares () {

    local values="" out=""

    values="$(mktemp)"

    printf 'name: probe\nprocesses:\n  worker:\n    command: [run]\n    port: 0\n    route: ""\n    replicas: 1\n    grace: 30\n    resources:\n      requests: { cpu: 10m, memory: 16Mi }\n      limits: { memory: 32Mi }\n' > "${values}"

    out="$(chart_render service -f "${values}")"

    assert_contains "${out}" "name: probe-worker" "the declared process renders"
    assert_lacks "${out}" "name: probe-web" "a process the service never declared never appears"

    rm -f "${values}"

}
