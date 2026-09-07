# Sistema MCP

MCP operativo mínimo para administrar `/home/ubuntu/Sistema` sin depender del legado de CoreX/IAChat.

## Herramientas iniciales

- `health`
- `system_status`
- `list_dir`
- `read_file`
- `write_file`
- `run_command` con allowlist y sin shell
- `pm2_status`
- `restart_pm2`

## Instalación

En la VM Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/gpcorex/gpcorex/main/Sistema-MCP/install.sh | bash
```

El servicio queda gestionado por systemd como `sistema-mcp` y escucha solamente en `127.0.0.1:8765`.

## Comprobación local

```bash
systemctl status sistema-mcp --no-pager
ss -ltnp | grep 8765
```

Endpoint local MCP: `http://127.0.0.1:8765/mcp`.

## Seguridad

No abrir el puerto 8765 directamente a Internet. Para acceso remoto se debe colocar por delante un transporte HTTPS autenticado (túnel/reverse proxy con autenticación) y mantener el MCP escuchando en localhost.
