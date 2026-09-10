#!/usr/bin/env bash

test_render_fills_placeholders_and_refuses_missing_ones () {

    local src="" dst=""

    src="$(mktemp)"
    dst="$(mktemp)"

    printf 'name: ${PROBE_NAME}\n' > "${src}"

    PROBE_NAME=probe render "${src}" "${dst}"

    assert_eq "$(cat "${dst}")" "name: probe" "a placeholder renders from the environment"
    assert_fails "an undefined placeholder refuses to render" env -u PROBE_NAME bash -c "source '${INFRAX_BIN}'; render '${src}' '${dst}'"

    rm -f "${src}" "${dst}"

}
test_render_text_streams () {

    assert_eq "$(PROBE_NAME=probe bash -c "source '${INFRAX_BIN}'; printf 'a=\${PROBE_NAME}' | render_text")" "a=probe" "stdin renders to stdout"

}
