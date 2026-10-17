# 05 — Respaldos y restauración

Hay **dos** sistemas de respaldo en este kit y conviene no confundirlos:

| | `backup` (upstream) | `backup-hefesto` (Hefesto) |
|---|---|---|
| Perfil | `backup` | `hefesto` |
| Script | `scripts/backup.sh` (original de LibreDTE, sin tocar) | `scripts/backup-hefesto.sh` |
| Artefactos | dump, tar.gz, `.env` | lo mismo **+ manifiesto JSON + SHA-256 + marcador de completitud** |
| Verificación antes de restaurar | no | **sí**: SHA-256 de cada artefacto y del manifiesto |
| Restaura sobre destino ocupado | sí, con `dropdb --force` | **se niega**, salvo `--force` explícito |
| Valida rutas del tar (path traversal) | no | **sí** |
| Detecta escritores conectados | no | **sí**: refuses si hay conexiones activas |
| Queda detenido al terminar | no | **sí** |

**Recomendación: activar los dos** (`COMPOSE_PROFILES=backup,hefesto`). Son
independientes y el de upstream es la referencia conocida por el equipo del
cliente. Nunca usan el mismo directorio de salida.

---

## 1. Qué es persistente

| Volumen / ruta | Contenido | ¿Se respalda? |
|---|---|---|
| `db_data` (o `./data/db`) | Base PostgreSQL | **Sí** — `pg_dump`, formato custom |
| `state` (o `./data/state`) | `secrets.env`: `SECRET_KEY` y `FIELD_ENCRYPTION_KEY` | **Sí** |
| `media` (o `./data/media`) | Logos y archivos subidos | **Sí** |
| `.env` del host | `DB_PASSWORD`, SMTP, tokens de servicios | **Sí** |
| `emision_masiva` (o `./data/emision_masiva`) | ZIP de PDF de la emisión masiva | No — se regeneran |
| `static` (o `./data/static`) | Estáticos que produce `setup` | No — `setup` los regenera en cada `up` |
| `valkey_data` (o `./data/valkey`) | Broker de Celery y caché | No — es caché y cola |
| `caddy_data`, `caddy_config` | Certificados TLS | No — se vuelven a emitir |

## 2. Qué NO se respalda y por qué

- **`emision_masiva`**: los ZIP de la emisión masiva son regenerables. Copiarlos
  multiplica el tamaño del respaldo sin agregar nada recuperable.
- **`static`**: `setup` los reconstruye con `collectstatic` en cada arranque.
- **`valkey_data`**: perderlo solo cancela tareas en vuelo y caché.
- **`caddy_data`**: el certificado se vuelve a pedir. Copiarlo a la fuerza puede
  causar problemas con los límites de emisión de Let's Encrypt.

## 3. Cómo obtener una copia coherente

`pg_dump` toma un snapshot consistente por sí solo: no hace falta detener la
base. Lo que sí importa es la coherencia **entre** la base y `state`/`media`:

- `pg_dump` y `tar` corren en paralelo en el script. El riesgo real es que un
  certificado se suba **entre** el `pg_dump` y el `tar`: la copia tendría el
  certificado cifrado con una clave que todavía no está en el tar.

**Para responder a eso:**

```shell
# Ventana de mantenimiento: nada se emite ni se sube nada
docker compose stop web worker worker-emision-masiva
docker compose run --rm --no-deps backup-hefesto now
docker compose up -d web worker worker-emision-masiva
```

Con la capa Hefesto, `stop_grace_period` hace que un contenedor **termine** lo que
está haciendo en vez de que lo corten: `web` y `worker` tienen 5 minutos,
`worker-emision-masiva` tiene 30.

Un respaldo diario automático sin ventana es aceptable para el uso diario; para una
migración o un cambio de `FIELD_ENCRYPTION_KEY`, hacer respaldo con la
aplicación detenida.

## 4. Manifiesto y SHA-256

`backup-hefesto` escribe, por respaldo `<ts>`:

```
<ts>-db.dump          base de datos (pg_dump --format=custom)
<ts>-files.tar.gz     media/ y state/
<ts>-env              el .env del host
<ts>-manifest.json    SHA-256 y tamaño de cada artefacto, fecha, host, DB
<ts>-COMPLETE         marcador final, con el SHA-256 del manifiesto
```

- Los archivos se escriben primero con prefijo temporal (`.tmp-`) y recién
  después se publican con su nombre definitivo.
- El marcador `-COMPLETE` se escribe **al final**. **Un respaldo sin marcador no
  existe**: no aparece en `list`, no se puede verificar ni restaurar.
- El SHA-256 del manifiesto va dentro del marcador: si alguien edita el manifiesto
  después, la verificación lo detecta.

```shell
docker compose run --rm --no-deps backup-hefesto list
docker compose run --rm --no-deps backup-hefesto verify 20261016T030000Z
```

`verify` recalcula los SHA-256 y compara con el manifiesto. También comprueba que
el dump sea legible con `pg_dump`/`pg_restore --list`.

> Validado realmente en este kit: `list`, `verify` y `health` se ejecutaron con
> respaldos de prueba (correctos, con artefacto corrupto y con manifiesto
> alterado). La prueba **completa** con PostgreSQL real está pendiente:
> ver `07-PRUEBAS-DE-ACEPTACION.md`.

## 5. Restauración

### Antes

1. **Verificar el respaldo:** `backup-hefesto verify <ts>`.
2. **Copiarlo fuera del servidor** antes de tocar nada, por si la restauración
   sale mal.
3. **Detener la aplicación:**

```shell
docker compose stop web worker worker-emision-masiva caddy
```

`restore` además **lo comprueba**: si hay conexiones activas a la base, se niega y
lo dice. Es el control que evita restaurar con un worker escribiendo encima.

### Restaurar

```shell
docker compose run --rm --no-deps backup-hefesto restore 20261016T030000Z
```

Lo que hace, en orden:

1. Verifica el SHA-256 del manifiesto y de los tres artefactos. **Nada se toca
   si algo no cuadra.**
2. Valida el `tar`: rechaza rutas absolutas, rutas con `..` y enlaces simbólicos o
   duros.
3. Comprueba que no haya escritores conectados.
4. Comprueba que el destino esté vacío. **Si hay datos, se niega** y no borra
   nada:

   ```
   ERROR: El destino tiene datos: la base 'libredte_slim' (42 tablas)
   Nada se sobrescribió. Si de verdad quieres reemplazarlo, repite con --force
   ```

5. Solo entonces repone la base y extrae `media` y `state`, y deja los archivos a
   nombre de `slim` (UID 10001).

### Sobre un destino ocupado

`--force` **sí** borra: hace `dropdb --force` (cierra conexiones abiertas) y
limpia `media` y `state`. **No hay vuelta atrás** y no queda copia de lo que se
borra. Solo con `--force` explícito:

```shell
docker compose run --rm --no-deps backup-hefesto restore <ts> --force
```

**Nunca** automatizar `--force` en un script: el script no lo hace nunca solo.

### El `.env` no se toca

El `.env` del respaldo queda junto a los artefactos (`<ts>-env`) y **no**
reemplaza al del host. Si el `.env` actual se perdió, hay que copiarlo a mano:

```shell
docker compose run --rm --no-deps backup-hefesto list   # ubicar el respaldo
# extraer el .env del volumen backups con las herramientas de Docker que prefieras
cp .env.recuperado .env
chmod 600 .env
```

## 6. El script queda con el servicio detenido

Al terminar, `restore` **no levanta nada**: el script no tiene acceso al socket
de Docker, y a propósito no lo pide. Imprime lo que hay que hacer:

```shell
docker compose up -d setup && docker compose logs -f setup
docker compose up -d web worker worker-emision-masiva caddy
```

Revisa que `/setup/` o el login funcione antes de seguir.

## 7. Secretos que hay que conservar aparte

| Secreto | Dónde | Qué pasa si se pierde |
|---|---|---|
| `FIELD_ENCRYPTION_KEY` | Volumen `state` / `<ts>-files.tar.gz` | **Los certificados guardados son ilegibles para siempre** |
| `SECRET_KEY` | Volumen `state` | Se caen las sesiones; no se pierden datos |
| `DB_PASSWORD` | `.env` / `<ts>-env` | Hay que cambiarla en PostgreSQL también |
| Credenciales SMTP | `.env` / `<ts>-env` | Slim deja de enviar correo y lo escribe al log |
| Tokens de API Gateway / Core API | `.env` / `<ts>-env` | Se pierden las consultas al SII |
| **Clave privada del digital** | También en el SII y en el `.pfx` del cliente | Se puede re-descargar desde el SII |

Los respaldos están en modo `600` (`umask 077`): trátalos como claves privadas.

## 8. Copia fuera del servidor

**Un respaldo en el mismo VPS no es un respaldo.** Copiar a:

- otra máquina o NAS,
- almacenamiento de objetos (S3, Backblaze, Wasabi…),
- un contenedor con retención versionada.

Y **probar la restauración**: un respaldo que nunca se restauró es una hipótesis.

## 9. Límites y qué hacer ante un fallo parcial

- **Espacio en disco**: si `pg_dump` falla a mitad, no queda nada publicable
  (los temporales se limpian) y no hay marcador `-COMPLETE`. El respaldo anterior
  sigue intacto.
- **Fallo durante `restore`**: la base puede quedar a medias. No reintentar a
  ciegas: `verify <ts>` y volver a intentarlo con `--force` desde cero.
- **Restauración cruzada de versión**: no verificada. Si se restaura un respaldo
  de una versión de Slim y se levanta otra, las migraciones pueden no aplicar.
  Levantar **la misma versión** primero.
- **Restaurar a una versión anterior de la aplicación**: ver
  `06-ACTUALIZACIONES-Y-REVERSION.md`; hay migraciones que no son reversibles.
- **Nunca borrar el último respaldo bueno** hasta tener uno nuevo verificado.

## 10. Comandos de referencia

```shell
# Periódicos: el servicio `backup-hefesto` con el perfil `hefesto` ya corre solo
docker compose run --rm --no-deps backup-hefesto now
docker compose run --rm --no-deps backup-hefesto list
docker compose run --rm --no-deps backup-hefesto verify <ts>
docker compose run --rm --no-deps backup-hefesto restore <ts> [--force]
docker compose run --rm --no-deps backup-hefesto health

# los de upstream, sin cambios
docker compose run --rm --no-deps backup now
docker compose run --rm --no-deps backup list
docker compose run --rm --no-deps backup restore <ts>
```

Usar siempre `run --rm --no-deps`: sin `--no-deps` arrancaría `setup`, que
falla con datos dañados.