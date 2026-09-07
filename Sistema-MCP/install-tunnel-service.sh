#!/usr/bin/env bash
set -euo pipefail

TUNNEL_ID="${1:-}"
MCP_URL="${2:-http://127.0.0.1:8765/mcp}"

if [[ -z "$TUNNEL_ID" ]]; then
  echo "Uso: sudo $0 tunnel_<id> [mcp_url]" >&2
  exit 2
fi

if [[ ! "$TUNNEL_ID" =~ ^tunnel_[0-9a-f]{32}$ ]]; then
  echo "Tunnel ID invalido: $TUNNEL_ID" >&2
  exit 2
fi

if ! command -v tunnel-client >/dev/null 2>&1; then
  echo "No encuentro tunnel-client en PATH" >&2
  exit 1
fi

if ! systemctl list-unit-files sistema-mcp.service >/dev/null 2>&1; then
  echo "Advertencia: no pude confirmar sistema-mcp.service" >&2
fi

install -d -m 700 /etc/sistema

if [[ ! -f /etc/sistema/tunnel.env ]]; then
  umask 077
  cat >/etc/sistema/tunnel.env <<EOF
CONTROL_PLANE_TUNNEL_ID=$TUNNEL_ID
MCP_SERVER_URL=$MCP_URL
# Completar manualmente sin pegar el secreto en el historial del shell:
# CONTROL_PLANE_API_KEY=sk-...
EOF
  chmod 600 /etc/sistema/tunnel.env
else
  sed -i "s|^CONTROL_PLANE_TUNNEL_ID=.*|CONTROL_PLANE_TUNNEL_ID=$TUNNEL_ID|" /etc/sistema/tunnel.env || true
  sed -i "s|^MCP_SERVER_URL=.*|MCP_SERVER_URL=$MCP_URL|" /etc/sistema/tunnel.env || true
fi

install -m 644 "$(dirname "$0")/systemd/tunnel-client.service" /etc/systemd/system/tunnel-client.service
systemctl daemon-reload

echo
cat <<'EOF'
Servicio instalado, pero NO iniciado.

1. Editar /etc/sistema/tunnel.env y agregar CONTROL_PLANE_API_KEY.
2. Verificar permisos: sudo chmod 600 /etc/sistema/tunnel.env
3. Probar primero:
     sudo -u ubuntu bash -lc 'set -a; source /etc/sistema/tunnel.env; set +a; tunnel-client doctor --explain'
4. Solo si doctor pasa:
     sudo systemctl enable --now tunnel-client
5. Verificar readiness/logs:
     sudo systemctl status tunnel-client --no-pager
     sudo journalctl -u tunnel-client -n 100 --no-pager
EOF
