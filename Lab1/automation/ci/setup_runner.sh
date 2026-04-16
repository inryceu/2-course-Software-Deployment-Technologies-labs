#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [ "$#" -lt 2 ]; then
    error "Usage: sudo bash setup_runner.sh <GITHUB_OWNER/REPO> <PAT_TOKEN>"
fi

GITHUB_REPO="$1"
PAT_TOKEN="$2"
RUNNER_LABEL="lab3-deployer"
RUNNER_NAME="$(hostname -s)-${RANDOM}"
RUNNER_DIR="/opt/github-actions-runner"
RUNNER_USER="runner"

log "Setting up GitHub Actions self-hosted runner..."
log "Repository: $GITHUB_REPO"
log "Runner name: $RUNNER_NAME"
log "Runner label: $RUNNER_LABEL"
log "Install directory: $RUNNER_DIR"

log "Updating system and installing dependencies..."
apt-get update
apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-pip \
    docker.io

log "Creating runner user..."
if ! id "$RUNNER_USER" &>/dev/null; then
    useradd -m -s /bin/bash -d "/home/$RUNNER_USER" "$RUNNER_USER"
    log "User '$RUNNER_USER' created"
else
    warn "User '$RUNNER_USER' already exists"
fi

log "Adding runner user to docker group..."
usermod -aG docker "$RUNNER_USER"

log "Creating runner directory..."
mkdir -p "$RUNNER_DIR"
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

log "Downloading GitHub Actions runner..."
cd "$RUNNER_DIR"
RUNNER_VERSION=$(curl -s "https://api.github.com/repos/actions/runner/releases/latest" | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

log "Downloading runner v${RUNNER_VERSION}..."
curl -L -o runner.tar.gz "$RUNNER_URL"
tar xzf runner.tar.gz
rm runner.tar.gz

chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

log "Generating registration token from GitHub API..."
REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $PAT_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPO/actions/runners/registration-token" \
    | grep -o '"token":"[^"]*' | cut -d '"' -f 4)

if [ -z "$REGISTRATION_TOKEN" ]; then
    error "Failed to obtain registration token. Check your PAT_TOKEN and repository."
fi

log "Registration token obtained (length: ${#REGISTRATION_TOKEN})"

log "Registering runner..."
cd "$RUNNER_DIR"
sudo -u "$RUNNER_USER" ./config.sh \
    --url "https://github.com/$GITHUB_REPO" \
    --token "$REGISTRATION_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABEL" \
    --runnergroup "Default" \
    --replace \
    --unattended

log "Runner registered successfully"


log "Installing as systemd service..."
cd "$RUNNER_DIR"
sudo ./svc.sh install "$RUNNER_USER"
sudo systemctl daemon-reload

log "Starting runner service..."
sudo systemctl enable "actions.runner.${GITHUB_REPO/\//.}.${RUNNER_NAME}.service"
sudo systemctl start "actions.runner.${GITHUB_REPO/\//.}.${RUNNER_NAME}.service"

log "Waiting for runner to start..."
sleep 3

if sudo systemctl is-active --quiet "actions.runner.${GITHUB_REPO/\//.}.${RUNNER_NAME}.service"; then
    log "✓ Runner service is active and running"
    sudo systemctl status "actions.runner.${GITHUB_REPO/\//.}.${RUNNER_NAME}.service" --no-pager
else
    error "Runner service failed to start. Check logs with: sudo journalctl -u actions.runner.* -n 50"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ RUNNER SETUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Runner details:"
echo "  Name: $RUNNER_NAME"
echo "  Label: $RUNNER_LABEL"
echo "  Directory: $RUNNER_DIR"
echo "  User: $RUNNER_USER"
echo ""
echo "Next steps:"
echo "  1. Go to: https://github.com/$GITHUB_REPO/settings/actions/runners"
echo "  2. Verify the runner appears with label '$RUNNER_LABEL'"
echo "  3. Use 'runs-on: [self-hosted, linux, x64, $RUNNER_LABEL]' in workflows"
echo ""
echo "To view logs: sudo journalctl -u actions.runner.* -f"
echo "To stop runner: sudo systemctl stop actions.runner.*"
echo "To remove runner: sudo $RUNNER_DIR/config.sh remove --token <TOKEN>"
echo ""
