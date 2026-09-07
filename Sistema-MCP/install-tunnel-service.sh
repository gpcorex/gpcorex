#!/usr/bin/env bash
set -euo pipefail

TUNNEL_ID="${1:-}"
MCP_URL="${2:-http://127.0.0.1:8765/mcp}"
PROFILE="sistema"
HEALTH_ADDR="127.0.0.1:8787"

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

install -d -o root -g ubuntu -m 750 /etc/sistema

if [[ ! -f /etc/sistema/tunnel.env ]]; then
  cat >/etc/sistema/tunnel.env <<'EOF'
# No guardar esta clave en Git ni pegarla en comandos visibles.
# CONTROL_PLANE_API_KEY=sk-...
EOF
fi
chown root:ubuntu /etc/sistema/tunnel.env
chmod 640 /etc/sistema/tunnel.env

# Perfil oficial de tunnel-client. Solo guarda una referencia a la variable de entorno,
# nunca el secreto literal.
sudo -u ubuntu -H /usr/local/bin/tunnel-client init \
  --sample sample_mcp_with_dcr \
  --profile "$PROFILE" \
  --force \
  --tunnel-id "$TUNNEL_ID" \
  --control-plane-api-key-ref env:CONTROL_PLANE_API_KEY \
  --mcp-server-url "$MCP_URL" \
  --health-listen-addr "$HEALTH_ADDR"

install -m 644 "$(dirname "$0")/systemd/tunnel-client.service" /etc/systemd/system/tunnel-client.service
systemctl daemon-reload

echo
cat <<EOF
Preparacion terminada. El servicio NO se inicia automaticamente hasta validar autenticacion.

1. Cargar la runtime key en /etc/sistema/tunnel.env:
     sudo nano /etc/sistema/tunnel.env
   Debe quedar una linea CONTROL_PLANE_API_KEY=... y permisos 640 root:ubuntu.

2. Validar el perfil y la autorizacion real:
     sudo -u ubuntu -H bash -lc 'set -a; source /etc/sistema/tunnel.env; set +a; tunnel-client doctor --profile $PROFILE --explain'

3. Solo si doctor pasa, iniciar:
     sudo systemctl enable --now tunnel-client

4. Verificar el estado real, no solo el proceso:
     curl -fsS http://$HEALTH_ADDR/healthz && echo
     curl -fsS http://$HEALTH_ADDR/readyz && echo
     sudo systemctl status tunnel-client --no-pager
     sudo journalctl -u tunnel-client -n 100 --no-pager

No considerar la conexion terminada hasta que /readyz devuelva HTTP 200 y ChatGPT pueda invocar Sistema MCP.
EOF
