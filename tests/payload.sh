#!/usr/bin/env bash

test_payload_extracts_once_and_verifies () {

    local file="" build="" dir="" stamp="" path=""

    file="$(mktemp)"
    build="$(mktemp -d)"

    printf 'STACK=light\n' > "${file}"

    export BUILD_DIR="${build}" INFRAX_DEV_TEMPLATE=""

    dir="$("${INFRAX_BIN}" --config "${file}" ci setting TEMPLATE_DIR)"

    assert_contains "${dir}" "${build}/template/${INFRAX_VERSION}-" "the templates unpack under the build dir, stamped by version"

    for path in helm/service/Chart.yaml helm/data/Chart.yaml helm/tool/Chart.yaml tofu/aws/stacks/light/main.tf tofu/gcp/stacks/full/main.tf \
        runtime/laravel/profile.env runtime/rust/profile.env runtime/go/profile.env runtime/node/profile.env runtime/python/profile.env \
        module/postgresql/module.env module/mysql/module.env module/redis/module.env module/storage/module.env module/pgadmin4/module.env module/phpmyadmin/module.env; do

        assert_ok "${path} is in the payload" test -f "${dir}/${path}"

    done

    assert_eq "$(cat "${dir}/.sha256")" "${INFRAX_TEMPLATE_SHA}" "the extracted payload carries the header stamp"

    stamp="$(stat -c %Y "${dir}/.sha256")"
    sleep 1
    "${INFRAX_BIN}" --config "${file}" ci setting TEMPLATE_DIR >/dev/null

    assert_eq "$(stat -c %Y "${dir}/.sha256")" "${stamp}" "a second run does not unpack again"

    rm -rf "${file}" "${build}"

}
test_payload_refuses_a_tampered_bundle () {

    local file="" build="" copy="" output=""

    file="$(mktemp)"
    build="$(mktemp -d)"
    copy="${build}/tampered.sh"

    printf 'STACK=light\n' > "${file}"

    export BUILD_DIR="${build}" INFRAX_DEV_TEMPLATE=""

    sed '$ s/^#\(.\)/#A/' "${INFRAX_BIN}" > "${copy}"
    chmod +x "${copy}"

    output="$(INFRAX_BIN="${copy}" "${copy}" --config "${file}" ci setting TEMPLATE_DIR 2>&1 || true)"

    assert_contains "${output}" "corrupt" "a bundle whose payload changed refuses to unpack"
    assert_fails "nothing was unpacked" test -d "${build}/template"

    rm -rf "${file}" "${build}"

}
