#!/usr/bin/env bash

set -euo pipefail

: "${TARGET_HOST:?TARGET_HOST is required}"
: "${TARGET_USER:?TARGET_USER is required}"
: "${SSH_PRIVATE_KEY:?SSH_PRIVATE_KEY is required}"
: "${APP_IMAGE:?APP_IMAGE is required}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

SSH_PORT="${TARGET_PORT:-22}"
TARGET_DIR="${TARGET_DIR:-/opt/lab3-notes}"
KNOWN_HOSTS_VALUE="${SSH_KNOWN_HOSTS:-}"

KEY_FILE="$(mktemp)"
KNOWN_HOSTS_FILE="$(mktemp)"
cleanup() {
  rm -f "$KEY_FILE" "$KNOWN_HOSTS_FILE"
}
trap cleanup EXIT

printf '%s\n' "$SSH_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

if [ -n "$KNOWN_HOSTS_VALUE" ]; then
  printf '%s\n' "$KNOWN_HOSTS_VALUE" > "$KNOWN_HOSTS_FILE"
  SSH_STRICT_OPTS=(-o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS_FILE")
else
  SSH_STRICT_OPTS=(-o StrictHostKeyChecking=no)
fi

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo mkdir -p '$TARGET_DIR'"

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "cat > /tmp/lab3-env <<'EOF'
APP_IMAGE=$APP_IMAGE
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOF
sudo mv /tmp/lab3-env '$TARGET_DIR/.env'
sudo chmod 600 '$TARGET_DIR/.env'"

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo docker login ghcr.io -u '${GHCR_USER:-${GITHUB_ACTOR:-github-actions}}' -p '${GHCR_TOKEN:-${GITHUB_TOKEN:-}}'"

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "cd '$TARGET_DIR' && \
   for i in \$(seq 1 18); do \
     if sudo docker compose pull; then \
       break; \
     fi; \
     if [ \"\$i\" -eq 18 ]; then \
       exit 1; \
     fi; \
     sleep 10; \
   done && \
   sudo systemctl daemon-reload && \
   sudo systemctl enable lab3-notes && \
   sudo systemctl restart lab3-notes"
