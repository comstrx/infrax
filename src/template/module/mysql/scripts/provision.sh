#!/bin/sh
set -eu

export MYSQL_PWD="${ROOT_PASSWORD}"

tries=0

until mysqladmin ping -h "${HOST}" -P "${PORT}" -u "${ROOT_USER}" --silent; do

    tries=$((tries + 1))
    [ "${tries}" -lt 90 ] || { echo "mysql at ${HOST}:${PORT} never accepted a connection"; exit 1; }
    sleep 2

done

mysql -h "${HOST}" -P "${PORT}" -u "${ROOT_USER}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${SERVICE_DATABASE}\`;
CREATE USER IF NOT EXISTS '${SERVICE_USER}'@'%' IDENTIFIED BY '${SERVICE_PASSWORD}';
ALTER USER '${SERVICE_USER}'@'%' IDENTIFIED BY '${SERVICE_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${SERVICE_DATABASE}\`.* TO '${SERVICE_USER}'@'%';
FLUSH PRIVILEGES;
SQL

echo "mysql: ${SERVICE_USER} owns ${SERVICE_DATABASE}"
