# Sistema: arquitectura de conexión estable

## Objetivo

Eliminar la dependencia de sesiones temporales, clientes SSH locales del chat y túneles artesanales. Sistema debe conservar control operativo de sus VMs aunque falle una interfaz, una app o un provider.

## Diseño recomendado (2026-09)

1. **Canal primario: Secure MCP Tunnel oficial de OpenAI**
   - `Sistema MCP` escucha solo en `127.0.0.1`.
   - `tunnel-client` mantiene una conexión HTTPS saliente al control plane de OpenAI.
   - No se expone el puerto MCP a Internet.
   - El runtime debe correr como servicio supervisado por systemd.

2. **Canal secundario: SSH entre VMs**
   - Cada VM mantiene SSH por clave pública.
   - La VM principal de Sistema puede entrar a la VM legado con una clave dedicada de automatización.
   - Esa clave no debe ser la clave personal del usuario.
   - `known_hosts` debe fijarse y no usarse `StrictHostKeyChecking=no` en producción.

3. **Canal de emergencia: acceso SSH manual del usuario**
   - Se conserva como recuperación fuera de ChatGPT.
   - No forma parte del funcionamiento normal de Sistema.

## Invariantes

- No publicar `Sistema MCP` directamente en una IP pública.
- No depender de PM2 para el túnel: usar `systemd` con reinicio automático y límites.
- No usar una única clave SSH para usuario, automatización y migración.
- No guardar secretos en Git.
- Registrar health, readiness, reinicios y última conexión del túnel.
- Separar el plano de control de Sistema de Prisma/Diseño/Programador: una app puede caer sin perder acceso operativo.

## Topología

```text
ChatGPT / producto OpenAI compatible
            |
            | Secure MCP Tunnel (HTTPS saliente)
            v
     tunnel-client (systemd)
            |
            v
 Sistema MCP 127.0.0.1:8765
            |
            +--> archivos / servicios / logs / comandos de VM nueva
            |
            +--> SSH dedicado --> VM legado

Usuario ---- SSH manual ----> VM nueva / VM legado   (emergencia)
```

## Qué no debe volver a ocurrir

- Que `Prisma`, `IAChat`, `Puente` o un bridge sea condición necesaria para conservar acceso a las VMs.
- Que la caída de una sesión de ChatGPT obligue a redescubrir la arquitectura.
- Que el acceso remoto dependa de un binario SSH disponible dentro de un entorno temporal del asistente.

## Estado actual conocido

- VM nueva: `136.248.73.25`, `instance-20260906-2322`.
- VM legado: `137.131.131.196`, `instance-20260526-1622`.
- `Sistema MCP`: `127.0.0.1:8765/mcp` en la VM nueva.
- SSH está habilitado con autenticación por clave en ambas VMs.
- `tunnel-client` está instalado en la VM nueva.
- Bloqueo actual del canal primario: respuesta `401 Unauthorized` del control plane al usar el túnel configurado.

## Criterio de cierre

La conexión se considera terminada solo cuando:

1. `Sistema MCP` está `ready` localmente.
2. `tunnel-client` está `running/ready` como servicio.
3. ChatGPT puede ejecutar al menos una herramienta de lectura y una acción controlada de escritura/operación.
4. La VM nueva puede consultar la VM legado mediante SSH dedicado.
5. Reiniciar cualquiera de las apps de Sistema no corta el canal de control.
6. Reiniciar la VM nueva recupera automáticamente MCP + túnel sin intervención manual.
