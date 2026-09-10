#!/usr/bin/env bash

test_aws_registry_derives_from_the_account () {

    local root="" bin=""

    root="$(fixture_copy)"
    bin="$(mktemp -d)"

    printf '#!/usr/bin/env bash\necho 123456789012\n' > "${bin}/aws"
    chmod +x "${bin}/aws"

    assert_eq "$(PATH="${bin}:${PATH}" fixture_run "${root}" 'unset REGISTRY; ci_registry')" "123456789012.dkr.ecr.eu-north-1.amazonaws.com" "the registry is the account's own, before any stack is applied"

    printf '#!/usr/bin/env bash\nexit 1\n' > "${bin}/aws"

    assert_eq "$(PATH="${bin}:${PATH}" fixture_run "${root}" 'unset REGISTRY; ci_registry')" "123456789012.dkr.ecr.eu-north-1.amazonaws.com" "the account is asked once and remembered"
    assert_eq "$(PATH="${bin}:${PATH}" ECR_REGISTRY=pinned.example fixture_run "${root}" 'unset REGISTRY; ci_registry')" "pinned.example" "a pinned registry wins"

    rm -rf "${root}/.infrax/aws"

    assert_fails "no credentials, no registry — the release refuses" env PATH="${bin}:${PATH}" bash -c "$(declare -f fixture_run); fixture_run '${root}' 'unset REGISTRY; ci_registry'"

    rm -rf "${root}" "${bin}"

}
test_gcp_registry_is_the_project_artifact_registry () {

    local root=""

    root="$(fixture_copy)"

    assert_eq "$(CLOUD=gcp GCP_PROJECT=probe-project GCP_REGION=europe-north1 fixture_run "${root}" 'unset REGISTRY; ci_registry')" "europe-north1-docker.pkg.dev/probe-project" "gcp hosts the images in the project's artifact registry"

    rm -rf "${root}"

}
