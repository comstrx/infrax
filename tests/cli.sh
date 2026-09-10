#!/usr/bin/env bash

test_cli_lists_every_module () {

    local listing="" name=""

    listing="$("${INFRAX_BIN}" -l)"

    for name in app argocd audit aws backup ci dns gcp helm k8s load secrets self server tofu tool; do

        assert_contains "${listing}" "  ${name} — " "module ${name} is listed"

    done

}
test_cli_refuses_the_unknown () {

    assert_fails "an unknown module is refused" "${INFRAX_BIN}" -s light nothing here
    assert_fails "an unknown option is refused" "${INFRAX_BIN}" --nothing
    assert_fails "a missing config file is refused" "${INFRAX_BIN}" --config /nonexistent ci setting STACK

}
test_help_names_a_command () {

    assert_contains "$("${INFRAX_BIN}" help ci setting)" "print one resolved setting" "help reaches a single command"
    assert_contains "$("${INFRAX_BIN}" help server)" "deploy" "help lists a module's commands"
    assert_contains "$("${INFRAX_BIN}" --version)" "${INFRAX_VERSION}" "the version is the one the forge stamped"

}
