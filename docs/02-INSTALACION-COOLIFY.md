# 02 — Instalación con Coolify

Coolify despliega este kit como un recurso **Docker Compose**. La diferencia
importante con la instalación directa: **Coolify pone su propio proxy (Traefik)
delante**, así que el dominio, el certificado y el HTTPS los maneja Coolify, no
Caddy.

> **Estado:** no se probó en una instancia real de Coolify desde el entorno donde
> se preparó el kit. Lo que se afirma acá sale de los requisitos del propio stack
> (que Caddy acepta HTTP plano detrás de un proxy y que solo Caddy publica
> puertos) y de la documentación de Coolify (<https://coolify.io/docs>). **Los
> nombres exactos de los campos de la interfaz pueden variar según la versión de
> Coolify**: confirmarlos en pantalla. Queda como pendiente en
> [`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md).

---

## 1. Antes de empezar

Coolify **sí sirve** para este kit, pero con dos condiciones:

1. Hay que dejar de pedirle a Caddy un certificado propio: Coolify ya termina el
   TLS. Si no, los dos proxies pelean por el mismo puerto.
2. El despliegue depende de que el job `setup` termine bien. Si `setup` falla,
   Coolify marca el despliegue como fallido y `web` no arranca nunca.

## 2. Crear el recurso

1. **New Resource → Public Repository** (o *Add Resource → Docker Compose* si
   preferís pegar el contenido).
2. Repositorio: el que contenga este kit, rama `coolify`.
3. Archivo compose: `compose.yaml`, **solo**.

No hace falta `COMPOSE_FILE`: `compose.yaml` ya incluye `backup-hefesto` y las
paradas limpias de `compose.hefesto.yaml`, no publica puertos y no fija `name:`
(Coolify pone el nombre del proyecto). No declares `COMPOSE_FILE` en la interfaz.

## 3. Variables de entorno

Cargalas en la interfaz del recurso. Obligatorias:

| Variable | Valor |
|---|---|
| `SITE_HOSTNAME` | El dominio, **sin puerto** (p. ej. `facturacion.ejemplo.cl`) |
| `SITE_ADDRESS` | `:80` — Coolify ya se encarga del TLS |
| `SITE_URL_SCHEMA` | `https` |
| `DB_PASSWORD` | Una generada, no una de ejemplo |

Generá la contraseña con `openssl rand -base64 32` **en el servidor o en tu
equipo**, no acá.

`SLIM_SEED_DEMO` debe quedar en `0`. Fijá también `SLIM_VERSION` y
`CORE_API_VERSION` a un tag publicado. No declares `COMPOSE_PROFILES=hefesto`
hasta tener el `.env` en disco (ver §6).

**Cuidado con `SITE_EXTRA_HOSTS`:** cada host extra es una puerta adicional
aceptada por Slim. En Coolify basta con el dominio principal.

## 4. Publicar el sitio (el punto delicado)

Solo `caddy` puede recibir tráfico. En el recurso, asigná el dominio **al
servicio `caddy`, puerto 80**, y **no publiques el puerto en el host**.

`compose.yaml` no publica puertos de ningún servicio, así que no hace falta
`overrides/traefik.yaml` ni declarar la red del proxy: Coolify conecta `caddy` a
su Traefik y enruta el dominio a `caddy:80`. Para comprobarlo en el servidor:

```shell
docker compose config --format json | jq '[.services[] | select(.ports != null)] | length'   # 0
```

`overrides/puertos.yaml` es solo para el uso directo sin Coolify: no lo actives acá.

## 5. Volúmenes y persistencia

Coolify permite declarar volúmenes en el recurso. **Recomendación: usá
`overrides/local-dirs.yaml`** para que los datos queden en directorios del host,
que sobreviven a un redeploy y a un `down -v`:

```
COMPOSE_FILE=compose.yaml:compose.hefesto.yaml:overrides/local-dirs.yaml
DATA_DIR=./data
```

Si usas volúmenes nombrados (sin ese override), ten presente que Coolify puede
recrear los contenedores pero los volúmenes nombrados sobreviven; aun así, un
`docker compose down -v` en una operación de mantenimiento los borra.

## 6. El detalle que seOlvida: el archivo `.env` en disco

Los servicios de respaldo montan el `.env` del host como archivo:

```yaml
- ./.env:/host/.env:ro
```

Si ese archivo no existe, Docker crea un **directorio** en ese lugar y el
respaldo falla al copiarlo. Con Coolify las variables viven en la interfaz, pero
**el archivo tiene que estar igual** en el directorio del despliegue, con los
mismos valores. Sin eso, `backup-hefesto` y `backup` no respaldan nada.

Es el mismo `.env` que está en `.gitignore`: nunca va al repositorio.

## 7. Primer despliegue

1. Deploy.
2. Seguir los logs del servicio `setup` hasta `==> Listo`. Si falla, el
   despliegue falla: es el comportamiento esperado, no un bug.
3. Entrar a `https://el-dominio/setup/` y crear el primer usuario.

## 8. Healthchecks

Los healthchecks del compose upstream son los que Coolify usa para saber si el
despliegue está sano:

| Servicio | Healthcheck |
|---|---|
| `db` | `pg_isready -U $POSTGRES_USER -d $POSTGRES_DB` |
| `valkey` | `valkey-cli ping` |
| `libredte-lib-core-api` | `curl -fsS http://127.0.0.1/docs.html` |
| `web` | `python -c urllib.request.urlopen('http://127.0.0.1:8000/health/')` |
| `caddy` | `wget -q -O /dev/null http://127.0.0.1:8080/health/` |
| `worker`, `worker-emision-masiva` | `grep -q celery /proc/1/cmdline` |
| `backup`, `backup-hefesto` | su propio script, comando `health` |

Si un servicio queda en `starting` por mucho tiempo, el primer sospechoso es el
dominio: `SITE_HOSTNAME` distinto del configurado en Coolify hace que Slim
responda `400` a la verificación.

## 9. respaldos en Coolify

```shell
docker compose run --rm --no-deps backup-hefesto now
```

La copia externa del respaldo es **responsabilidad del servidor**, no de Coolify:
si el volumen `backups` vive en el mismo VPS, no protege de perder el VPS.

Detalle en [`05-RESPALDOS-Y-RESTAURACION.md`](05-RESPALDOS-Y-RESTAURACION.md).

## 10. Si el kit no sirve en Coolify

Vuelve a la instalación directa
([`01-INSTALACION-DOCKER.md`](01-INSTALACION-DOCKER.md)) con `docker compose`.
No es un paso atrás: es la vía en la que upstream declara haber probado todo el
stack.

## 11. Checklist de cierre

- [ ] El dominio abre con TLS válido (certificado emitido por Coolify).
- [ ] `docker compose ps` sin puertos públicos de `db`, `valkey` ni `caddy`.
- [ ] `SITE_ADDRESS=:80` y `SITE_URL_SCHEMA=https`.
- [ ] `.env` presente **en disco** en el directorio del despliegue.
- [ ] `setup` terminó con `==> Listo` y `web` está `healthy`.
- [ ] Primer usuario creado desde `/setup/`.
- [ ] Un respaldo generado y copiado fuera del servidor.