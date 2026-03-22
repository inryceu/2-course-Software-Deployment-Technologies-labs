#!/bin/bash

set -o pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO] $(date +'%Y-%m-%d %H:%M:%S') - $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }

check_status() {
    if [ $? -ne 0 ]; then
        error "$1"
        exit 1
    fi
}

if [ "$#" -ne 3 ]; then
    error "Недостатньо аргументів!"
    echo -e "${YELLOW}Використання: sudo $0 <db_name> <db_user> <db_password>${NC}"
    exit 1
fi

DB_NAME=$1
DB_USER=$2
DB_PASS=$3
EXEC_DIR=$(pwd) 

echo -e "${GREEN}=== Початок розгортання mywebapp (Debian 13 + pnpm + Prisma) ===${NC}"

log "Встановлення системних пакетів..."
apt-get update && apt-get install -y npm mariadb-server nginx curl sudo git ufw
check_status "Не вдалося встановити системні пакети."

if ! command -v node &> /dev/null; then
    log "Встановлення Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

log "Встановлення pnpm глобально..."
npm install -g pnpm
check_status "Не вдалося встановити pnpm."

PNPM_BIN="$(npm config get prefix)/bin/pnpm"
log "Використовуємо pnpm за абсолютним шляхом: $PNPM_BIN"

create_user_safe() {
    if ! id "$1" &>/dev/null; then
        log "Створення користувача $1..."
        PASS_HASH=$(openssl passwd -6 "12345678")
        useradd -m -s /bin/bash -c "$2" -p "$PASS_HASH" "$1"
        chage -d 0 "$1"
    else
        warn "Користувач $1 вже існує."
    fi
}

create_user_safe "student" "Student User"
create_user_safe "teacher" "Teacher User"
create_user_safe "operator" "Operator User"

if ! id "app" &>/dev/null; then
    useradd -r -s /bin/false app
fi

echo "operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp, /bin/systemctl stop mywebapp, /bin/systemctl restart mywebapp, /bin/systemctl status mywebapp, /usr/sbin/nginx -s reload" > /etc/sudoers.d/operator
chmod 0440 /etc/sudoers.d/operator

log "Налаштування бази даних..."
systemctl start mariadb || systemctl start mysql
systemctl enable mariadb || systemctl enable mysql

mariadb -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mariadb -e "CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';"
mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'127.0.0.1';"
mariadb -e "FLUSH PRIVILEGES;"

APP_TARGET="/opt/mywebapp"
SOURCE_DIR="../mywebapp"

log "Підготовка директорії $APP_TARGET..."
mkdir -p $APP_TARGET

log "Встановлення залежностей через pnpm..."
$PNPM_BIN install --config.ignore-scripts=false
check_status "Помилка встановлення залежностей."

log "Генерація Prisma Client та міграція БД..."
$PNPM_BIN exec prisma generate
check_status "Не вдалося згенерувати Prisma Client."

$PNPM_BIN exec prisma db push --accept-data-loss
check_status "Не вдалося синхронізувати схему БД."

if [ ! -d "$EXEC_DIR/$SOURCE_DIR/dist" ]; then
    warn "Папка dist відсутня. Починаю збірку..."
    cd "$EXEC_DIR/$SOURCE_DIR"
    $PNPM_BIN install --config.ignore-scripts=false
    $PNPM_BIN run build
    cd "$EXEC_DIR"
fi

log "Копіювання файлів..."
cp -r "$EXEC_DIR/$SOURCE_DIR/dist" $APP_TARGET/
cp "$EXEC_DIR/$SOURCE_DIR/package.json" $APP_TARGET/
cp "$EXEC_DIR/$SOURCE_DIR/pnpm-lock.yaml" $APP_TARGET/
cp -r "$EXEC_DIR/$SOURCE_DIR/prisma" $APP_TARGET/

log "Налаштування .env для Prisma..."
echo "DATABASE_URL=\"mysql://$DB_USER:$DB_PASS@127.0.0.1:3306/$DB_NAME\"" > $APP_TARGET/.env

cd $APP_TARGET

chown -R app:app $APP_TARGET

log "Активація системних служб..."
if [ -d "$EXEC_DIR/../systemd" ]; then
    cp "$EXEC_DIR/../systemd/mywebapp.socket" /etc/systemd/system/
    cp "$EXEC_DIR/../systemd/mywebapp.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now mywebapp.socket
fi

if [ -f "$EXEC_DIR/../nginx/mywebapp.conf" ]; then
    rm -f /etc/nginx/sites-available/mywebapp
    rm -f /etc/nginx/sites-enabled/mywebapp
    cp "$EXEC_DIR/../nginx/mywebapp.conf" /etc/nginx/sites-available/mywebapp
    ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    if /usr/sbin/nginx -t; then
        systemctl restart nginx
    fi
fi

echo "14840136" > /home/student/gradebook
chown student:student /home/student/gradebook

echo -e "${GREEN}=== РОЗГОРТАННЯ ЗАВЕРШЕНО УСПІШНО! ===${NC}"