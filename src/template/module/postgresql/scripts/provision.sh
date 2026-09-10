#!/bin/sh
set -eu

export PGPASSWORD="${ROOT_PASSWORD}"

tries=0

until pg_isready -h "${HOST}" -p "${PORT}" -U "${ROOT_USER}" -q; do

    tries=$((tries + 1))
    [ "${tries}" -lt 90 ] || { echo "postgresql at ${HOST}:${PORT} never accepted a connection"; exit 1; }
    sleep 2

done

psql -h "${HOST}" -p "${PORT}" -U "${ROOT_USER}" -d postgres -v ON_ERROR_STOP=1 -q \
    -v role="${SERVICE_USER}" -v password="${SERVICE_PASSWORD}" -v database="${SERVICE_DATABASE}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role', :'password') WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('ALTER ROLE %I LOGIN PASSWORD %L', :'role', :'password') \gexec
SELECT format('GRANT %I TO %I', :'role', current_user) WHERE NOT pg_has_role(current_user, :'role', 'MEMBER') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'database', :'role') WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'database') \gexec
SELECT format('REVOKE ALL ON DATABASE %I FROM PUBLIC', :'database') \gexec
SQL

for extension in ${EXTENSIONS:-}; do

    psql -h "${HOST}" -p "${PORT}" -U "${ROOT_USER}" -d "${SERVICE_DATABASE}" -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS \"${extension}\""

done

echo "postgresql: ${SERVICE_USER} owns ${SERVICE_DATABASE}"
