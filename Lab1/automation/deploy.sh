#!/bin/bash

set -o pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO] $(date +'%Y-%m-%d %H:%M:%S') - $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

if [ "$#" -ne 3 ]; then
    error "Недостатньо аргументів!"
    echo -e "${YELLOW}Використання: sudo $0 <db_name> <db_user> <db_password>${NC}"
    echo -e "Приклад: sudo $0 notes_db app app_secure_pass"
    exit 1
fi

DB_NAME=$1
DB_USER=$2
DB_PASS=$3
APP_TARGET="/opt/mywebapp"
SOURCE_DIR="../mywebapp"

EXEC_DIR=$(pwd)

echo -e "${GREEN}=== Розгортання з параметрами: DB=$DB_NAME, USER=$DB_USER ===${NC}"

log "Встановлення залежностей..."
apt-get update && apt-get install -y mariadb-server nginx curl sudo git nodejs
npm install -g pnpm

create_user_safe() {
    if ! id "$1" &>/dev/null; then
        useradd -m -s /bin/bash "$1"
        echo "$1:12345678" | chpasswd
        log "Користувача $1 створено."
    fi
}
create_user_safe "student"
create_user_safe "teacher"
create_user_safe "operator"
id "app" &>/dev/null || useradd -r -s /bin/false app

echo "operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp, /bin/systemctl stop mywebapp, /bin/systemctl restart mywebapp, /bin/systemctl status mywebapp, /usr/sbin/nginx -s reload" > /etc/sudoers.d/operator
chmod 0440 /etc/sudoers.d/operator

log "Налаштування MariaDB..."
systemctl start mariadb
mariadb -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
mariadb -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';"
mariadb -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';"
mariadb -e "FLUSH PRIVILEGES;"

mkdir -p $APP_TARGET
cp -r $SOURCE_DIR/dist $APP_TARGET/
cp $SOURCE_DIR/package.json $APP_TARGET/
cp $SOURCE_DIR/pnpm-lock.yaml $APP_TARGET/
cp -r $SOURCE_DIR/prisma $APP_TARGET/

log "Генерація .env з параметрів CLI..."
echo "DATABASE_URL=\"mysql://${DB_USER}:${DB_PASS}@127.0.0.1:3306/${DB_NAME}\"" > $APP_TARGET/.env

cd $APP_TARGET
log "Встановлення пакетів та Prisma..."
pnpm install --config.ignore-scripts=false
pnpm exec prisma generate
pnpm exec prisma db push --accept-data-loss

chown -R app:app $APP_TARGET

log "Оновлення файлів Systemd..."

[ -f "$EXEC_DIR/../systemd/mywebapp.socket" ] && cp "$EXEC_DIR/../systemd/mywebapp.socket" /etc/systemd/system/
[ -f "$EXEC_DIR/../systemd/mywebapp.service" ] && cp "$EXEC_DIR/../systemd/mywebapp.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now mywebapp.socket

log "Оновлення файлів Nginx..."
if [ -f "$EXEC_DIR/../nginx/mywebapp.conf" ]; then
    rm -f /etc/nginx/sites-available/mywebapp
    rm -f /etc/nginx/sites-enabled/mywebapp
    
    cp "$EXEC_DIR/../nginx/mywebapp.conf" /etc/nginx/sites-available/mywebapp
    ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/mywebapp
    rm -f /etc/nginx/sites-enabled/default
    
    if nginx -t; then
        systemctl restart nginx
        log "Nginx успішно налаштовано та перезапущено."
    else
        error "Помилка конфігурації Nginx! Перевір файл mywebapp.conf."
    fi
else
    warn "Файл Nginx не знайдено за шляхом: $EXEC_DIR/../nginx/mywebapp.conf"
fi

echo -e "${GREEN}=== РОЗГОРТАННЯ ЗАВЕРШЕНО ===${NC}"