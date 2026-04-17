#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

[ -z "${TARGET_HOST:-}" ] && error "TARGET_HOST is required (check GitHub Secrets)"
[ -z "${TARGET_USER:-}" ] && error "TARGET_USER is required (check GitHub Secrets)"
[ -z "${SSH_PRIVATE_KEY:-}" ] && error "SSH_PRIVATE_KEY is required (check GitHub Secrets)"
[ -z "${APP_IMAGE:-}" ] && error "APP_IMAGE is required"
[ -z "${MYSQL_ROOT_PASSWORD:-}" ] && error "MYSQL_ROOT_PASSWORD is required (check GitHub Secrets)"
[ -z "${MYSQL_PASSWORD:-}" ] && error "MYSQL_PASSWORD is required (check GitHub Secrets)"

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
  "cd '$TARGET_DIR' && sudo docker compose pull && sudo systemctl daemon-reload && sudo systemctl enable lab3-notes && sudo systemctl restart lab3-notes"
