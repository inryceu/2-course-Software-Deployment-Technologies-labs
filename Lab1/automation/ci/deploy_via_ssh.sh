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

# Docker image repository must be lowercase. Keep tag/digest unchanged.
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
  error "SSH_PRIVATE_KEY is invalid, encrypted, or malformed. Store an unencrypted OpenSSH private key in the secret."
fi

if [ -n "$KNOWN_HOSTS_VALUE" ]; then
  printf '%s\n' "$KNOWN_HOSTS_VALUE" > "$KNOWN_HOSTS_FILE"
  SSH_STRICT_OPTS=(-o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS_FILE")
else
  SSH_STRICT_OPTS=(-o StrictHostKeyChecking=no)
fi

SSH_BASE_OPTS=(-i "$KEY_FILE" -p "$SSH_PORT" -o BatchMode=yes -o IdentitiesOnly=yes "${SSH_STRICT_OPTS[@]}")

ssh "${SSH_BASE_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" "sudo -n true" || \
  error "Target user '$TARGET_USER' must have passwordless sudo (NOPASSWD) on $TARGET_HOST"

# shellcheck disable=SC2029
ssh "${SSH_BASE_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo -n mkdir -p '$TARGET_DIR'"

# shellcheck disable=SC2029
ssh "${SSH_BASE_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "cat > /tmp/lab3-env <<'EOF'
APP_IMAGE=$APP_IMAGE
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_PASSWORD=$MYSQL_PASSWORD
EOF
sudo -n mv /tmp/lab3-env '$TARGET_DIR/.env'
sudo -n chmod 600 '$TARGET_DIR/.env'"

# shellcheck disable=SC2029
ssh "${SSH_BASE_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "sudo -n docker login ghcr.io -u '${GHCR_USER:-${GITHUB_ACTOR:-github-actions}}' -p '${GHCR_TOKEN:-${GITHUB_TOKEN:-}}'"

# shellcheck disable=SC2029
ssh "${SSH_BASE_OPTS[@]}" "$TARGET_USER@$TARGET_HOST" \
  "cd '$TARGET_DIR' && sudo -n docker compose pull && sudo -n systemctl daemon-reload && sudo -n systemctl enable lab3-notes && sudo -n systemctl restart lab3-notes"
