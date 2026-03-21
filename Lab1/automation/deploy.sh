#!/bin/bash
set -e

echo "=== Початок розгортання mywebapp ==="

apt-get update
apt-get install -y mariadb-server nginx curl sudo git ufw
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

create_user() {
    local username=$1
    local gecos=$2
    if ! id -u "$username" >/dev/null 2>&1; then
        useradd -m -s /bin/bash -c "$gecos" "$username"
        echo "$username:12345678" | chpasswd
        chage -d 0 "$username"
    fi
}

create_user "student" "Student User"
create_user "teacher" "Teacher User"
create_user "operator" "Operator User"

if ! id -u "app" >/dev/null 2>&1; then
    useradd -r -s /bin/false app
fi

usermod -aG sudo student
usermod -aG sudo teacher

cat << 'EOF' > /etc/sudoers.d/operator
operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp, /bin/systemctl stop mywebapp, /bin/systemctl restart mywebapp, /bin/systemctl status mywebapp, /usr/sbin/nginx -s reload
EOF
chmod 0440 /etc/sudoers.d/operator

usermod -L ubuntu 2>/dev/null || true

echo "14840136" > /home/student/gradebook
chown student:student /home/student/gradebook

systemctl start mariadb
systemctl enable mariadb
mysql -e "CREATE DATABASE IF NOT EXISTS notes_db;"
mysql -e "CREATE USER IF NOT EXISTS 'app'@'127.0.0.1' IDENTIFIED BY 'app_secure_pass';"
mysql -e "GRANT ALL PRIVILEGES ON notes_db.* TO 'app'@'127.0.0.1';"
mysql -e "FLUSH PRIVILEGES;"

mkdir -p /opt/mywebapp
cp -r ../apps/mywebapp/dist /opt/mywebapp/
cp ../apps/mywebapp/package*.json /opt/mywebapp/
cd /opt/mywebapp && npm install --production
chown -R app:app /opt/mywebapp

cp ../systemd/mywebapp.socket /etc/systemd/system/
cp ../systemd/mywebapp.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now mywebapp.socket

cp ../nginx/mywebapp.conf /etc/nginx/sites-available/mywebapp
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "=== Розгортання успішно завершено ==="