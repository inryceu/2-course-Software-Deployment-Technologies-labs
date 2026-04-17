#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

log "Setting up target VM for Lab3 deployments..."

log "Installing Docker..."
apt-get update
apt-get install -y docker.io docker-compose-plugin

log "Enabling Docker service..."
systemctl enable docker
systemctl start docker

docker --version || error "Docker installation failed"
docker compose version || error "Docker Compose installation failed"

log "Creating deployment directory..."
mkdir -p /opt/lab3-notes
chmod 755 /opt/lab3-notes

log "Creating docker-compose.yml template..."
tee /opt/lab3-notes/docker-compose.yml > /dev/null <<'COMPOSE_EOF'
services:
  mariadb:
    image: mariadb:11.6
    container_name: lab3-mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-rootpass}
      MYSQL_DATABASE: notes_db
      MYSQL_USER: app
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-apppass}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - lab3-net
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  app:
    image: ${APP_IMAGE}
    container_name: lab3-app
    restart: unless-stopped
    environment:
      DATABASE_URL: mysql://app:${MYSQL_PASSWORD:-apppass}@mariadb:3306/notes_db
      NODE_ENV: production
      PORT: 5200
    ports:
      - "5200:5200"
    depends_on:
      mariadb:
        condition: service_healthy
    networks:
      - lab3-net
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5200/health/alive"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s

  nginx:
    image: nginx:1.27-alpine
    container_name: lab3-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    networks:
      - lab3-net

volumes:
  db_data:
    name: lab3_db_data

networks:
  lab3-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
COMPOSE_EOF

log "Creating nginx.conf template..."
tee /opt/lab3-notes/nginx.conf > /dev/null <<'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:5200;
    }

    server {
        listen 80;
        server_name _;

        location = / {
            return 301 /api/docs;
        }

        location /api/docs {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /api {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /notes {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        location /health {
            proxy_pass http://app;
        }

        location / {
            return 403;
        }
    }
}
NGINX_EOF

log "Creating .env template..."
tee /opt/lab3-notes/.env > /dev/null <<'ENV_EOF'
# Application image (will be set by deployment script)
APP_IMAGE=ghcr.io/inryceu/2-course-software-deployment-technologies-labs:latest

# Database credentials (set by deployment script)
MYSQL_ROOT_PASSWORD=rootpass_change_me
MYSQL_PASSWORD=apppass_change_me
ENV_EOF

log "Creating systemd service..."
tee /etc/systemd/system/lab3-notes.service > /dev/null <<'SERVICE_EOF'
[Unit]
Description=Lab3 Notes Application Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/lab3-notes

# Load environment variables
EnvironmentFile=/opt/lab3-notes/.env

# Start services
ExecStart=/usr/bin/docker compose up -d

# Stop gracefully
ExecStop=/usr/bin/docker compose down
ExecStopPost=/bin/sleep 2

TimeoutStartSec=300
TimeoutStopSec=60

# Restart policy
Restart=no

[Install]
WantedBy=multi-user.target
SERVICE_EOF

log "Reloading systemd daemon..."
systemctl daemon-reload

log "Setting permissions..."
chown -R root:root /opt/lab3-notes
chmod 755 /opt/lab3-notes
chmod 644 /opt/lab3-notes/.env
chmod 644 /opt/lab3-notes/docker-compose.yml
chmod 644 /opt/lab3-notes/nginx.conf

log "Verifying setup..."
docker compose -f /opt/lab3-notes/docker-compose.yml config > /dev/null 2>&1 || \
  error "Docker Compose configuration is invalid"

systemctl is-enabled lab3-notes > /dev/null 2>&1 || \
  warn "Service not yet enabled (will be done on first deployment)"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ TARGET VM SETUP COMPLETE!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Deployment directory: /opt/lab3-notes"
echo ""
echo "Configuration files created:"
echo "  • /opt/lab3-notes/.env"
echo "  • /opt/lab3-notes/docker-compose.yml"
echo "  • /opt/lab3-notes/nginx.conf"
echo ""
echo "Systemd service: lab3-notes.service"
echo ""
echo "Next steps:"
echo "  1. Runner will SSH here to deploy"
echo "  2. It will update /opt/lab3-notes/.env with image and secrets"
echo "  3. It will run: sudo systemctl start lab3-notes"
echo ""
echo "To manually test:"
echo "  • sudo systemctl start lab3-notes"
echo "  • sudo docker compose -f /opt/lab3-notes/docker-compose.yml ps"
echo "  • curl http://localhost/notes"
echo ""
echo "To view logs:"
echo "  • sudo journalctl -u lab3-notes -f"
echo "  • docker compose -f /opt/lab3-notes/docker-compose.yml logs -f"
echo ""
