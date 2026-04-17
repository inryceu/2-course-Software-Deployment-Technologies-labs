#!/usr/bin/env bash

set -euo pipefail

# Prefer explicit verify target when provided, otherwise verify the deployed host.
TARGET_HOST="${VERIFY_HOST:-${TARGET_HOST:-}}"
: "${TARGET_HOST:?TARGET_HOST or VERIFY_HOST is required}"

TARGET_PORT="${VERIFY_PORT:-${TARGET_HTTP_PORT:-80}}"
BASE_URL="http://${TARGET_HOST}:${TARGET_PORT}"
MAX_WAIT_SECONDS="${VERIFY_MAX_WAIT_SECONDS:-120}"
SLEEP_SECONDS=5

request_code() {
  local path="$1"
  curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 2 \
    --max-time 5 \
    "$BASE_URL$path" || echo "000"
}

wait_for_http_200() {
  local path="$1"
  local elapsed=0

  while [ "$elapsed" -lt "$MAX_WAIT_SECONDS" ]; do
    if [ "$(request_code "$path")" = "200" ]; then
      return 0
    fi
    sleep "$SLEEP_SECONDS"
    elapsed=$((elapsed + SLEEP_SECONDS))
  done
  return 1
}

if ! wait_for_http_200 "/notes"; then
  echo "Verification failed: ${BASE_URL}/notes did not return HTTP 200 within ${MAX_WAIT_SECONDS}s" >&2
  echo "Last status for ${BASE_URL}/notes: $(request_code "/notes")" >&2
  echo "Last status for ${BASE_URL}/health/alive: $(request_code "/health/alive")" >&2
  echo "Last status for ${BASE_URL}/health/ready: $(request_code "/health/ready")" >&2
  exit 1
fi

if [ "$(request_code "/health/alive")" != "200" ]; then
  echo "Verification failed: /health/alive is not HTTP 200" >&2
  exit 1
fi

if [ "$(request_code "/health/ready")" != "200" ]; then
  echo "Verification failed: /health/ready is not HTTP 200" >&2
  exit 1
fi

if [ "$(request_code "/this-should-be-forbidden")" != "403" ]; then
  echo "Verification failed: forbidden endpoint check did not return HTTP 403" >&2
  exit 1
fi

echo "Verification successful: service reachable, health endpoints OK, nginx restrictions OK."
