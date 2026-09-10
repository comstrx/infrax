#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail
shopt -s inherit_errexit

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export ROOT_DIR

for file in "${ROOT_DIR}/src/core/log.sh" "${ROOT_DIR}/src/core/fs.sh" "${ROOT_DIR}/src/core/sys.sh" "${ROOT_DIR}/src/module/tool.sh" "${ROOT_DIR}"/src/forge/*.sh; do

    . "${file}"

done

forge_main "$@"
