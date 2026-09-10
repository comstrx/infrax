#!/bin/sh
set -eu

export PGPASSWORD="${ROOT_PASSWORD}"

stamp="$(date -u +%Y%m%d-%H%M%S)"

for database in ${DATABASES:-}; do

    mkdir -p "${OUT}/${database}"
    pg_dump -h "${HOST}" -p "${PORT}" -U "${ROOT_USER}" -d "${database}" --no-owner --no-privileges -Fc -f "${OUT}/${database}/${stamp}.dump"
    echo "postgresql: ${database} → ${stamp}.dump ($(wc -c < "${OUT}/${database}/${stamp}.dump") bytes)"

done
