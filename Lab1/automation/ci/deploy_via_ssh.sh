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
MAX_PULL_RETRIES="${MAX_PULL_RETRIES:-18}"

KEY_FILE="$(mktemp)"
KNOWN_HOSTS_FILE="$(mktemp)"
cleanup() {
  rm -f "$KEY_FILE" "$KNOWN_HOSTS_FILE"
}
trap cleanup EXIT

# Normalize SSH key from GitHub Secrets:
# - supports raw multiline key
# - supports literal "\n" escaped format
# - supports base64-encoded key
KEY_VALUE="${SSH_PRIVATE_KEY//$'\r'/}"
if [[ "$KEY_VALUE" == *"\\n"* ]]; then
  KEY_VALUE="$(printf '%s' "$KEY_VALUE" | sed 's/\\n/\n/g')"
fi

if [[ "$KEY_VALUE" != *"-----BEGIN"* ]]; then
  if DECODED_KEY="$(printf '%s' "$KEY_VALUE" | base64 -d 2>/dev/null)"; then
    KEY_VALUE="$DECODED_KEY"
  fi
fi

printf '%s\n' "$KEY_VALUE" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

if ! ssh-keygen -y -f "$KEY_FILE" > /dev/null 2>&1; then
  echo "SSH_PRIVATE_KEY is invalid, encrypted, or malformed. Store an unencrypted OpenSSH private key in the secret." >&2
  exit 1
fi

if [ -n "$KNOWN_HOSTS_VALUE" ]; then
  printf '%s\n' "$KNOWN_HOSTS_VALUE" > "$KNOWN_HOSTS_FILE"
  SSH_STRICT_OPTS=(-o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS_FILE")
else
  SSH_STRICT_OPTS=(-o StrictHostKeyChecking=no)
fi

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo -n mkdir -p '$TARGET_DIR'"

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "cat > /tmp/lab3-env <<'EOF'
APP_IMAGE=$APP_IMAGE
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOF
sudo -n mv /tmp/lab3-env '$TARGET_DIR/.env'
sudo -n chmod 600 '$TARGET_DIR/.env'"

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo -n docker login ghcr.io -u '${GHCR_USER:-${GITHUB_ACTOR:-github-actions}}' -p '${GHCR_TOKEN:-${GITHUB_TOKEN:-}}'"

ssh -i "$KEY_FILE" -p "$SSH_PORT" "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "cd '$TARGET_DIR' && \
   for i in \$(seq 1 ${MAX_PULL_RETRIES}); do \
     if sudo -n docker compose pull; then \
       break; \
     fi; \
     if [ \"\$i\" -eq ${MAX_PULL_RETRIES} ]; then \
       exit 1; \
     fi; \
     sleep 10; \
   done && \
   sudo -n systemctl daemon-reload && \
   sudo -n systemctl enable lab3-notes && \
   sudo -n systemctl restart lab3-notes"
