#!/usr/bin/env bash

test_cve_gate_counts_what_is_not_accepted () {

    local bin="" gate=""

    bin="$(mktemp -d)"

    cat > "${bin}/trivy" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '{"Results":[{"Target":"app","Vulnerabilities":[{"VulnerabilityID":"CVE-1","PkgName":"a","InstalledVersion":"1","FixedVersion":"2"},{"VulnerabilityID":"GHSA-x","PkgName":"b","InstalledVersion":"1","FixedVersion":"3"}]}]}'
SH
    chmod +x "${bin}/trivy"

    gate="source '${INFRAX_BIN}'; ci_trivy probe:tag"

    assert_eq "$(PATH="${bin}:${PATH}" bash -c "${gate} 2>/dev/null")" "2" "every fixable CRITICAL counts"
    assert_eq "$(PATH="${bin}:${PATH}" CVE_IGNORE='GHSA-x' bash -c "${gate} 2>/dev/null")" "1" "a reviewed finding named in CVE_IGNORE is accepted"
    assert_eq "$(PATH="${bin}:${PATH}" CVE_IGNORE='GHSA-x, CVE-1' bash -c "${gate} 2>/dev/null")" "0" "commas and spaces both separate the names"
    assert_eq "$(PATH="${bin}:${PATH}" CVE_IGNORE='CVE-10' bash -c "${gate} 2>/dev/null")" "2" "a name accepts only itself, never a prefix of another"
    assert_contains "$(PATH="${bin}:${PATH}" CVE_IGNORE='GHSA-x' bash -c "${gate} 2>&1 >/dev/null")" "GHSA-x  b 1 → 3  (app)  — accepted by CVE_IGNORE" "the log says what was accepted and why"

    rm -rf "${bin}"

}
