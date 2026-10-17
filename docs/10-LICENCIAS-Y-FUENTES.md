# 10 — Licencias y fuentes

Todo lo afirmado acá tiene una fuente. Cuando no se pudo verificar, está
dicho.

---

## 1. Licencias de cada componente

### 1.1 LibreDTE Slim — AGPL-3.0

- Aplicación: <https://github.com/LibreDTE/libredte-app-slim>
- Stack: <https://github.com/LibreDTE/libredte-docker-slim>
- Backend tributario: <https://github.com/LibreDTE/libredte-lib-core-api>
- Texto completo: `COPYING` en este kit (copiado del upstream, sin modificar).
- Términos de uso: <https://slim.libredte.cl/legal>

**AGPL-3.0** es copyleft **de red**: no solo el código derivado tiene que
liberarse; también si alguien ofrece el software modificado **por medio de una
red**, debe ofrecer el código fuente.

### 1.2 Infraestructura

| Componente | Licencia | Fuente |
|---|---|---|
| Caddy 2.11 | Apache-2.0 | <https://github.com/caddyserver/caddy/blob/master/LICENSE> |
| PostgreSQL 18 | PostgreSQL License | <https://www.postgresql.org/about/licence/> |
| Valkey 9.2 | BSD-3-Clause | <https://github.com/valkey-io/valkey> |
| Mailpit v1.31 | MIT | <https://github.com/axllent/mailpit> |

Todas permisivas: se pueden usar en un producto propietario sin obligation de
liberar.

### 1.3 Capa de Hefesto Studio

`compose.hefesto.yaml`, `scripts/backup-hefesto.sh`, `.env.example`, `README.md`,
`VERSION.md`, `LICENCIAS.md`, `docs/` y `ejemplos/`.

> **Sin licencia declarada todavía.** Hefesto Studio debe elegirla (MIT, AGPL-3.0,
> u otra) y escribirla en un `LICENCIA` antes de distribuir el kit. Está anotado
> como pendiente en `07-PRUEBAS-DE-ACEPTACION.md`.

---

## 2. El matiz AGPL que decide la venta

De <https://slim.libredte.cl/legal>, textual:

> "Si incorporas el código de LibreDTE dentro de tu propio software, ese software
> debe liberarse públicamente bajo licencia AGPL. Conectar tu software a LibreDTE
> Slim por su API, como un proceso separado, no te obliga a liberar tu software."

### Qué queda fuera de AGPL

- Un tercero que consume Slim **por HTTP** (su API REST).
- Un tercero que corre Slim **como servicio aparte** (por ejemplo, la imagen
  Docker en su propio servidor).

En ambos casos, **el software del tercero no queda obligado a AGPL**.

### Qué sí queda dentro

- Un tercero que **incorpore** el código de LibreDTE en su propio proceso:
  una biblioteca PHP que importe el código de Slim, un *dispatcher* o un
  *bridge* en Python, un *fork* modificado.

En ese caso, el trabajo derivado **debe liberarse bajo AGPL**.

### Lo que hay que cumplir siempre

De los términos oficiales: hay que hacer **referencia pública** en el software
al proyecto y a su autor original, tanto si se usa sin modificar como si se
modifica.

La interfaz ya trae un pie con esa información. **Verificado** leyendo
`config/settings.py`: la plantilla `templates/base.html` incluye
`{% block footer %}{{ config.APP_COPYRIGHT }}{% endblock %}` y
`APP_COPYRIGHT` se arma con la URL de <https://libredte.cl>.

**Pendiente:** confirmar en un servidor real que ese pie se ve efectivamente en
la interfaz. Si Hefesto personaliza la plantilla, **no debe eliminar el aviso de
atribución**: es una obligación de la licencia, no un detalle cosmético.

### Cómo decirlo en la venta

Correcto y verificable:

> "Su e-commerce habla con LibreDTE Slim por API, como un proceso separado. En
> esa forma su software **no queda sujeto a AGPL**. Si en algún momento lo
> embeddean —lo meten dentro de su propio proceso en vez de llamarlo por HTTP—,
> ahí sí tendría que liberarse."

Incorrecto:

> "Es AGPL, pero como usted no lo modifica no pasa nada." → Falso: el escenario
> habitual (usar Slim sin modificarlo, por red) **sí** está fuera de AGPL; lo que
> obliga es *embeber o modificar* el código.

Y en cualquier caso, para una decisión real: **un abogado**, no un documento de
venta.

---

## 3. Marca

<https://slim.libredte.cl/legal>: *"LibreDTE es una marca registrada de SASCO
SpA"* y *"no puedes presentar tu proyecto como si fuera oficial de LibreDTE o
usar el nombre o el logo de forma que sugiera afiliación"*.

**Se puede:** "compatible con LibreDTE", "construido sobre LibreDTE Slim",
"facturación con LibreDTE Slim".

**No se puede:** "Slim de Hefesto", usar el logo de LibreDTE, o insinuar que
LibreDTE respalda el producto.

Este kit es de **Hefesto Studio**, sobre el stack oficial de LibreDTE Slim.

---

## 4. Lo que NO es LibreDTE

Diferenciar siempre, porque se confunde en la venta:

| | Qué es | Licencia |
|---|---|---|
| **Slim** | Software libre. Gratis. Corre en el servidor del cliente | AGPL-3.0, sin licencia comercial |
| **Lib Core API** | Núcleo tributario que Corre en el servidor del cliente (incluido gratis) | AGPL-3.0 |
| **LibreDTE Pro** | Servicio externo de pago, **parte de otra plataforma** | Servicio comercial de SASCO SpA |
| **API Gateway** | Servicio externo de pago (apigateway.cl) | Servicio comercial |
| **Flex** | Producto donde Slim es un componente | Producto comercial |

Los términos oficiales son claros: *"Pro y API Gateway no forman parte de
LibreDTE Slim ni de Core, y se consumen mediante plugins"* y *"sus términos de
uso y precios son responsabilidad de sus proveedores"*.

**Nunca cotizar Pro o API Gateway como si fueran parte de este kit.** Son
servicios de otro, con otro contrato.

---

## 5. Servicios externos que este kit no incluye

| Servicio | Para qué | Qué pasa si no se contrata |
|---|---|---|
| API Gateway (<https://www.apigateway.cl>) | Consultas al SII con una cuenta de LibreDTE | Sin token, esas consultas no están disponibles |
| Certificación DTE (<https://www.libredte.cl/certificacion-dte>) | Trámite de certificación ante el SII | El cliente emite en modo prueba; para emitir de verdad, es suyo |

**El cliente debe certificarse ante el SII.** Es un trámite suyo, no una función
del kit.

---

## 6. Fuentes consultadas

### Repositorios (verificados con `git clone`)

| Repositorio | Commit | Qué se sacó de ahí |
|---|---|---|
| `LibreDTE/libredte-docker-slim` | `3cc73ff5a89a85d87759393147282d6ce65be1ac` (2026-10-02) | `compose.yaml`, scripts, overrides, `Caddyfile`, `COPYING`, README |
| `LibreDTE/libredte-app-slim` | tag `v0.1.0b1` → `a94fad3badeeb05cccc651341374d8ace237f9bf` (2026-10-02) | Comportamiento de la app: API, permisos, primer usuario, settings |

### API de GitHub

| Consulta | Resultado |
|---|---|
| `GET /repos/LibreDTE/libredte-app-slim/tags` | Un solo tag: `v0.1.0b1` |
| `GET /repos/LibreDTE/libredte-app-slim/releases` | `[]` (sin releases) |
| `GET /repos/LibreDTE/libredte-lib-core-api/tags` | `[]` (sin tags) |
| `GET /repos/LibreDTE/libredte-docker-slim/git/trees/master?recursive=1` | Estructura completa del stack |

### Registries de imágenes (2026-10-16)

Digests obtenidos de la cabecera `Docker-Content-Digest` con `HEAD` al manifiesto:

- `ghcr.io/libredte/libredte-app-slim:v0.1.0b1` → `sha256:c9be0372…2c70ef`
- `ghcr.io/libredte/libredte-lib-core-api:latest` → `sha256:6dcb267a…441a0`
- `postgres:18-alpine` → `sha256:77f58511…a1873`
- `valkey/valkey:9.2-alpine` → `sha256:cdcb7b1c…24f4fb`
- `caddy:2.11-alpine` → `sha256:d8542f48…35f75f`
- `axllent/mailpit:v1.31` → `sha256:23fe39e8…e300387`

Valores completos en `VERSION.md`.

### Sitio oficial de LibreDTE Slim

| Página | Qué se tomó |
|---|---|
| <https://slim.libredte.cl/legal> | Licencia AGPL, el matiz de "incorporar" vs "conectar por API", reconocimiento público, marca registrada, que Pro/API Gateway son externos, que no hay licencia comercial |
| <https://slim.libredte.cl/services> | *"El software es gratis, lo que cotizamos es el servicio"*; **certificación es un servicio aparte y el SII la exige**; soporte a cotizar; **no venden hosting ni VPS, ni SaaS** |
| <https://slim.libredte.cl/compare> | Cuadro de funcionalidades: **"Todos menos boletas"** en envío al SII para Slim + Core; emisión masiva CSV; API REST; base PostgreSQL; actualizaciones aplicadas por el usuario; soporte "a cotizar" |

### Docker

- <https://docs.docker.com/engine/install/ubuntu/> y
  <https://docs.docker.com/engine/install/debian/> — instalación de Engine.

### Coolify y Supabase

- <https://coolify.io/docs> — despliegue de Docker Compose.
- <https://supabase.com/docs/guides/database/connecting-to-postgres> — conexión
  directa vs pooler; la directa es IPv6; el pooler en modo transacción **no
  soporta prepared statements**; `pg_dump` y migraciones requieren conexión
  directa.

### Software de terceros

- Django 6.1, Django REST Framework, `drf-spectacular`, Celery, `psycopg` 3,
  `django-celery-results` — declarados en el `pyproject.toml` del tag `v0.1.0b1`.

---

## 7. Lo que NO se pudo verificar (importante)

- **Versiones de PostgreSQL que ofrece Supabase hoy.** Su documentación de
  conexión revisada no las declara. **No se puede afirmar compatibilidad.**
- **Que la versión fija de la Core API por hash de commit exista publicada.**
  Solo se verificó que el repositorio no tiene tags.
- **Que `v0.1.0b1` sea la última versión disponible.** Es el único tag que había
  al 2026-10-16; después puede haber salido otro.
- **Que el pie con el aviso de AGPL se muestre efectivamente** en la interfaz.
- **Comportamiento real en Coolify y con Traefik.**
- **Emisiones reales de documentos.** Nadie emitió desde este kit.
- **Cumplimiento de la Ley 19.628** por parte de la aplicación.
- **Si las migraciones de una versión futura son reversibles.**

Ninguna de estas se presentó como hecha. Lo que no se verificó, está
marcado como pendiente en `07-PRUEBAS-DE-ACEPTACION.md`.