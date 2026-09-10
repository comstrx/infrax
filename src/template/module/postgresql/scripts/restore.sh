#!/bin/sh
set -eu

export PGPASSWORD="${ROOT_PASSWORD}"

[ "${TARGET}" != "${SOURCE}" ] || { echo "refusing to restore over '${SOURCE}' — promotion is a deliberate act"; exit 1; }
[ -s "${FILE}" ] || { echo "backup '${STAMP}' of '${SOURCE}' not found"; exit 1; }

psql -h "${HOST}" -p "${PORT}" -U "${ROOT_USER}" -d postgres -v ON_ERROR_STOP=1 -q -v database="${TARGET}" <<'SQL'
SELECT format('CREATE DATABASE %I', :'database') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'database') \gexec
SQL

pg_restore --clean --if-exists --single-transaction --exit-on-error --no-owner --no-privileges \
    -h "${HOST}" -p "${PORT}" -U "${ROOT_USER}" -d "${TARGET}" "${FILE}"

echo "postgresql: ${SOURCE} ${STAMP} restored into ${TARGET} — verify it, then promote deliberately"
