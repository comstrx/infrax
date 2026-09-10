#!/bin/sh
set -eu

export MYSQL_PWD="${ROOT_PASSWORD}"

[ "${TARGET}" != "${SOURCE}" ] || { echo "refusing to restore over '${SOURCE}' — promotion is a deliberate act"; exit 1; }
[ -s "${FILE}" ] || { echo "backup '${STAMP}' of '${SOURCE}' not found"; exit 1; }

mysql -h "${HOST}" -P "${PORT}" -u "${ROOT_USER}" -e "CREATE DATABASE IF NOT EXISTS \`${TARGET}\`"
mysql -h "${HOST}" -P "${PORT}" -u "${ROOT_USER}" "${TARGET}" < "${FILE}"

echo "mysql: ${SOURCE} ${STAMP} restored into ${TARGET} — verify it, then promote deliberately"
