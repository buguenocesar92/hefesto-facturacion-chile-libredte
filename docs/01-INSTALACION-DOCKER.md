# 01 — Instalación con Docker (VPS Ubuntu/Debian)

Paso a paso desde un servidor Ubuntu o Debian recién instalado, usando el stack
oficial de LibreDTE más la capa de Hefesto. Para Coolify, ver
[`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md).

> **Estado:** este procedimiento **no se ejecutó** en un servidor desde el entorno
> donde se preparó el kit (no hay Docker ni VPS ahí). Los comandos del stack son
> los del upstream, verificados leyendo su `README.md` y `compose.yaml`; los de
> instalación de Docker son los documentados por Docker. La ejecución real está
> pendiente en [`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md).

---

## 1. Requisitos del servidor

- Ubuntu 22.04+ o Debian 12+.
- 2 GB de RAM (en reposo el stack usa poco más de 1 GB) y ~2 GB de disco libre
  para las imágenes.
- Un dominio con registro DNS apuntando a la IP del servidor.
- Puertos **80 y 443 TCP** (y 443 UDP, para HTTP/3) abiertos. Sin eso, Caddy no
  puede obtener el certificado de Let's Encrypt.
- Docker Engine 24+ con Compose v2 **2.24+**: el override `overrides/traefik.yaml`
  usa `!reset`, que requiere esa versión.

## 2. Instalar Docker

Según la documentación oficial de Docker
(<https://docs.docker.com/engine/install/ubuntu/> y
<https://docs.docker.com/engine/install/debian/>):

```shell
# Ubuntu: desinstalar versiones conflictivas si las hubiera
sudo apt-get remove docker docker-engine docker.io containerd runc || true

# Docker y sus dependencias
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Repositorio oficial
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

En Debian, cambiar `ubuntu` por `debian` en las dos URLs.

Comprobar:

```shell
sudo docker --version
sudo docker compose version   # debe ser >= 2.24
```

## 3. Poner el kit en el servidor

```shell
sudo mkdir -p /opt/libredte-slim && sudo chown "$USER":"$USER" /opt/libredte-slim
cd /opt/libredte-slim

# copiar el kit (desde el equipo o con git)
# <copiar aquí el contenido del kit>

chmod +x scripts/*.sh
```

Los scripts quedan ejecutables: en un `zip` o al copiarlos por FTP se puede
perder el permiso. Si es un repositorio git, `git update-index --chmod=+x
scripts/*.sh` lo deja fijo.

## 4. Configurar

```shell
cp .env.example .env
chmod 600 .env          # contiene DB_PASSWORD y tokens SMTP
```

Obligatorias, sin las cuales compose se niega a arrancar:

| Variable | Ejemplo | De dónde sale |
|---|---|---|
| `SITE_HOSTNAME` | `facturacion.ejemplo.cl` | El dominio que el cliente va a escribir en el navegador |
| `SITE_ADDRESS` | `facturacion.ejemplo.cl` | Lo mismo, para que Caddy pida el certificado solo |
| `DB_PASSWORD` | `openssl rand -base64 32` | Generarla en el servidor |

En `.env.example` ya vienen los puertos de Caddy al host y el perfil de Hefesto
(`backup-hefesto` ya está en `compose.yaml`):

```
COMPOSE_FILE=compose.yaml:overrides/puertos.yaml
COMPOSE_PROFILES=hefesto
```

Sin `overrides/puertos.yaml`, Caddy no publica puertos y el sitio no se ve desde
fuera. Para servir 80/443 directamente: `HTTP_BIND=0.0.0.0`, `HTTP_PORT=80`,
`HTTPS_PORT=443`.

Detalles de cada variable en
[`03-VARIABLES-Y-COMO-OBTENERLAS.md`](03-VARIABLES-Y-COMO-OBTENERLAS.md).

## 5. Validar antes de arrancar

```shell
docker compose config -q && echo "configuración válida"
```

Este comando falla si falta una obligatoria. Es el control más barato que hay:
después de cambiar `.env`, correrlo siempre antes de `up`.

## 6. Arrancar

```shell
docker compose up -d
docker compose logs -f setup      # esperar "==> Listo"
```

El primer arranque tarda varios minutos: baja las imágenes de `ghcr.io` y crea
la base. `setup` hace, en orden: dueños de volúmenes, secretos, migraciones,
estáticos para Caddy y catálogos del SII. Los mensajes "ya hay … cargados, no
se hizo nada" en las corridas siguientes son normales.

Con `--force` en `worker-emision-masiva` no: no es una opción de compose, es el
nombre del servicio. Para ver el estado:

```shell
docker compose ps
docker compose logs -f web worker
```

## 7. Primer usuario

Con `SLIM_SEED_DEMO=0` (lo que trae la plantilla), al entrar a
`https://tu-dominio/` el middleware `RequireInitialUserMiddleware` de Slim
redirige a `/setup/` porque la base no tiene ningún usuario. Ahí se crea el
**primer usuario, que además queda como staff y superusuario**.

**Esa pantalla se cierra sola**: apenas existe un usuario, `/setup/` deja de
servir el alta. Procedimiento completo y qué hacer si se filtró, en
[`04-PRIMERA-CUENTA-Y-USUARIOS.md`](04-PRIMERA-CUENTA-Y-USUARIOS.md).

## 8. Correo (recomendado hacerlo antes de emitir en serio)

Sin `EMAIL_HOST`, Slim **no envía correos**: los escribe en el log. Y se necesitan
para el resultado de la emisión masiva y la recuperación de contraseña.

```shell
EMAIL_HOST=smtp.tuservidor.cl
EMAIL_PORT=465
EMAIL_USE_SSL=1
EMAIL_USE_TLS=0
EMAIL_HOST_USER=facturacion@ejemplo.cl
EMAIL_HOST_PASSWORD=...
DEFAULT_FROM_EMAIL=facturacion@ejemplo.cl
```

## 9. Persistencia: activar `local-dirs` antes de arrancar

Recomendado: que los datos queden en directorios del host, que un
`down -v` **no** borra. Hay que activarlo **antes** del primer arranque; los
datos que ya estén en volúmenes nombrados no se mueven solos.

```
COMPOSE_FILE=compose.yaml:overrides/puertos.yaml:overrides/local-dirs.yaml
DATA_DIR=./data
```

## 10. Primer respaldo

```shell
docker compose run --rm --no-deps backup-hefesto now
docker compose run --rm --no-deps backup-hefesto list
```

**Copiá los respaldos fuera del servidor.** Un respaldo que vive en el mismo
VPS no protege de la pérdida del VPS. Ver
[`05-RESPALDOS-Y-RESTAURACION.md`](05-RESPALDOS-Y-RESTAURACION.md).

## 11. Differences con Coolify

Si se despliega con Coolify, el dominio, el proxy inverso y los certificados los
gestiona Coolify, no Caddy. En ese caso:

- `SITE_ADDRESS=:80` y `SITE_URL_SCHEMA=https`.
- Caddy **no** publica puertos del host: se usa `compose.yaml` solo, sin
  `overrides/puertos.yaml`, y Coolify enruta el dominio a `caddy:80`.
- Coolify gestiona los `.env` desde su interfaz; el `.env` del host no es el que
  se lee.

Detalle en [`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md).

## 12. Checklist de cierre

- [ ] `docker compose ps` muestra todo `healthy` o `running`.
- [ ] `https://tu-dominio/` carga con TLS válido y redirige a `/setup/`.
- [ ] `curl -sI https://tu-dominio/health/` responde sin error.
- [ ] `SLIM_SEED_DEMO=0` en `.env`.
- [ ] `.env` con permisos `600`, fuera de git.
- [ ] `BACKUP_KEEP_DAYS` y `BACKUP_INTERVAL_HOURS` a gusto, con copia externa.
- [ ] Un respaldo **probado a restaurar**, no solo generado.
- [ ] El cliente tiene claro que debe certificarse ante el SII.