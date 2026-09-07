#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/home/ubuntu/Sistema-MCP"
REPO_URL="https://github.com/gpcorex/gpcorex.git"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

sudo apt-get update
sudo apt-get install -y python3 python3-venv git

git clone --depth 1 "$REPO_URL" "$TMP_DIR/repo"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -a "$TMP_DIR/repo/Sistema-MCP/." "$APP_DIR/"

python3 -m venv "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/pip" install --upgrade pip
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

sudo tee /etc/systemd/system/sistema-mcp.service >/dev/null <<'UNIT'
[Unit]
Description=Sistema MCP
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/Sistema-MCP
Environment=SISTEMA_ROOT=/home/ubuntu/Sistema
Environment=SISTEMA_MCP_HOST=127.0.0.1
Environment=SISTEMA_MCP_PORT=8765
ExecStart=/home/ubuntu/Sistema-MCP/.venv/bin/python /home/ubuntu/Sistema-MCP/server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now sistema-mcp
sleep 2
sudo systemctl --no-pager --full status sistema-mcp || true
ss -ltnp | grep ':8765' || true

echo "Sistema MCP instalado en localhost: http://127.0.0.1:8765/mcp"
