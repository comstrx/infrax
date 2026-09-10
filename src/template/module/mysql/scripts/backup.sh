#!/bin/sh
set -eu

export MYSQL_PWD="${ROOT_PASSWORD}"

stamp="$(date -u +%Y%m%d-%H%M%S)"

for database in ${DATABASES:-}; do

    mkdir -p "${OUT}/${database}"
    mysqldump -h "${HOST}" -P "${PORT}" -u "${ROOT_USER}" --single-transaction --routines --triggers --set-gtid-purged=OFF \
        --result-file="${OUT}/${database}/${stamp}.sql" "${database}"
    echo "mysql: ${database} → ${stamp}.sql ($(wc -c < "${OUT}/${database}/${stamp}.sql") bytes)"

done
