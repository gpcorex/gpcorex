from __future__ import annotations

import json
import os
import platform
import shlex
import subprocess
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP

ROOT = Path(os.environ.get("SISTEMA_ROOT", "/home/ubuntu/Sistema")).resolve()
HOST = os.environ.get("SISTEMA_MCP_HOST", "0.0.0.0")
PORT = int(os.environ.get("SISTEMA_MCP_PORT", "8765"))

mcp = FastMCP(
    "Sistema MCP",
    instructions=(
        "MCP operativo minimo para administrar Sistema en la VM. "
        "No contiene logica de negocio ni capas de coordinacion."
    ),
    stateless_http=True,
    json_response=True,
)


def _safe_path(relative: str) -> Path:
    p = (ROOT / relative).resolve()
    if p != ROOT and ROOT not in p.parents:
        raise ValueError("Ruta fuera de SISTEMA_ROOT")
    return p


def _run(argv: list[str], timeout: int = 30) -> dict[str, Any]:
    cp = subprocess.run(
        argv,
        cwd=str(ROOT) if ROOT.exists() else "/home/ubuntu",
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
        env=os.environ.copy(),
    )
    return {
        "argv": argv,
        "returncode": cp.returncode,
        "stdout": cp.stdout[-20000:],
        "stderr": cp.stderr[-20000:],
    }


@mcp.tool()
def health() -> dict[str, Any]:
    """Estado basico del MCP y de la VM."""
    return {
        "ok": True,
        "name": "Sistema MCP",
        "hostname": platform.node(),
        "python": platform.python_version(),
        "root": str(ROOT),
        "root_exists": ROOT.exists(),
    }


@mcp.tool()
def system_status() -> dict[str, Any]:
    """Resumen de sistema operativo, memoria, disco y uptime."""
    return {
        "uname": _run(["uname", "-a"]),
        "uptime": _run(["uptime"]),
        "memory": _run(["free", "-h"]),
        "disk": _run(["df", "-h", "/"]),
    }


@mcp.tool()
def list_dir(path: str = ".", max_entries: int = 200) -> dict[str, Any]:
    """Lista un directorio dentro de /home/ubuntu/Sistema."""
    p = _safe_path(path)
    if not p.exists():
        return {"ok": False, "error": "not_found", "path": str(p)}
    if not p.is_dir():
        return {"ok": False, "error": "not_a_directory", "path": str(p)}
    entries = []
    for child in sorted(p.iterdir(), key=lambda x: x.name.lower())[:max_entries]:
        entries.append({
            "name": child.name,
            "type": "dir" if child.is_dir() else "file",
            "size": child.stat().st_size if child.is_file() else None,
        })
    return {"ok": True, "path": str(p), "entries": entries}


@mcp.tool()
def read_file(path: str, max_chars: int = 60000) -> dict[str, Any]:
    """Lee un archivo UTF-8 dentro de /home/ubuntu/Sistema."""
    p = _safe_path(path)
    if not p.exists() or not p.is_file():
        return {"ok": False, "error": "not_found", "path": str(p)}
    data = p.read_text(encoding="utf-8", errors="replace")
    return {
        "ok": True,
        "path": str(p),
        "truncated": len(data) > max_chars,
        "content": data[:max_chars],
    }


@mcp.tool()
def write_file(path: str, content: str, create_parents: bool = True) -> dict[str, Any]:
    """Escribe un archivo UTF-8 dentro de /home/ubuntu/Sistema."""
    p = _safe_path(path)
    if create_parents:
        p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")
    return {"ok": True, "path": str(p), "bytes": len(content.encode("utf-8"))}


ALLOWED_COMMANDS = {
    "git": "git",
    "pm2": "pm2",
    "python3": "python3",
    "node": "node",
    "npm": "npm",
    "systemctl": "systemctl",
    "journalctl": "journalctl",
    "ls": "ls",
    "cat": "cat",
    "find": "find",
    "grep": "grep",
    "ss": "ss",
    "curl": "curl",
}


@mcp.tool()
def run_command(command: str, timeout: int = 60) -> dict[str, Any]:
    """Ejecuta un comando controlado, sin shell, usando una lista de ejecutables permitidos."""
    argv = shlex.split(command)
    if not argv:
        return {"ok": False, "error": "empty_command"}
    executable = Path(argv[0]).name
    if executable not in ALLOWED_COMMANDS:
        return {
            "ok": False,
            "error": "command_not_allowed",
            "allowed": sorted(ALLOWED_COMMANDS),
        }
    argv[0] = ALLOWED_COMMANDS[executable]
    result = _run(argv, timeout=max(1, min(timeout, 300)))
    result["ok"] = result["returncode"] == 0
    return result


@mcp.tool()
def pm2_status() -> dict[str, Any]:
    """Devuelve el estado JSON de PM2."""
    result = _run(["pm2", "jlist"], timeout=30)
    if result["returncode"] == 0:
        try:
            result["processes"] = json.loads(result["stdout"])
        except json.JSONDecodeError:
            pass
    result["ok"] = result["returncode"] == 0
    return result


@mcp.tool()
def restart_pm2(process_name: str) -> dict[str, Any]:
    """Reinicia un proceso PM2 por nombre exacto."""
    if not process_name or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_." for c in process_name):
        return {"ok": False, "error": "invalid_process_name"}
    result = _run(["pm2", "restart", process_name], timeout=60)
    result["ok"] = result["returncode"] == 0
    return result


if __name__ == "__main__":
    mcp.run(
        transport="streamable-http",
        host=HOST,
        port=PORT,
        streamable_http_path="/mcp",
    )
