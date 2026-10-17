# 06 — Actualizaciones y reversión

Este kit corre una **beta**. Tratar las actualizaciones como una operación con
plan de vuelta atrás, no como un `pull && up`.

---

## 1. Reglas antes de tocar nada

1. **Respaldo verificado, no solo generado:**
   ```shell
   docker compose run --rm --no-deps backup-hefesto now
   docker compose run --rm --no-deps backup-hefesto verify <ts>
   ```
2. **Anotar las versiones actuales** (quedan en `.env`):
   `SLIM_VERSION`, `CORE_API_VERSION`, `POSTGRES_VERSION`, `VALKEY_VERSION`,
   `CADDY_VERSION`.
3. **Copia externa del respaldo.** Actualizar y perder el disco en la misma
   semana es un mal día.
4. **Ventana de mantenimiento**, para que no se emita a mitad.

## 2. Actualizar Slim

```shell
# 1) Editar SLIM_VERSION en .env
# 2) Bajar la imagen nueva
docker compose pull
# 3) Levantar; `setup` aplica las migraciones al arrancar
docker compose up -d
docker compose logs -f setup          # esperar "==> Listo"
docker compose ps
```

Sobre los tags:

- `SLIM_VERSION` es el tag de la imagen publicada en `ghcr.io`. Al día de este
  kit el único tag publicado es **`v0.1.0b1`**, una beta.
- Si el tag no se puede descargar, Compose lo avisa y **construye la imagen** desde
  el código de ese tag (tarda varios minutos). Para verlo venir:
  `docker compose pull` primero.
- Con `SLIM_VERSION` **vacío**, la imagen se construye siempre en el servidor
  con el último commit de `master`. **En producción, nunca**: no es una versión
  fija.

## 3. Actualizar la Core API

```shell
docker compose pull libredte-lib-core-api
docker compose up -d
```

`CORE_API_VERSION` está en `latest` porque **el repositorio no publica tags**
(verificado: la lista de tags está vacía). Para dejar de correr `latest`:

```shell
# 1) Saber el commit que te interesa del repo del backend
# 2) Ponerlo en .env como CORE_API_VERSION (40 hexadecimales, el hash del commit)
# 3) LIBREDTE_BACKEND_COMMIT se deriva solo (lo hace scripts/lib.sh)
docker compose pull libredte-lib-core-api
```

**Pendiente de verificar:** que exista imagen publicada para ese hash y que
funcione. Desde este entorno no se pudo hacer un `docker pull`.

## 4. Reconstruir por parches de seguridad

La imagen de Slim corre sobre `python:3.14-slim` con dependencias fijadas. Las
imágenes publicadas no reciben parches del sistema base: para tomarlos hay que
reconstruir.

```shell
docker compose build --pull --no-cache
docker compose up -d
```

Solo tiene sentido con `SLIM_VERSION` vacío (construcción local). Con la versión
fijada a un tag, el tag es inmutable: un parche de Python llega con el **tag
nuevo** de LibreDTE.

## 5. Volver atrás

El plan depende de qué se cambió.

### Cambió `SLIM_VERSION` y ya corrieron migraciones

```shell
docker compose down          # NO con -v: conserva volúmenes
# en .env: SLIM_VERSION=la-anterior
docker compose up -d
```

**Advertencia real:** `setup` ejecuta `manage.py migrate` en cada arranque y las
migraciones de Django **no se revierten solas**. Si la versión nueva aplicó
migraciones que la vieja no entiende, la aplicación puede no arrancar. La
vuelta atrás segura es **restaurar un respaldo hecho antes de actualizar**:

```shell
docker compose stop web worker worker-emision-masiva
docker compose run --rm --no-deps backup-hefesto restore <ts-anterior> --force
docker compose up -d
```

Por eso el respaldo previo no es opcional: es lo que hace posible la reversión.

### Cambió solo la Core API

`setup` no toca migraciones de la app, pero el backend maneja los catálogos y el
timbre. Si la versión nueva falla:

```shell
# en .env: CORE_API_VERSION=el-commit-anterior
docker compose pull libredte-lib-core-api
docker compose up -d
```

### Cambió `POSTGRES_VERSION` u otra imagen de infraestructura

**No recomendado.** Una actualización mayor de PostgreSQL puede dejar la base en
un formato que la versión anterior no lee. Si hay que hacerlo: respaldo,
actualización, y `restore` si algo falla.

## 6. Qué migraciones no son reversibles

No se hizo un análisis del historial de migraciones del repositorio de la app, así
que **no se puede afirmar qué migraciones son reversibles y cuáles no**.

Lo que sí se sabe, por cómo funciona Django:

- `migrate` **no tiene** reversión automática. Sin un `migrate app <número>` escrito
  a mano, la base queda en la versión más alta aplicada.
- Una migración que **borra columnas o tablas** es, por definición, irreversible
  en la práctica: volver el código atrás no devuelve los datos.
- La propia app **no publica un changelog** en el repositorio verificado, así que
  no hay forma de saber de antemano qué trae el tag siguiente. Hay que leer el
  código del tag nuevo:
  ```shell
  git clone --branch <tag> https://github.com/LibreDTE/libredte-app-slim.git
  # revisar apps/*/migrations/
  ```

**Pendiente declarado** en `07-PRUEBAS-DE-ACEPTACION.md`.

## 7. Actualizar el kit de Hefesto

El kit son archivos: `compose.yaml`, `scripts/`, `overrides/`, `config/`. Para
actualizar a una versión nueva de LibreDTE upstream hay que **re-copiar esos
archivos** y comparar, porque el `compose.yaml` upstream cambia entre versiones.

El orden recomendado:

```shell
# 1) respaldo
docker compose run --rm --no-deps backup-hefesto now

# 2) traer los archivos nuevos del upstream y COMPARAR antes de reemplazar
diff -u compose.yaml /ruta/al/compose.yaml.nuevo
diff -u scripts/ /ruta/al/scripts.nuevos/

# 3) reemplazar solo lo que cambió, y recalcular los SHA-256 (VERSION.md)
# 4) docker compose config -q
# 5) docker compose up -d
```

**No borres ni reemplaces `scripts/backup-hefesto.sh` ni `compose.hefesto.yaml`:
son de Hefesto**, no vienen del upstream.

## 8. Checklist de actualización

- [ ] Respaldo generado **y verificado**.
- [ ] Copia externa del respaldo.
- [ ] Versiones actuales anotadas.
- [ ] `.env` guardado aparte.
- [ ] Ventana de mantenimiento; sin emisiones en curso.
- [ ] `docker compose config -q` pasa antes del `up`.
- [ ] `setup` terminó con `==> Listo`.
- [ ] Login, emisión de prueba y descarga de PDF funcionando.
- [ ] `/setup/` sigue cerrado y no hay usuarios nuevos sospechosos.