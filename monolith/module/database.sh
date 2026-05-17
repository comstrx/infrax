#!/usr/bin/env bash
set -Eeuo pipefail

DB_NAME="${DB_NAME:-}"
DB_USER="${DB_USER:-user}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_ROOT_USER="${DB_ROOT_USER:-root}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
DB_PMA_USER="${DB_PMA_USER:-phpmyadmin}"
DB_PMA_PASSWORD="${DB_PMA_PASSWORD:-}"

UPLOAD_MAX_FILESIZE="${UPLOAD_MAX_FILESIZE:-256M}"
POST_MAX_SIZE="${POST_MAX_SIZE:-256M}"
MEMORY_LIMIT="${MEMORY_LIMIT:-512M}"
INPUT_TIMEOUT="${INPUT_TIMEOUT:-300}"

PHP_VERSION="${PHP_VERSION:-8.3}"
PHP_FPM_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
PHP_CLI_INI="/etc/php/${PHP_VERSION}/cli/php.ini"

ROOT_SQL=""
APP_SQL=""
PMA_SQL=""
MYSQL_SQL=""
MYSQL=()

sql_escape () {

    printf '%s' "${1:-}" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g"

}
sql_ident_escape () {

    printf '%s' "${1:-}" | sed "s/\`/\`\`/g"

}
sed_escape () {

    printf '%s' "${1:-}" | sed 's/[&|\\]/\\&/g'

}
set_ini () {

    local file="${1:-}" key="${2:-}" value="${3:-}"

    [[ -f "${file}" ]] || return 0

    if grep -qE "^[[:space:]]*;?[[:space:]]*${key}[[:space:]]*=" "${file}"; then

        sudo sed -i "s|^[[:space:]]*;*[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "${file}"

    else

        printf '%s = %s\n' "${key}" "${value}" | sudo tee -a "${file}" >/dev/null

    fi

}
password_mode () {

    [[ -n "${DB_ROOT_PASSWORD}" ]] || return 1

    MYSQL=( env "MYSQL_PWD=${DB_ROOT_PASSWORD}" mysql -u "${DB_ROOT_USER}" )

}
mysql_connection () {

    if sudo mysql -e "SELECT 1" >/dev/null 2>&1; then MYSQL=( sudo mysql )
    elif [[ -n "${DB_ROOT_PASSWORD}" ]]; then password_mode
    fi

    (( ${#MYSQL[@]} > 0 )) || { echo "❌ Cannot access MySQL"; exit 1; }

}
sql_users () {

    echo "Configuring MySQL ..."

    mysql_connection

    if [[ -n "${DB_ROOT_PASSWORD}" ]]; then

        DB_ROOT_USER_SQL="$(sql_escape "${DB_ROOT_USER}")"
        DB_ROOT_PASSWORD_SQL="$(sql_escape "${DB_ROOT_PASSWORD}")"

        read -r -d '' ROOT_SQL <<-SQL || true
		ALTER USER '${DB_ROOT_USER_SQL}'@'localhost'
		    IDENTIFIED WITH mysql_native_password BY '${DB_ROOT_PASSWORD_SQL}';
		SQL

    fi
    if [[ -n "${DB_NAME}" ]]; then

        DB_NAME_SQL="$(sql_ident_escape "${DB_NAME}")"
        DB_USER_SQL="$(sql_escape "${DB_USER}")"
        DB_PASSWORD_SQL="$(sql_escape "${DB_PASSWORD}")"

        read -r -d '' APP_SQL <<-SQL || true
		CREATE DATABASE IF NOT EXISTS \`${DB_NAME_SQL}\`
		    CHARACTER SET utf8mb4
		    COLLATE utf8mb4_unicode_ci;

		CREATE USER IF NOT EXISTS '${DB_USER_SQL}'@'localhost'
		    IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD_SQL}';

		ALTER USER '${DB_USER_SQL}'@'localhost'
		    IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD_SQL}';

		GRANT ALL PRIVILEGES ON \`${DB_NAME_SQL}\`.* TO '${DB_USER_SQL}'@'localhost';
		SQL

    fi
    if [[ -n "${DB_PMA_PASSWORD}" ]]; then

        DB_PMA_USER_SQL="$(sql_escape "${DB_PMA_USER}")"
        DB_PMA_PASSWORD_SQL="$(sql_escape "${DB_PMA_PASSWORD}")"
        DB_PMA_USER_SED="$(sed_escape "${DB_PMA_USER}")"
        DB_PMA_PASSWORD_SED="$(sed_escape "${DB_PMA_PASSWORD}")"

        read -r -d '' PMA_SQL <<-SQL || true
		CREATE USER IF NOT EXISTS '${DB_PMA_USER_SQL}'@'localhost'
		    IDENTIFIED WITH mysql_native_password BY '${DB_PMA_PASSWORD_SQL}';

		ALTER USER '${DB_PMA_USER_SQL}'@'localhost'
		    IDENTIFIED WITH mysql_native_password BY '${DB_PMA_PASSWORD_SQL}';

		GRANT SELECT, INSERT, UPDATE, DELETE ON \`phpmyadmin\`.* TO '${DB_PMA_USER_SQL}'@'localhost';
		SQL

    fi

    read -r -d '' MYSQL_SQL <<-SQL || true
	${ROOT_SQL}

	${APP_SQL}

	CREATE DATABASE IF NOT EXISTS \`phpmyadmin\`
	    CHARACTER SET utf8mb4
	    COLLATE utf8mb4_unicode_ci;

	${PMA_SQL}

	FLUSH PRIVILEGES;
	SQL

    "${MYSQL[@]}" <<< "${MYSQL_SQL}"

    if [[ -n "${DB_ROOT_PASSWORD}" ]]; then

        password_mode

    fi
    if [[ -f /usr/share/phpmyadmin/sql/create_tables.sql ]]; then

        "${MYSQL[@]}" phpmyadmin < /usr/share/phpmyadmin/sql/create_tables.sql \
            || echo "⚠️ Failed to import phpMyAdmin tables"

    fi

}
pma_login () {

    echo "Configuring PhpMyAdmin Login ..."

    if [[ -n "${DB_PMA_PASSWORD}" && -f /etc/phpmyadmin/config-db.php ]]; then

        sudo sed -i \
            -e "s|^\$dbuser=.*|\$dbuser='${DB_PMA_USER_SED}';|" \
            -e "s|^\$dbpass=.*|\$dbpass='${DB_PMA_PASSWORD_SED}';|" \
            -e "s|^\$basepath=.*|\$basepath='';|" \
            -e "s|^\$dbname=.*|\$dbname='phpmyadmin';|" \
            -e "s|^\$dbserver=.*|\$dbserver='localhost';|" \
            -e "s|^\$dbport=.*|\$dbport='3306';|" \
            -e "s|^\$dbtype=.*|\$dbtype='mysql';|" \
            /etc/phpmyadmin/config-db.php

    fi
    if [[ -n "${DB_PMA_PASSWORD}" && -f /etc/dbconfig-common/phpmyadmin.conf ]]; then

        sudo sed -i \
            -e "s|^dbc_dbuser=.*|dbc_dbuser='${DB_PMA_USER_SED}'|" \
            -e "s|^dbc_dbpass=.*|dbc_dbpass='${DB_PMA_PASSWORD_SED}'|" \
            -e "s|^dbc_dbname=.*|dbc_dbname='phpmyadmin'|" \
            -e "s|^dbc_dbserver=.*|dbc_dbserver='localhost'|" \
            -e "s|^dbc_dbport=.*|dbc_dbport='3306'|" \
            /etc/dbconfig-common/phpmyadmin.conf || true

    fi

}
php_limits () {

    echo "Configuring PHP Limits ..."

    for ini in "${PHP_FPM_INI}" "${PHP_CLI_INI}"; do

        set_ini "${ini}" "upload_max_filesize" "${UPLOAD_MAX_FILESIZE}"
        set_ini "${ini}" "post_max_size" "${POST_MAX_SIZE}"
        set_ini "${ini}" "memory_limit" "${MEMORY_LIMIT}"
        set_ini "${ini}" "max_execution_time" "${INPUT_TIMEOUT}"
        set_ini "${ini}" "max_input_time" "${INPUT_TIMEOUT}"

    done

}
restart () {

    sudo systemctl restart mysql || sudo systemctl restart mariadb || { echo "❌ Failed to restart mysql/mariadb"; exit 1; }

    sudo systemctl restart "php${PHP_VERSION}-fpm" || { echo "❌ Failed to restart php${PHP_VERSION}-fpm"; exit 1; }

}

sql_users
pma_login
php_limits
restart

echo "✅ Database Configured Successfully."
