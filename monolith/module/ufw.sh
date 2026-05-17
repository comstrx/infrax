#!/usr/bin/env bash
set -Eeuo pipefail

ufw_nginx () {

    sudo ufw allow OpenSSH
    sudo ufw allow 'Nginx Full'

}
ufw_app () {

    sudo ufw allow in on lo to any port 8080
    sudo ufw deny 8080

}
ufw_mysql () {

    sudo ufw allow in on lo to any port 3306
    sudo ufw deny 3306

}
ufw_redis () {

    sudo ufw allow in on lo to any port 6379
    sudo ufw deny 6379

}
restart () {

    echo "y" | sudo ufw enable
    sudo ufw reload
    sudo ufw status || true

}

echo "Configuring Firewall ..."

ufw_nginx
ufw_app
ufw_mysql
ufw_redis
restart

echo "✅ Firewall Configured Successfully."
