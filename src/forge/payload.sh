#!/usr/bin/env bash

## the template payload — deterministic archive, one stamp, verified on both sides

payload_pack () {

    tar -C "${SOURCE_DIR}" --sort=name --owner=0 --group=0 --numeric-owner --mtime='@0' -cf - template | gzip -n > "${1}"

}
payload_sha () {

    sha256sum "${1}" | cut -c1-64

}
payload_of () {

    sed -n '/^#__INFRAX_PAYLOAD__$/,$p' "${1:-${BIN}}" | tail -n +2 | sed 's/^#//' | base64 -d

}
payload_stamp () {

    sed -n 's/^INFRAX_TEMPLATE_SHA="\(.*\)"$/\1/p' "${1:-${BIN}}"

}
