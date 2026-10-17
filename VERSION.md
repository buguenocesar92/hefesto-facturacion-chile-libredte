# VERSION.md — versiones y su origen

Todo lo que está en esta tabla fue **verificado contra la fuente** el
2026-10-16. Cuando no se pudo verificar, la fila dice explícitamente qué falta.

---

## 1. Stack de LibreDTE Slim (upstream)

| Qué | De dónde sale | Versión |
|---|---|---|
| Stack Docker de Slim | https://github.com/LibreDTE/libredte-docker-slim | commit `3cc73ff5a89a85d87759393147282d6ce65be1ac`, 2026-10-02, rama `master` |
| Aplicación Slim | https://github.com/LibreDTE/libredte-app-slim | tag `v0.1.0b1` → commit `a94fad3badeeb05cccc651341374d8ace237f9bf`, 2026-10-02 |

> El tag `v0.1.0b1` es **anotado** (apunta a un objeto de tag `48cc4206…`,
> que a su vez apunta al commit de arriba).

### 1.1 Versión publicada de `libredte-app-slim`: solo hay beta

Verificado contra la API de GitHub:

- `GET /repos/LibreDTE/libredte-app-slim/tags` → **un solo tag**:
  `v0.1.0b1`.
- `GET /repos/LibreDTE/libredte-app-slim/releases` → **array vacío**: no hay
  releases publicadas.

**No existe una versión estable publicada.** La `b` de `0.1.0b1` es de beta y
el `pyproject.toml` de la app declara `version = "0.1.0b1"`. Hay que decirlo con
todas sus letras al cliente: se está instalando software en beta, lo que obliga
obliga a respaldos y a poder volver atrás (ver `06-ACTUALIZACIONES-Y-REVERSION.md`).

### 1.2 Digests de imagen (referencia, no fijados en el compose)

Resueltos el 2026-10-16 contra los registries (cabecera `Docker-Content-Digest`
de un `HEAD` al manifiesto):

| Imagen | Digest |
|---|---|
| `ghcr.io/libredte/libredte-app-slim:v0.1.0b1` | `sha256:c9be03723608823e5a415737bc09363d558d22390df2221b108390b1992c70ef` |
| `ghcr.io/libredte/libredte-lib-core-api:latest` | `sha256:6dcb267ac56488c93b095e2e251f8a7bd25718281cb47ae96426617dd08441a0` |
| `postgres:18-alpine` | `sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873` |
| `valkey/valkey:9.2-alpine` | `sha256:cdcb7b1c7b6f1c9cb9442c71ac6275e78184657448407b2c1fdde7ee8024f4fb` |
| `caddy:2.11-alpine` | `sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f` |
| `axllent/mailpit:v1.31` | `sha256:23fe39e81bde596a918000b3135c0f85dc8bb4c9ea6be274b051143f3e300387` |

**Son los digest de los índices multi-plataforma**, no los de una imagen
concreta: `docker pull` en un servidor `linux/amd64` resuelve el manifiesto de esa
arquitectura dentro del índice. Por eso el digest del índice sirve para
*auditar* ("esto es lo que había el día X"), no para fijar exactamente lo que se
instala.

**Por qué NO van en el `compose.yaml`:** upstream fija por tag, y cambiar el
modo de fijación sin necesidad rompe la promesa de "el compose upstream queda
intacto y legible" sobre la que está construido este kit. Si el cliente quiere
fijar por digest, se hace en un override propio del servidor (ver
`docs/06-ACTUALIZACIONES-Y-REVERSION.md`), no acá.

### 1.3 La excepción: la Core API es `latest`

`libredte-lib-core-api` **no publica tags** (verificado:
`GET /repos/LibreDTE/libredte-lib-core-api/tags` → array vacío). Por eso su
versión por defecto es `latest` y no hay forma de fijarla por versión.

El procedimiento que sí funciona, y que documenta upstream, es fijar
`CORE_API_VERSION` al **hash completo (40 hexadecimales) del commit**: sus
imágenes se publican con ese tag. `scripts/lib.sh` detecta ese caso y exporta
`LIBREDTE_BACKEND_COMMIT`, que la app muestra en su pie.

**Pendiente de verificar:** el hash del commit con el que se quiere fijar en un
servidor real, y que exista imagen publicada para él. Nunca se hizo un
`docker pull` desde este entorno (no hay Docker instalado).

---

## 2. Componentes del stack

| Componente | Imagen | Versión por defecto | Licencia |
|---|---|---|---|
| Servidor web / TLS / estáticos / media | `caddy:2.11-alpine` | 2.11 | Apache-2.0 |
| Slim: web (gunicorn) y workers (Celery) | `ghcr.io/libredte/libredte-app-slim` | `v0.1.0b1` (beta) | AGPL-3.0 |
| Backend tributario (timbre, firma, PDF, catálogos) | `ghcr.io/libredte/libredte-lib-core-api` | `latest` | AGPL-3.0 |
| Base de datos | `postgres:18-alpine` | 18 | PostgreSQL License |
| Cola y caché | `valkey/valkey:9.2-alpine` | 9.2 | BSD-3-Clause |
| Correo de pruebas (solo desarrollo) | `axllent/mailpit:v1.31` | v1.31 | MIT |

Detalle de licencias en `LICENCIAS.md` y `docs/10-LICENCIAS-Y-FUENTES.md`.

### 2.1 Base de la imagen de Slim

`Dockerfile` de `libredte-app-slim` (verificado en el tag `v0.1.0b1`):
`ARG PYTHON_VERSION=3.14`, sobre `python:3.14-slim`, dependencias instaladas con
`uv` (`ghcr.io/astral-sh/uv:0.12`). `pyproject.toml`: `requires-python = ">=3.14"`,
`django==6.1.*`, `djangorestframework>=3.15`, `psycopg[binary]>=3.1`,
`django-celery-results>=2.6`.

El usuario de la app en la imagen es `slim` con UID/GID **10001** (de ahí los
`chown` de `setup.sh`, `backup.sh` y `backup-hefesto.sh`).

---

## 3. Archivos vendorizados de upstream (fidelidad byte a byte)

Copiados **sin modificar** del commit `3cc73ff` de `libredte-docker-slim`.
SHA-256 para comprobar que nadie los editó sin querer:

| Archivo en este kit | SHA-256 |
|---|---|
| `compose.yaml` | `b62e600ebee01b39d1fb4fe19cf52082300cf06a74d5e93a4b1fe870cc24d724` |
| `COPYING` | `282751b8c98ee9e445346eb57a992c9ecbe25ed8dd554df046777313e19b10f9` |
| `config/caddy/Caddyfile` | `c5f8c4eefd7074af350bc6034ff8c1964af14393edbed217dfb1af34431624c2` |
| `overrides/local-dirs.yaml` | `f96effc1700ad922c7be078ba793b3854280a594b6943e5124b363acb0adc370` |
| `overrides/traefik.yaml` | `e3a3a001936519ec6d7bcc62d3def558f609f4d29c93a8c8971835037f85d7f3` |
| `scripts/backup.sh` | `0e39b7c6160aba9af4f93cc0d79a90db12b974927fd85daccf8858bdba4361ad` |
| `scripts/entrypoint.sh` | `9d5d6f367ec69de7c953ef0215cc95695082e1f1ee0bb063a6efb45ce9bd8355` |
| `scripts/lib.sh` | `e0ef7986ba1b6bfd9cd5c5e52831e2474f2dbaf7e0c2c1ade36c9695c0c9638e` |
| `scripts/setup.sh` | `77a39fcd38beb293676e92fcbd4ffa22bfd4361e8eb0459dc58f80b489419c2c` |
| `docs/UPSTREAM-README.md` | `f8552a534dea74cb78e5000d5adafa2c3c17ec6efb285122c4775930dbf5d4cc` |

Las dos plantillas `.env` de upstream quedaron en `ejemplos/`, **renombradas y
con un aviso de "DEMOSTRACIÓN" agregado al principio** (única modificación: se
les antepone un banner). Sus SHA-256 **con** el banner:

| Archivo | SHA-256 |
|---|---|
| `ejemplos/01-env.desarrollo-local.ejemplo.txt` | `d144a4b9e2ec8626e1553b3dac2f1a3bb31c6f5bca1737bb4b3d929fee69b6ec` |
| `ejemplos/02-env.produccion.upstream.ejemplo.txt` | `d54da4ce382c18153be602cf3d736e90685294a6679844366c01a9d1dc660d12` |

Las dos plantillas `.env` de upstream quedaron en `ejemplos/` **renombradas y
marcadas como demostración**, para que nadie las confunda con el `.env.example`
de Hefesto ni con un `.env` real.

## 4. Archivos propios de Hefesto Studio

| Archivo | Qué es |
|---|---|
| `compose.hefesto.yaml` | Override de producción: servicio `backup-hefesto` + `stop_grace_period` |
| `scripts/backup-hefesto.sh` | Respaldos con manifiesto JSON, SHA-256 y marcador de completitud |
| `.env.example` | Plantilla de producción de Hefesto, sin secretos |
| `README.md`, `VERSION.md`, `LICENCIAS.md` | Documentación del kit |
| `docs/01` … `docs/10` | Documentación en español de Chile |
| `ejemplos/` | Plantillas marcadas como DEMOSTRACIÓN |

Todo lo demás es de LibreDTE y conserva su licencia AGPL-3.0.

---

## 5. Limitaciones del versionado, dichas sin adornar

1. **`SLIM_VERSION=v0.1.0b1` es beta.** No hay estable. Es el único tag
   publicado y el que traen las plantillas de upstream.
2. **La Core API corre en `latest`.** Sin tags publicados no hay más. Fijarla
   por hash de commit es posible, pero no se verificó en la práctica desde acá.
3. **Los digest son de índice multi-plataforma**, no por imagen concreta.
4. **Este kit no ejecutó Docker.** No hay Docker en el entorno donde se preparó
   (ver `docs/07-PRUEBAS-DE-ACEPTACION.md`). Ninguna versión de acá está probada
   corriendo: están leídas de las fuentes citadas.