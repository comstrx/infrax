#!/usr/bin/env bash

## self-provisioning — every verb installs its own missing tools

tool_arch () {

    local arch=""

    arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"

    case "${arch}" in
        x86_64  ) arch=amd64 ;;
        aarch64 ) arch=arm64 ;;
    esac

    printf '%s' "${arch}"

}
tool_curl () {

    pkg_install curl

}
tool_envsubst () {

    pkg_install gettext-base

}
tool_flock () {

    pkg_install util-linux

}
tool_htpasswd () {

    pkg_install apache2-utils

}
tool_gpg () {

    pkg_install gnupg

}
tool_bin () {

    local file="${1:?Missing binary}" name="${2:?Missing name}" dir=""

    if [[ "$(id -u)" == "0" ]] || sudo -n true 2>/dev/null; then

        as_root install -o root -g root -m 0755 "${file}" "${TOOL_BIN_DIR}/${name}"

    else

        dir="$(path_expand "${INFRAX_INSTALL_DIR}")"

        ensure_dir "${dir}"
        install -m 0755 "${file}" "${dir}/${name}"

    fi

}
tool_kubeconform () {

    local dir=""

    ensure curl tar
    tool_certs

    dir="$(tmp_dir)"

    curl -fsSL "${KUBECONFORM_RELEASES}/${KUBECONFORM_VERSION}/kubeconform-linux-$(tool_arch).tar.gz" \
        | tar xz -C "${dir}" kubeconform || die "Cannot download kubeconform ${KUBECONFORM_VERSION}"

    tool_bin "${dir}/kubeconform" kubeconform

    rm -rf "${dir}"

}
tool_actionlint () {

    local dir=""

    ensure curl tar
    tool_certs

    dir="$(tmp_dir)"

    curl -fsSL "${ACTIONLINT_RELEASES}/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_$(tool_arch).tar.gz" \
        | tar xz -C "${dir}" actionlint || die "Cannot download actionlint ${ACTIONLINT_VERSION}"

    tool_bin "${dir}/actionlint" actionlint

    rm -rf "${dir}"

}
tool_gitleaks () {

    local dir="" arch=""

    ensure curl tar
    tool_certs

    dir="$(tmp_dir)"
    arch="$(tool_arch)"

    [[ "${arch}" != "amd64" ]] || arch=x64

    curl -fsSL "${GITLEAKS_RELEASES}/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${arch}.tar.gz" \
        | tar xz -C "${dir}" gitleaks || die "Cannot download gitleaks ${GITLEAKS_VERSION}"

    tool_bin "${dir}/gitleaks" gitleaks

    rm -rf "${dir}"

}
tool_trivy () {

    local dir="" arch=""

    ensure curl tar
    tool_certs

    dir="$(tmp_dir)"
    arch="$(tool_arch)"

    [[ "${arch}" != "amd64" ]] || arch=64bit
    [[ "${arch}" != "arm64" ]] || arch=ARM64

    curl -fsSL "${TRIVY_RELEASES}/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${arch}.tar.gz" \
        | tar xz -C "${dir}" trivy || die "Cannot download trivy ${TRIVY_VERSION}"

    tool_bin "${dir}/trivy" trivy

    rm -rf "${dir}"

}
tool_certs () {

    [[ -f "${CA_BUNDLE}" ]] || pkg_install ca-certificates

}
tool_docker () {

    local os="" codename="" conflict=""

    ensure curl
    tool_certs

    os="$(. /etc/os-release && printf '%s' "${ID}")"
    codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}")"

    case "${os}" in
        ubuntu | debian | raspbian ) ;;
        * ) os="$(. /etc/os-release && printf '%s' "${ID_LIKE%% *}")" ;;
    esac

    [[ -n "${os}" && -n "${codename}" ]] || die "Cannot resolve the distro for the docker repo"

    for conflict in docker.io docker-doc docker-compose podman-docker containerd runc; do

        as_root apt-get remove -y "${conflict}" >/dev/null 2>&1 || true

    done

    as_root install -m 0755 -d ${APT_KEYRINGS}

    curl -fsSL "${DOCKER_APT_URL}/${os}/gpg" | as_root tee ${APT_KEYRINGS}/docker.asc >/dev/null || die "Cannot fetch the docker signing key"
    as_root chmod a+r ${APT_KEYRINGS}/docker.asc

    printf 'deb [arch=%s signed-by=${APT_KEYRINGS}/docker.asc] %s/%s %s stable\n' \
        "$(tool_arch)" "${DOCKER_APT_URL}" "${os}" "${codename}" | as_root tee ${APT_SOURCES}/docker.list >/dev/null

    pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    ! has systemctl || as_root systemctl enable --now docker

}
tool_gcloud () {

    ensure curl gpg
    tool_certs

    as_root install -m 0755 -d ${APT_KEYRINGS}

    curl -fsSL "${GCLOUD_KEY_URL}" | as_root gpg --dearmor --yes -o ${APT_KEYRINGS}/cloud.google.gpg || die "Cannot fetch the gcloud signing key"

    printf 'deb [signed-by=${APT_KEYRINGS}/cloud.google.gpg] %s cloud-sdk main\n' "${GCLOUD_APT_URL}" \
        | as_root tee ${APT_SOURCES}/google-cloud-sdk.list >/dev/null

    pkg_install google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin

}
tool_kubectl () {

    local version="" arch="" dir=""

    ensure curl
    tool_certs

    version="$(curl -fsSL "${K8S_RELEASE_URL}/stable${K8S_VERSION:+-${K8S_VERSION}}.txt")" || die "Cannot resolve kubectl version"
    arch="$(tool_arch)"
    dir="$(tmp_dir)"

    curl -fsSLo "${dir}/kubectl" "${K8S_RELEASE_URL}/${version}/bin/linux/${arch}/kubectl"
    curl -fsSLo "${dir}/kubectl.sha256" "${K8S_RELEASE_URL}/${version}/bin/linux/${arch}/kubectl.sha256"

    ( cd "${dir}" && printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum --check --quiet ) || die "kubectl checksum mismatch"

    tool_bin "${dir}/kubectl" kubectl

    rm -rf "${dir}"

}
tool_helm () {

    ensure curl openssl tar
    tool_certs

    curl -fsSL "${HELM_INSTALLER_URL}" | as_root env DESIRED_VERSION="${HELM_VERSION}" bash

}
tool_tofu () {

    ensure curl gpg
    tool_certs

    curl -fsSL "${TOFU_INSTALLER_URL}" | as_root sh -s -- --install-method deb --opentofu-version "${TOFU_VERSION}"

}
tool_aws () {

    local dir="" arch=""

    ensure curl unzip
    tool_certs

    dir="$(tmp_dir)"
    arch="$(tool_arch)"

    if [[ "${arch}" == "arm64" ]]; then arch=aarch64; else arch=x86_64; fi

    curl -fsSLo "${dir}/aws.zip" "${AWSCLI_URL}/awscli-exe-linux-${arch}.zip"
    unzip -q "${dir}/aws.zip" -d "${dir}"

    as_root "${dir}/aws/install" --update

    rm -rf "${dir}"

}
## install any listed tool if missing (docker, kubectl, helm, tofu, aws, gcloud, trivy, ...)
tool_ensure () {

    ensure "$@"

}
