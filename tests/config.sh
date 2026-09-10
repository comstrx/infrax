#!/usr/bin/env bash

test_config_precedence () {

    local file="" build=""

    file="$(mktemp)"
    build="$(mktemp -d)"

    printf 'STACK=light\nPROJECT=filed\nREGISTRY_KEEP_IMAGES=7\n' > "${file}"

    export BUILD_DIR="${build}"

    assert_eq "$("${INFRAX_BIN}" --config "${file}" ci setting PROJECT)" "filed" "a --config file fills an empty default"
    assert_eq "$("${INFRAX_BIN}" --config "${file}" ci setting REGISTRY_KEEP_IMAGES)" "7" "a --config file beats a built-in default"
    assert_eq "$("${INFRAX_BIN}" --config "${file}" ci setting DEPLOY_PATH)" "deploy" "a built-in default reaches the run"
    assert_eq "$(REGISTRY_KEEP_IMAGES=9 "${INFRAX_BIN}" --config "${file}" ci setting REGISTRY_KEEP_IMAGES)" "9" "the process env beats a --config file"
    assert_eq "$(JSON_ENV='{"REGISTRY_KEEP_IMAGES":"11","FOREIGN_THING":"x"}' "${INFRAX_BIN}" --config "${file}" ci setting REGISTRY_KEEP_IMAGES)" "11" "JSON_ENV beats a --config file"
    assert_eq "$(JSON_ENV='{"FOREIGN_THING":"x"}' "${INFRAX_BIN}" --config "${file}" ci setting FOREIGN_THING)" "" "JSON_ENV cannot smuggle a foreign key"
    assert_eq "$(JSON_ENV='{"SERVICE_API_REPLICAS_MIN":"3"}' "${INFRAX_BIN}" --config "${file}" ci setting SERVICE_API_REPLICAS_MIN)" "3" "JSON_ENV admits a service key"
    assert_eq "$(REGISTRY_KEEP_IMAGES=9 "${INFRAX_BIN}" --config "${file}" -e REGISTRY_KEEP_IMAGES=13 ci setting REGISTRY_KEEP_IMAGES)" "13" "a flag beats everything"

    rm -rf "${file}" "${build}"

}
test_config_last_file_wins () {

    local one="" two="" build=""

    one="$(mktemp)"
    two="$(mktemp)"
    build="$(mktemp -d)"

    printf 'STACK=light\nREGISTRY_KEEP_IMAGES=1\n' > "${one}"
    printf 'REGISTRY_KEEP_IMAGES=2\n' > "${two}"

    export BUILD_DIR="${build}"

    assert_eq "$("${INFRAX_BIN}" --config "${one}" --config "${two}" ci setting REGISTRY_KEEP_IMAGES)" "2" "the last --config file wins"
    assert_eq "$("${INFRAX_BIN}" --config "${two}" --config "${one}" ci setting REGISTRY_KEEP_IMAGES)" "1" "order decides, not name"

    rm -rf "${one}" "${two}" "${build}"

}
test_manifest_files_rank_below_the_run () {

    local root="" file=""

    root="$(fixture_copy)"
    file="$(mktemp)"

    printf 'SERVICE_API_REPLICAS_MIN=5\n' > "${file}"

    assert_eq "$(fixture_run "${root}" 'service_get api REPLICAS_MIN')" "1" "infrax.<stack>.env beats infrax.env and the defaults"
    assert_eq "$(fixture_run "${root}" 'service_get worker REPLICAS_MIN')" "2" "an unset service key falls to the global default"
    assert_eq "$(INFRAX_CONFIG="${file}" fixture_run "${root}" 'service_get api REPLICAS_MIN')" "5" "a --config file beats the manifest"
    assert_eq "$(SERVICE_API_REPLICAS_MIN=4 fixture_run "${root}" 'service_get api REPLICAS_MIN')" "4" "the process env beats the manifest"
    assert_eq "$(fixture_run "${root}" 'service_get worker PORT')" "8080" "a key the service leaves unset comes from its runtime profile"
    assert_eq "$(GO_PORT=9090 fixture_run "${root}" 'service_get worker PORT')" "9090" "a runtime key overrides the profile for every service on it"

    rm -rf "${root}" "${file}"

}
test_a_child_run_rereads_its_own_stack () {

    local root=""

    root="$(fixture_copy)"

    printf 'SERVICE_API_REPLICAS_MIN=6\n' > "${root}/infrax.full.env"

    assert_eq "$(fixture_run "${root}" '"${INFRAX_BIN}" -s full ci setting SERVICE_API_REPLICAS_MIN')" "6" "a child on another stack reads that stack's file, not its parent's"
    assert_eq "$(fixture_run "${root}" '"${INFRAX_BIN}" -s full ci setting CLUSTER_SOURCE')" "managed" "a child derives for its own stack"
    assert_eq "$(fixture_run "${root}" '"${INFRAX_BIN}" -s full ci setting REGISTRY')" "registry.probe.test" "a value the caller gave survives into the child"
    assert_eq "$(fixture_run "${root}" '"${INFRAX_BIN}" ci setting STACK')" "light" "a child without a stack flag keeps its parent's stack"

    rm -rf "${root}"

}
test_stack_presets () {

    local root=""

    root="$(fixture_copy)"

    assert_eq "$(fixture_run "${root}" 'printf "%s %s %s %s" "${CLUSTER_SOURCE}" "${DATA_MODE}" "${STORAGE_MODE}" "${ROLLOUT_SURGE}"')" "ssh cluster object 0" "light: a box, data in cluster, object storage, pods swap"
    assert_eq "$(STACK=standard fixture_run "${root}" 'printf "%s %s %s" "${PROVISIONER}" "${STORAGE_MODE}" "${ROLLOUT_SURGE}"')" " volume 1" "standard: no provisioner, volumes, surge"
    assert_eq "$(STACK=full fixture_run "${root}" 'printf "%s %s %s" "${CLUSTER_SOURCE}" "${DATA_MODE}" "${EDGE_TYPE}"')" "managed managed lb" "full: managed cluster and data behind a load balancer"
    assert_eq "$(STACK=full fixture_run "${root}" 'module_mode postgresql; printf " "; module_mode redis')" "managed cluster" "full manages what the cloud can manage, the rest stays in cluster"

    rm -rf "${root}"

}
test_rollout_strategy_follows_the_stack () {

    local file="" build=""

    file="$(mktemp)"
    build="$(mktemp -d)"

    printf 'STACK=light\n' > "${file}"

    export BUILD_DIR="${build}"

    assert_eq "$("${INFRAX_BIN}" --config "${file}" ci setting ROLLOUT_SURGE)" "0" "light swaps pods — no surge to schedule"
    assert_eq "$("${INFRAX_BIN}" --config "${file}" ci setting ROLLOUT_UNAVAILABLE)" "1" "light lets one pod go during a rollout"
    assert_eq "$("${INFRAX_BIN}" --config "${file}" -s standard ci setting ROLLOUT_SURGE)" "1" "standard surges"
    assert_eq "$("${INFRAX_BIN}" --config "${file}" -s light -e ROLLOUT_SURGE=2 ci setting ROLLOUT_SURGE)" "2" "an explicit value beats the stack"

    rm -rf "${file}" "${build}"

}
test_defaults_are_neutral () {

    local key="" value="" biased="PROJECT SERVICES MODULES BASE_DOMAIN HOST_PREFIX GIT_REPO_URL SSH_HOST AWS_REGION GCP_PROJECT GCP_REGION CLUSTER_NAME K8S_NAMESPACE SSL_EMAIL ALARM_EMAIL REGISTRY ECR_REGISTRY TF_STATE_BUCKET BACKUP_BUCKET BUCKET_SUFFIX CLOUDFLARE_DOMAIN_ID ALERT_CHAT_ID LOAD_TARGET_HOST"

    for key in ${biased}; do

        value="$(infrax_defaults | sed -n "s/^${key}=//p")"

        assert_eq "${value}" "" "${key} carries a project-biased default"

    done

}
# test
manifests_are_disjoint_and_every_key_is_read () {

    local file="" build=""

    file="$(mktemp)"
    build="$(mktemp -d)"

    printf 'STACK=light\n' > "${file}"

    export BUILD_DIR="${build}"

    assert_ok "the examples law holds" "${INFRAX_BIN}" --config "${file}" secrets example

    rm -rf "${file}" "${build}"

}
