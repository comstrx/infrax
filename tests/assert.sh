#!/usr/bin/env bash

assert_eq () {

    local actual="${1:-}" expected="${2:-}" message="${3:-}"

    [[ "${actual}" == "${expected}" ]] && return 0

    err "${message:-expected [${expected}], got [${actual}]}"
    return 1

}
assert_ne () {

    local actual="${1:-}" expected="${2:-}" message="${3:-}"

    [[ "${actual}" != "${expected}" ]] && return 0

    err "${message:-expected anything but [${expected}]}"
    return 1

}
assert_contains () {

    local haystack="${1:-}" needle="${2:-}" message="${3:-}"

    [[ "${haystack}" == *"${needle}"* ]] && return 0

    err "${message:-expected to find [${needle}]}"
    return 1

}
assert_lacks () {

    local haystack="${1:-}" needle="${2:-}" message="${3:-}"

    [[ "${haystack}" != *"${needle}"* ]] && return 0

    err "${message:-expected not to find [${needle}]}"
    return 1

}
assert_ok () {

    local message="${1:-}"
    shift

    "$@" >/dev/null 2>&1 && return 0

    err "${message:-expected success: $*}"
    return 1

}
assert_fails () {

    local message="${1:-}"
    shift

    ! "$@" >/dev/null 2>&1 && return 0

    err "${message:-expected failure: $*}"
    return 1

}
## a private copy of the fixture project — a consumer repo with its manifest, safe to write into
fixture_copy () {

    local dir=""

    dir="$(mktemp -d)"

    cp -r "$(dirname "${INFRAX_BIN}")/../../tests/fixture/." "${dir}/"

    printf '%s' "${dir}"

}
## run bash inside the bundle with the fixture as the consumer repo — the secrets a seed needs, never real ones
fixture_run () {

    local root="${1:?fixture_run needs a root}" script="${2:?fixture_run needs a script}"

    REPO_ROOT="${root}" BUILD_DIR="${root}/.infrax" REGISTRY="${REGISTRY:-registry.probe.test}" \
        POSTGRESQL_PASSWORD=probe-postgresql REDIS_PASSWORD=probe-redis PGADMIN4_PASSWORD=probe-pgadmin TOOLS_PASSWORD=probe-tools \
        bash -c "set -Eeuo pipefail; source '${INFRAX_BIN}'; config_load; ${script}"

}
