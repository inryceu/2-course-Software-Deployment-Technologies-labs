#!/usr/bin/env bash

set -euo pipefail

: "${TARGET_HOST:?TARGET_HOST is required}"
: "${TARGET_USER:?TARGET_USER is required}"
: "${SSH_PRIVATE_KEY:?SSH_PRIVATE_KEY is required}"
: "${APP_IMAGE:?APP_IMAGE is required}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

# Docker image repository path must be lowercase. Keep tag/digest unchanged.
if [[ "$APP_IMAGE" == */* ]]; then
  IMAGE_REGISTRY="${APP_IMAGE%%/*}"
  IMAGE_PATH_AND_REF="${APP_IMAGE#*/}"
  IMAGE_PATH="${IMAGE_PATH_AND_REF%%[:@]*}"
  IMAGE_REF_SUFFIX="${IMAGE_PATH_AND_REF#"$IMAGE_PATH"}"
  APP_IMAGE="${IMAGE_REGISTRY}/$(printf '%s' "$IMAGE_PATH" | tr '[:upper:]' '[:lower:]')${IMAGE_REF_SUFFIX}"
fi

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

# shellcheck disable=SC2029
ssh -i "$KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo -n true"

# shellcheck disable=SC2029
ssh -i "$KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo -n mkdir -p '$TARGET_DIR'"

# shellcheck disable=SC2029
ssh -i "$KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "set -euo pipefail
sudo -n tee '$TARGET_DIR/.env' >/dev/null <<'EOF'
APP_IMAGE=$APP_IMAGE
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOF
sudo -n chmod 600 '$TARGET_DIR/.env'
sudo -n grep -Eq '^APP_IMAGE=.+$' '$TARGET_DIR/.env'"

# shellcheck disable=SC2029
ssh -i "$KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "printf '%s' '${GHCR_TOKEN:-${GITHUB_TOKEN:-}}' | sudo -n docker login ghcr.io -u '${GHCR_USER:-${GITHUB_ACTOR:-github-actions}}' --password-stdin"

# shellcheck disable=SC2029
ssh -i "$KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes "${SSH_STRICT_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "set -euo pipefail
TARGET_DIR='$TARGET_DIR'
MAX_PULL_RETRIES='${MAX_PULL_RETRIES}'

show_diagnostics() {
  echo '----- lab3-notes.service status -----' >&2
  sudo -n systemctl status lab3-notes --no-pager -l || true
  echo '----- lab3-notes journal (last 120 lines) -----' >&2
  sudo -n journalctl -u lab3-notes --no-pager -n 120 || true
  echo '----- docker compose ps -----' >&2
  sudo -n docker compose --env-file \"\$TARGET_DIR/.env\" -f \"\$TARGET_DIR/docker-compose.yml\" ps || true
  echo '----- docker compose logs (last 120 lines) -----' >&2
  sudo -n docker compose --env-file \"\$TARGET_DIR/.env\" -f \"\$TARGET_DIR/docker-compose.yml\" logs --tail 120 || true
}

cd \"\$TARGET_DIR\"
sudo -n docker compose --env-file \"\$TARGET_DIR/.env\" -f \"\$TARGET_DIR/docker-compose.yml\" config > /dev/null

for i in \$(seq 1 \"\$MAX_PULL_RETRIES\"); do
  if sudo -n docker compose --env-file \"\$TARGET_DIR/.env\" -f \"\$TARGET_DIR/docker-compose.yml\" pull; then
    break
  fi
  if [ \"\$i\" -eq \"\$MAX_PULL_RETRIES\" ]; then
    echo \"docker compose pull failed after \$MAX_PULL_RETRIES attempts\" >&2
    show_diagnostics
    exit 1
  fi
  sleep 10
done

sudo -n systemctl daemon-reload
sudo -n systemctl enable lab3-notes
if ! sudo -n systemctl restart lab3-notes; then
  show_diagnostics
  exit 1
fi"
