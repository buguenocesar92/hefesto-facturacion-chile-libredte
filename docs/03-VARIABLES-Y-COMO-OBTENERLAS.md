# 03 — Variables de entorno y cómo obtenerlas

Todas las variables que el stack lee, de dónde salen y qué pasa si se cambian
después. Fuente: `compose.yaml` y `.env.prod.example` del upstream, y
`config/settings.py` de la app (tag `v0.1.0b1`).

**El `.env` nunca lo modifica el stack.** Es tuyo: si algo se sobrescribe solo,
eso es un bug.

---

## Generar los secretos

```shell
# Contraseña de PostgreSQL
openssl rand -base64 32

# SECRET_KEY (firma sesiones y cookies)
python3 -c "import secrets; print(secrets.token_urlsafe(64))"

# FIELD_ENCRYPTION_KEY (clave Fernet: 32 bytes en base64 urlsafe)
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Los dos últimos también los genera `setup` solo la primera vez y los deja en el
volumen `state`. Fijarlos a mano es opcional.

---

## Obligatorias

El compose upstream las declara con `${VAR:?mensaje}`: **no arranca** si faltan.

| Variable | Ejemplo | De dónde sale | Qué pasa si la cambias después |
|---|---|---|---|
| `SITE_HOSTNAME` | `facturacion.ejemplo.cl` | El dominio que escribe el usuario en el navegador | Slim responde `400` a peticiones con otra cabecera `Host`. Hay que actualizar también Coolify/Traefik y esperar el redeploy |
| `SITE_ADDRESS` | `facturacion.ejemplo.cl` | El mismo dominio (Caddy pide el certificado solo) o `:80` detrás de otro proxy | Caddy deja de pedir certificado y pasa a escucha plana; reiniciar el contenedor |
| `DB_PASSWORD` | `openssl rand -base64 32` | La generas | **No cambia la contraseña ya creada dentro de PostgreSQL.** Hay que cambiarla también adentro (ver abajo) |

### Cómo cambiar la contraseña de la base de verdad

```shell
docker compose exec db psql -U libredte_slim -d postgres -c "\password libredte_slim"
docker compose exec db psql -U libredte_slim -d postgres \
  -c "ALTER ROLE libredte_slim WITH PASSWORD 'NUEVA';"
```

Después actualizar `DB_PASSWORD` en `.env` y `docker compose up -d`. El `\password`
pide la clave de forma interactiva; en un servidor sin TTY conviene usar solo el
`ALTER ROLE`, asumiendo que queda en el historial de la shell. Después hay que
recrear los servicios que usan la base, porque no detectan el cambio solas:

```shell
docker compose up -d --force-recreate web worker worker-emision-masiva setup
```

## Sitio y TLS

| Variable | Por defecto | Qué hace | Qué pasa si la cambias |
|---|---|---|---|
| `SITE_URL_SCHEMA` | `https` en producción | `http` o `https` para armar enlaces y `CSRF_TRUSTED_ORIGINS` | Los enlaces quedan con el esquema equivocado |
| `SITE_EXTRA_HOSTS` | vacío | Hosts adicionales separados por espacio | **Cada host extra es una puerta más.** Revisar antes de agregar |
| `HTTP_BIND` | `127.0.0.1` | Interfaz donde Caddy publica puertos | Cambiar a `0.0.0.0` expone el sitio en todas las interfaces |
| `HTTP_PORT` | `80` | Puerto HTTP del host | Debe coincidir con el proxy de adelante |
| `HTTPS_PORT` | `443` | Puerto HTTPS/443 (TCP y UDP) del host |idem |
| `UPLOAD_MAX_SIZE` | `32M` | Tope de subida (planillas, certificados, logos) | Subir planillas grandes falla con error de tamaño |
| `SLIM_SEED_DEMO` | `0` | `1` crea el usuario `demo` / `Slim123%` | **Nunca en servidor.** Pasar a producción con demo exige `docker compose down -v` |

## Secretos de la aplicación

| Variable | Default | Dónde vive realmente | Qué pasa si la cambias |
|---|---|---|---|
| `SECRET_KEY` | la genera `setup` | Volumen `state` (`secrets.env`), o `.env` | Se cae la sesión abierta; los tokens de API siguen válidos |
| `FIELD_ENCRYPTION_KEY` | la genera `setup` | Volumen `state` (`secrets.env`), o `.env` | **`setup` falla a propósito** si el valor de `.env` no coincide con el registrado. Los certificados guardados quedan ilegibles |

**`FIELD_ENCRYPTION_KEY` es la más importante de todas.** Cifra la clave privada de
los certificados digitales. Si se pierde, los certificados guardados **no se pueden
leer nunca más**. Está en los respaldos: si el volumen `state` se pierde y no hay
respaldo, hay que volver a cargar todos los certificados en Slim.

Procedimiento de rotación (el del upstream): los certificados guardados quedan
inservibles y hay que volver a cargarlos.

```shell
docker compose run --rm --no-deps -u root --entrypoint sh setup \
  -c "sed -i '/^FIELD_ENCRYPTION_KEY=/d' /var/lib/slim/state/secrets.env"
# agregar la nueva clave a .env y luego:
docker compose up -d
```

## Correo

Sin `EMAIL_HOST`, Slim **no envía correos**: los escribe en el log. Afecta al
resultado de la emisión masiva y a la recuperación de contraseña.

| Variable | Notas |
|---|---|
| `EMAIL_HOST` | Servidor SMTP. Sin él, correo solo al log |
| `EMAIL_PORT` | Si se omite, se deduce de SSL/TLS |
| `EMAIL_USE_SSL` / `EMAIL_USE_TLS` | 465/SSL o 587/STARTTLS, no ambos |
| `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` | Credenciales SMTP |
| `DEFAULT_FROM_EMAIL` | Si no se define, se usa `EMAIL_HOST_USER` |

## Servicios externos de LibreDTE (opcionales)

| Variable | Para qué |
|---|---|
| `PLUGIN_APIGATEWAYCL_API_URL`, `PLUGIN_APIGATEWAYCL_API_TOKEN` | Cuenta de <https://www.apigateway.cl> para consultas al SII (catálogos, CAF). **Es un servicio de pago de LibreDTE, no viene incluido.** Sin token, esas consultas no están disponibles |
| `PLUGIN_LIBREDTE_BACKEND_API_TOKEN` | La Core API del stack no pide token. Solo si se apunta a otra que lo exija |

## Perfiles, overrides y respaldos

| Variable | Default | Qué hace |
|---|---|---|
| `COMPOSE_PROFILES` | vacío | Perfiles separados por coma: `backup`, `hefesto`, `tools`, `mailpit` |
| `COMPOSE_FILE` | `compose.yaml` | Lista de archivos separados por `:`. En este kit: `compose.yaml:compose.hefesto.yaml` |
| `DATA_DIR` | `./data` | Solo con `overrides/local-dirs.yaml` |
| `BACKUP_INTERVAL_HOURS` | `24` | Frecuencia de los respaldos |
| `BACKUP_KEEP_DAYS` | `30` en Hefesto (7 en upstream) | Retención |

**Ojo con los perfiles:** `mailpit` es solo para desarrollo y publica un buzón
web. Nunca activarlo en producción.

## Versiones

| Variable | Default | Nota |
|---|---|---|
| `SLIM_VERSION` | `v0.1.0b1` | **Es una beta.** Único tag publicado. Cambiarla exige `docker compose pull` y `up -d`; `setup` aplica las migraciones |
| `SLIM_REPO` | repo oficial | Solo para construir cuando no se puede bajar la imagen |
| `CORE_API_VERSION` | `latest` | El backend **no publica tags**. Se puede fijar al hash de 40 hexadecimales de un commit |
| `LIBREDTE_BACKEND_COMMIT` | vacío | Se deriva del anterior si es un hash completo |
| `POSTGRES_VERSION`, `VALKEY_VERSION`, `CADDY_VERSION`, `MAILPIT_VERSION` | `18`, `9.2`, `2.11`, `v1.31` | Fijadas; nunca `latest` |

Detalle y digest en `VERSION.md`.

## Ajustes y límites

`TZ` (por defecto `America/Santiago`), `LOG_LEVEL`, `LOG_MAX_SIZE`, `LOG_MAX_FILE`,
`WEB_WORKERS`, `WEB_THREADS`, `WORKER_CONCURRENCY`,
`WORKER_EMISION_MASIVA_CONCURRENCY`, y los límites de memoria
(`DB_MEMORY_LIMIT`, `VALKEY_MEMORY_LIMIT`, `CORE_API_MEMORY_LIMIT`,
`SETUP_MEMORY_LIMIT`, `WEB_MEMORY_LIMIT`, `WORKER_MEMORY_LIMIT`,
`WORKER_EMISION_MASIVA_MEMORY_LIMIT`, `CADDY_MEMORY_LIMIT`, `CONSOLE_MEMORY_LIMIT`,
`BACKUP_MEMORY_LIMIT`).

Los límites de memoria **suman el tope real**: subirlos todos es fácil, pero si
el VPS no tiene la RAM, el sistema operativo mata contenedores. La suma por
defecto es ~7 GB: un VPS de 2 GB tiene que ajustarlos a la baja.

## Variables que el compose fija y no conviene tocar

Estas están en el `compose.yaml` upstream con valores fijos, no tomados del `.env`:

| Variable | Valor fijo | Por qué |
|---|---|---|
| `DB_HOST` | `db` | Apunta al servicio interno de PostgreSQL |
| `DB_PORT` | `5432` | Puerto interno |
| `DB_ENGINE` | `postgresql` | Slim no soporta otros motores en este stack |
| `CELERY_BROKER_URL` | `redis://valkey:6379/0` | Broker interno |
| `PLUGIN_LIBREDTE_BACKEND_API_URL` | `http://libredte-lib-core-api/api` | Backend del stack |
| `SITE_BEHIND_PROXY` | `1` | Siempre hay Caddy delante |
| `DEBUG` | `0` | Nunca en producción |
| `FORWARDED_ALLOW_IPS` | `*` en `web` | Solo Caddy alcanza a gunicorn, en la red interna |

> **Consecuencia práctica:** mover la base a un PostgreSQL externo (por ejemplo
> Supabase) exige **un override propio** que cambie `DB_HOST` y `DB_PORT`. No se
> puede con solo variables de entorno. Ver `docs/09-EXPORTACION-O-TRASPASO.md`.