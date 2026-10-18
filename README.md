# Kit de despliegue LibreDTE Slim — Hefesto Studio

Facturación electrónica (DTE) chilena en un VPS propio, con Docker Compose y
compatible con Coolify.

**Estado del kit: `kit preparado`.**
No se ejecutó Docker ni hay servidor en el entorno donde se construyó este kit.
Los archivos están escritos y verificados contra las fuentes, pero **nada corrió
realmente**. Lo que sí se ejecutó y lo que falta está separado sin ambigüedad en
`docs/07-PRUEBAS-DE-ACEPTACION.md`.

---

## Aviso importante antes de venderlo

**LibreDTE Slim no tiene versión estable publicada.** El único tag del
repositorio `LibreDTE/libredte-app-slim` es **`v0.1.0b1`**: una *beta*. No hay
releases. Se instala igual porque es lo que hay, y ese es un riesgo que hay que
decirle al cliente antes de cotizar, no después.

Además, con la opción gratuita (Slim + Core API local):

- **No se pueden enviar boletas al SII** (todos los demás documentos, sí).
- **No incluye soporte**: el soporte de la plataforma se cotiza aparte con
  LibreDTE (SASCO SpA). Ver `docs/08-SERVICIOS-COMERCIALES.md`.
- **La API REST de esta versión es de solo lectura**: sirve para consultar datos,
  **no para emitir**. Hay que decirlo explícitamente, porque la tabla de
  comparación de LibreDTE sugiere lo contrario. Ver `docs/09-EXPORTACION-O-TRASPASO.md`.

---

## Qué es este kit

**Es un kit de despliegue, no el código de la aplicación.**

- **Viene de upstream (LibreDTE, AGPL-3.0):** el stack Docker completo tal cual
  está publicado — `compose.yaml`, `scripts/`, `overrides/`, `config/caddy/`,
  `COPYING` y el README original. Archivos **sin modificar**, con su SHA-256 en
  `VERSION.md`. La app **no se distribuye acá**: se baja como imagen Docker desde
  `ghcr.io`.
- **Es de Hefesto Studio:** `compose.hefesto.yaml`, `scripts/backup-hefesto.sh`,
  `.env.example`, toda la carpeta `docs/`, `ejemplos/` y los archivos de raíz.
  Son unos pocos cientos de líneas, todas de configuración y respaldos.

**No hay aislamiento entre clientes.** Este kit despliega **una** instancia para
**un** cliente. Nada de lo que hay acá implementa multi-tenancy, y no debe
prometerse: si dos clientes comparten el mismo servidor, cada uno corre su propio
proyecto de Docker Compose separado.

## Requisitos

- Docker Engine 24+ con Compose v2 (2.24+, hace falta para `!reset` en los overrides).
- ~2 GB de disco para imágenes y ~2 GB de RAM.
- Un dominio con DNS apuntando al servidor y **80 y 443 alcanzables** si querés
  que Caddy pida el certificado solo.
- El navegador de quien use Slim necesita salida a `cdn.jsdelivr.net`
  (Bootstrap, Font Awesome y htmx se cargan desde ahí).

## Inicio rápido

```shell
cp .env.example .env
# completa SITE_HOSTNAME, SITE_ADDRESS y DB_PASSWORD (obligatorias)
chmod +x scripts/*.sh
# .env.example trae COMPOSE_FILE=compose.yaml:overrides/puertos.yaml (puertos al host)
docker compose config -q          # si falta algo, el compose no arranca
docker compose up -d
docker compose logs -f setup      # espera "==> Listo"
```

Después: `https://tu-dominio/setup` crea el primer usuario (ver
`docs/04-PRIMERA-CUENTA-Y-USUARIOS.md`).

Paso a paso desde un Ubuntu/Debian limpio: `docs/01-INSTALACION-DOCKER.md`.
Con Coolify: `docs/02-INSTALACION-COOLIFY.md`.

## Qué incluye

| Ruta | Qué es |
|---|---|
| `compose.yaml` | Stack oficial de LibreDTE adaptado a Coolify: sin `name:` fijo ni puertos publicados, con `backup-hefesto` y paradas limpias incluidos |
| `compose.hefesto.yaml` | Override Hefesto, ya fusionado en `compose.yaml` (opcional, mismo resultado) |
| `scripts/backup.sh` | Respaldos oficiales de LibreDTE, sin tocar |
| `scripts/backup-hefesto.sh` | Respaldos Hefesto: manifiesto, SHA-256, restauración validada |
| `scripts/entrypoint.sh`, `lib.sh`, `setup.sh` | Scripts oficiales, sin tocar |
| `overrides/local-dirs.yaml`, `overrides/traefik.yaml` | Overrides oficiales, sin tocar |
| `overrides/puertos.yaml` | Publica los puertos de Caddy (y mailpit) para el uso directo sin Coolify |
| `config/caddy/Caddyfile` | Caddy de upstream, sin tocar |
| `docs/` | 10 documentos + el README original de upstream |
| `ejemplos/` | Plantillas marcadas como DEMOSTRACIÓN |
| `COPYING` | AGPL-3.0 |

### Servicios

`caddy` (la única entrada; publica puertos solo con `overrides/puertos.yaml`), `web`, `worker`, `worker-emision-masiva`,
`libredte-lib-core-api`, `db`, `valkey`, `setup`, y con perfiles: `console`
(tools), `backup` y `backup-hefesto` (ambos de respaldo), `mailpit` (desarrollo).

### Volúmenes: qué se respalda y qué no

| Volumen | Contenido | ¿Se respalda? |
|---|---|---|
| `db_data` | Base de datos PostgreSQL | **Sí** (`pg_dump`) |
| `state` | `SECRET_KEY`, `FIELD_ENCRYPTION_KEY` | **Sí** — sin esto los certificados quedan ilegibles |
| `media` | Logos y archivos subidos | **Sí** |
| `.env` (en el host) | `DB_PASSWORD`, SMTP, tokens | **Sí** |
| `static` | Estáticos que regenera `setup` | No |
| `valkey_data` | Broker y caché | No |
| `caddy_data`, `caddy_config` | Certificados TLS | No (se emiten de nuevo) |
| `emision_masiva` | ZIP de PDF | No (se regeneran) |

Solo `docker compose down -v` borra los volúmenes. Detalle y procedimiento en
`docs/05-RESPALDOS-Y-RESTAURACION.md`.

## Lo que hay que saber sí o sí

1. **`FIELD_ENCRYPTION_KEY` cifra la clave privada de los certificados.** Si se
   pierde, los certificados guardados son ilegibles para siempre. Vive en el
   volumen `state`, que sí se respalda.
2. **`SLIM_SEED_DEMO=1` crea el usuario `demo` con contraseña pública.**
   Prohibido en un servidor. Para pasar de demo a producción hay que empezar de
   volúmenes nuevos (`docker compose down -v`).
3. **Cambiar `DB_PASSWORD` en `.env` después del primer arranque no cambia la
   contraseña dentro de PostgreSQL.** Hay que cambiarla también adentro.
4. **Slim solo acepta el dominio de `SITE_HOSTNAME`** (más `SITE_EXTRA_HOSTS`).
   Cualquier otra cabecera `Host` recibe `400`.
5. **El `.env` nunca lo modifica el stack.** Es de Hefesto y del cliente.
6. **El cliente debe certificarse ante el SII antes de emitir.** Es un trámite
   del cliente, no una función de este kit. Ver `docs/08-SERVICIOS-COMERCIALES.md`.

## Estado honesto

- Escrito y verificado contra fuentes: **sí**.
- Ejecutado con Docker: **no**.
- Probado en un servidor: **no**.
- Pendiente declarado: `docs/07-PRUEBAS-DE-ACEPTACION.md`.

## Despliegue en Coolify (MVP Hefesto)

- Recurso Docker Compose, rama `coolify`, archivo `compose.yaml` **solo**: no se
  declara `COMPOSE_FILE` ni hace falta `compose.hefesto.yaml` ni
  `overrides/traefik.yaml`.
- Dominio asignado al servicio `caddy`, puerto `80`. Ningún servicio publica
  puertos al host; Traefik de Coolify pone el TLS.
- Variables obligatorias (en la interfaz de Coolify): `SITE_HOSTNAME` (dominio sin
  puerto), `SITE_ADDRESS=:80`, `SITE_URL_SCHEMA=https`, `DB_PASSWORD`.
- Versiones: fijar `SLIM_VERSION` y `CORE_API_VERSION` a un tag publicado. Sin
  `SLIM_VERSION` la imagen se construye desde `master` del repositorio de Slim, y
  `CORE_API_VERSION` usa `latest` por defecto.
- `setup` es un job de una sola vez del que dependen `web` y los workers: si
  falla, falla el despliegue.
- El primer usuario se crea en `https://<dominio>/setup/`: hacerlo antes de
  publicar el dominio.
- Los perfiles `backup` y `hefesto` montan `./.env`, que no existe en el clon de
  Coolify: no activar `COMPOSE_PROFILES` ahí sin crear antes ese archivo.
- `mailpit` (perfil de desarrollo) no publica puertos en `compose.yaml`; están en
  `overrides/puertos.yaml`.
- SMTP opcional: sin `EMAIL_HOST`, Slim escribe los correos en el log.
- Verificación del contrato: `bash scripts/coolify-check.sh`.

## Licencias

AGPL-3.0 (aplicación y stack), más Apache-2.0, PostgreSQL License y BSD-3-Clause
para la infraestructura. La capa de Hefesto todavía **no tiene licencia
declarada**: elegirla es parte del trabajo de Hefesto antes de distribuir el kit.
Ver `LICENCIAS.md` y `docs/10-LICENCIAS-Y-FUENTES.md`.

---

Hefesto Studio · Stack oficial de LibreDTE Slim + capa de producción propia.