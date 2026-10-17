# 07 — Pruebas de aceptación

Este documento separa tres cosas y **no las mezcla nunca**:

- **A. Lo que upstream declara haber probado** (no es prueba de Hefesto).
- **B. Lo que Hefesto ejecutó de verdad** (poco: no hay Docker).
- **C. Lo que está pendiente** antes de vender o desplegar esto.

> **Estado del kit: `kit preparado`.**
> No hay Docker ni servidor en el entorno donde se construyó este kit.
> **Ninguna prueba de este documento se ejecutó contra Docker, PostgreSQL,
> Slim ni Coolify.** Lo que hay abajo marcado como "ejecutado" son pruebas de
> shell sobre archivos, sin contenedores.

---

## A. Lo que upstream declara (fuente: `docs/UPSTREAM-README.md`, sección "Validación")

Upstream prueba en **Docker Desktop (macOS, arm64, 8 GB)**:

- Los cuatro comandos del inicio rápido, desde cero, con demo: login, páginas,
  descarga de PDF (generado por la Core API) y emisión masiva con PDF (worker,
  enlace de descarga por correo, ZIP descargable).
- Plantilla de producción sin demo: pantalla de alta del primer usuario, login,
  directorios locales (`local-dirs.yaml`), HTTPS local con HSTS.
- Segunda corrida de `up` (`setup` repetible, secretos sin cambio), `down` + `up`
  conservando usuarios y secretos, respaldo → daño → restauración
  (base, media y secretos), `FIELD_ENCRYPTION_KEY` distinta falla y el
  procedimiento de reemplazo funciona.
- `docker compose config -q` falla sin `.env` y pasa con cada plantilla y
  override; `shellcheck` limpio; sin puertos inesperados.
- Memoria en reposo: web ≈ 330 MiB, worker ≈ 280 MiB, worker-emision-masiva
  ≈ 210 MiB, Core API ≈ 50 MiB, PostgreSQL ≈ 30 MiB, Caddy ≈ 12 MiB.

**Nada de esto lo verificó Hefesto.** Es la experiencia del equipo de LibreDTE,
en macOS, no en un VPS Ubuntu. Se toma como referencia, no como garantía.

## B. Lo que Hefesto ejecutó realmente

### B.1 Verificación de sintaxis de los scripts

```
bash -n scripts/backup-hefesto.sh  -> exit 0
bash -n scripts/backup.sh          -> exit 0   (upstream)
bash -n scripts/setup.sh           -> exit 0   (upstream)
bash -n scripts/entrypoint.sh      -> exit 0   (upstream)
bash -n scripts/lib.sh             -> exit 0   (upstream)
```

Ejecutado con el bash de Git for Windows. `shellcheck` **no** se ejecutó (no está
instalado en el entorno).

### B.2 `backup-hefesto`: listado, verificación y health

Con respaldos de prueba construidos a mano (los mismos nombres y el mismo formato
de manifiesto que escribe el script):

| Prueba | Resultado |
|---|---|
| `list` con un respaldo completo | Lista la marca de tiempo ✅ |
| `verify` de un respaldo íntegro | Acepta, 3 artefactos con SHA-256 correctos ✅ |
| `verify` con un artefacto corrupto (1 byte agregado) | **Rechaza** ✅ |
| `verify` con el manifiesto alterado después de marcarse | **Rechaza** ✅ |
| `health` con respaldo reciente | OK ✅ |
| `list` tras corromper un artefacto | Sigue listando el respaldo (no lo oculta) ✅ |

### B.3 `backup-hefesto`: validación de rutas del tar

`validar_tar` probada contra archivos `.tar.gz` construidos a propósito:

| Caso | Resultado |
|---|---|
| Tar legítimo (`media/logo.png`) | Acepta ✅ |
| Entrada con `..` (`media/../../escapada.txt`) | **Rechaza** ✅ |
| Entrada con ruta absoluta (`/etc/evil.txt`) | **Rechaza** ✅ |
| Enlace simbólico a `/etc/shadow` | **Rechaza** ✅ |
| Enlace simbólico con destino relativo fuera | **Rechaza** ✅ |
| Archivo inexistente o ilegible | **Rechaza** ✅ |

> Estos dos casos (tar ilegible y enlace simbólico) **encontraron un defecto real
> durante el desarrollo** y lo corrigieron: la validación devolvía "correcto" sin
> haber mirado nada cuando `tar` fallaba.

### B.4 Verificaciones de fuentes (documentales, no de ejecución)

| Afirmación | Cómo se verificó |
|---|---|
| Único tag de `libredte-app-slim`: `v0.1.0b1` | `GET api.github.com/repos/LibreDTE/libredte-app-slim/tags` |
| No hay releases publicadas | `GET /repos/LibreDTE/libredte-app-slim/releases` → `[]` |
| `libredte-lib-core-api` sin tags | `GET /repos/LibreDTE/libredte-lib-core-api/tags` → `[]` |
| Digests de las 6 imágenes | Cabecera `Docker-Content-Digest` contra `ghcr.io` y `registry-1.docker.io` |
| Contenido del compose y los scripts | `git clone` del upstream, commit `3cc73ff` |
| Comportamiento de Slim (API, primer usuario, permisos) | Lectura del código del tag `v0.1.0b1` |
| Términos legales y marca | https://slim.libredte.cl/legal, /services, /compare |
| Cachés SHA-256 de los archivos vendorizados | `Get-FileHash -Algorithm SHA256` |

### B.5 Lo que NO se ejecutó (importante)

- `docker compose config -q` — **no** hay Docker.
- `docker compose up`, healthchecks, `setup`, `seed`, catálogos del SII.
- `pg_dump` / `pg_restore` reales.
- La emisión de un documento, la descarga de PDF, la emisión masiva.
- Coolify, Traefik, Let's Encrypt.
- `shellcheck`.

---

## C. Pendiente antes de desplegar en un cliente

### C.1 Bloqueante (no desplegar sin esto)

- [ ] `docker compose config -q` con `.env` de producción → pasa.
- [ ] `docker compose up -d` completo y `setup` termina con `==> Listo`.
- [ ] Todos los servicios `healthy` o `running`.
- [ ] `curl -sI https://dominio/health/` responde bien.
- [ ] `/setup/` crea el primer usuario y después se cierra.
- [ ] Login y navegación sin errores en consola del navegador.
- [ ] **Salida a `cdn.jsdelivr.net`**: la interfaz carga Bootstrap, Font Awesome y
      htmx desde ahí. Si el navegador del cliente no llega, la interfaz se ve
      rota. **Probar en la red real del cliente.**
- [ ] Respaldo generado **y verificado**.
- [ ] **Restauración probada de verdad**, no solo generada.

### C.2 Importante (antes de la primera emisión real)

- [ ] Correo SMTP configurado y probado (recuperación de contraseña).
- [ ] `SLIM_SEED_DEMO=0` confirmado en `.env`.
- [ ] `.env` con permisos `600` y fuera de git.
- [ ] Copia externa del respaldo configurada y probada.
- [ ] TLS válido y HSTS si hay HTTPS.
- [ ] `FIELD_ENCRYPTION_KEY` respaldada y el respaldo con esa clave verificado.
- [ ] Límites de memoria ajustados al RAM real del VPS.
- [ ] Volumen de disco y alertas de llenado.
- [ ] Verificar que **no** se publiquen puertos de `db`, `valkey` ni `caddy`
      fuera de lo previsto:
      ```shell
      docker compose ps
      ss -lntp | grep -E ':(5432|6379|8000)\b'   # no deberían estar expuestos
      ```

### C.3 Verificaciones concretas pendientes

| Pendiente | Por qué importa |
|---|---|
| Digests en `VERSION.md` son de **índice multi-plataforma** | El digest por arquitectura se resuelve en el `pull`; para fijar hay que usar el digest del manifiesto de la plataforma |
| Fijar la Core API por hash de commit | `libredte-lib-core-api:latest` es una etiqueta móvil; hay que confirmar que exista imagen para el commit elegido |
| Bash disponible en `postgres:18-alpine` | `backup-hefesto.sh` y `backup.sh` usan `#!/bin/bash`. Upstream usa el mismo intérprete con la misma imagen y declara haber probado el respaldo, pero **no se comprobó directamente** |
| `tar --no-same-owner` en esa imagen | Se usa al restaurar. BusyBox lo soporta, pero conviene confirmarlo en el servidor |
| Emisión de un documento real | Nadie ha emitido desde este kit. Hay que hacerlo antes de cobrar |
| Comportamiento de Coolify en la práctica | El flujo del dominio y la red del proxy se verificó **leyendo**, no corriendo |
| Análisis de migraciones reversibles | No se revisó el historial; ver `06-ACTUALIZACIONES-Y-REVERSION.md` |
| Versiones disponibles de Supabase | **No verificado.** Ver `09-EXPORTACION-O-TRASPASO.md` |
| Licencia de la capa de Hefesto | **Sin definir.** Elegir y escribir antes de distribuir |
| El navegador del cliente llega a `cdn.jsdelivr.net` | La interfaz depende de ese CDN |

### C.4 Decisión de diseño pendiente de confirmar en el servidor

`stop_grace_period` (5m web/worker, 30m emisión masiva) es un valor **elegido por
Hefesto**, no viene de upstream. Hay que confirmar que el `docker stop` del VPS
respeta esos plazos y que el tiempo de detención resultante es aceptable para el
cliente.

---

## Checklist de aceptación para el cliente (resumen)

1. El sitio abre con HTTPS válido y redirige a `/setup/`.
2. `/setup/` crea el primer usuario y se cierra.
3. `/setup/` ya no ofrece el alta.
4. El login funciona y activa segundo factor.
5. Se puede cargar el certificado digital y un CAF.
6. Se emite un documento de prueba y se descarga su PDF.
7. La emisión masiva produce un ZIP descargable.
8. Hay un respaldo con manifiesto y SHA-256, verificado.
9. La restauración de ese respaldo se probó y dejó el servicio detenido.
10. El cliente sabe que debe certificarse ante el SII antes de emitir.

Los puntos 6 y 7 requieren un certificado y el flujo del SII: **son del cliente**,
y su ejecución en un servidor real es parte del traspaso, no de este kit.