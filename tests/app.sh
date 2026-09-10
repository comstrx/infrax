#!/usr/bin/env bash

test_argv_keeps_every_argument_exact () {

    local argv=""

    argv="$(bash -c "source '${INFRAX_BIN}'; argv_list php artisan catalog:stock 'two words' 'q\"uote'")"

    assert_eq "${argv}" '["php", "artisan", "catalog:stock", "two words", "q\"uote"]' "each argument becomes one json string, quotes escaped"
    assert_eq "$(bash -c "source '${INFRAX_BIN}'; argv_json 'php artisan migrate --force'")" '["php", "artisan", "migrate", "--force"]' "a manifest command splits on words"
    assert_eq "$(bash -c "source '${INFRAX_BIN}'; argv_json '[\"sh\", \"-c\", \"a b\"]'")" '["sh", "-c", "a b"]' "a json array passes through untouched"
    assert_eq "$(bash -c "source '${INFRAX_BIN}'; argv_json ''")" '[]' "no command is an empty argv"

}
test_app_verdict_reads_the_job_status () {

    assert_ok "one success is a pass" bash -c "source '${INFRAX_BIN}'; app_verdict '1/'"
    assert_fails "one failure is not a pass" bash -c "source '${INFRAX_BIN}'; app_verdict '/1'"
    assert_fails "a running job is not a pass" bash -c "source '${INFRAX_BIN}'; app_verdict '/'"
    assert_fails "a running job is not settled" bash -c "source '${INFRAX_BIN}'; app_settled '/'"
    assert_ok "a failed job is settled" bash -c "source '${INFRAX_BIN}'; app_settled '/1'"

}
test_app_polls_survive_a_pod_that_is_not_there_yet () {

    local bin=""

    bin="$(mktemp -d)"

    printf '#!/usr/bin/env bash\necho "error: array index out of bounds" >&2\nexit 1\n' > "${bin}/kubectl"
    chmod +x "${bin}/kubectl"

    assert_eq "$(PATH="${bin}:${PATH}" K8S_NAMESPACE=probe bash -c "set -Eeuo pipefail; source '${INFRAX_BIN}'; phase=\"\$(app_phase job)\"; outcome=\"\$(app_outcome job)\"; printf '%s|%s|alive' \"\${phase}\" \"\${outcome}\"")" "||alive" "a failing kubectl yields an empty poll, never a dead script"

    rm -rf "${bin}"

}
test_app_manifest_runs_on_the_release_of_one_service () {

    local root="" manifest=""

    root="$(fixture_copy)"

    manifest="$(fixture_run "${root}" "app_manifest '${root}/run.yaml' api-run api registry/probe/api:abc123 php artisan about 'two words' >/dev/null; cat '${root}/run.yaml'")"

    assert_contains "${manifest}" "image: registry/probe/api:abc123" "the job runs the release image"
    assert_contains "${manifest}" 'command: ["php", "artisan", "about", "two words"]' "the command is the argv, untouched"
    assert_contains "${manifest}" "name: api-secrets" "the job reads the service secrets"
    assert_contains "${manifest}" "name: api-config" "the job reads the service config"
    assert_contains "${manifest}" "serviceAccountName: api" "the job wears the service identity"
    assert_contains "${manifest}" "namespace: probe" "the job lands in the project namespace"
    assert_contains "${manifest}" "runAsUser: 33" "the job runs as the runtime user"
    assert_contains "${manifest}" "volumes: []" "an object stack mounts nothing"

    assert_contains "$(STACK=standard fixture_run "${root}" "app_manifest '${root}/run.yaml' api-run api registry/probe/api:abc123 true >/dev/null; cat '${root}/run.yaml'")" "claimName: api-storage" "a volume stack mounts the service storage"

    rm -rf "${root}"

}
