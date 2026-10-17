# ejemplos/ — plantillas de demostración

> **Todo lo que hay en esta carpeta es de DEMOSTRACIÓN.**
> Ningún valor es un secreto real: son marcadores públicos de ejemplo.
> **Nada de acá se copia tal cual a un servidor.**

| Archivo | Qué es | Estado |
|---|---|---|
| `01-env.desarrollo-local.ejemplo.txt` | Copia de la plantilla `.env.example` **de desarrollo** de LibreDTE (con perfil `mailpit`, datos de prueba) | Upstream, con aviso agregado |
| `02-env.produccion.upstream.ejemplo.txt` | Copia de la plantilla `.env.prod.example` **de LibreDTE** (sin datos de prueba, SMTP opcional) | Upstream, con aviso agregado |
| `03-consola-django.ejemplo.txt` | Cheatsheet de `manage.py` para el perfil `console` | Escrito por Hefesto |
| `04-consulta-api.ejemplo.txt` | Consultas de **solo lectura** a la API, con token de ejemplo | Escrito por Hefesto |
| `05-override-supabase.ejemplo.txt` | Override para apuntar a un PostgreSQL externo (**NO VERIFICADO**) | Escrito por Hefesto |
| `06-respaldo-programado.ejemplo.txt` | Cómo programar los respaldos desde el cron del host | Escrito por Hefesto |

## Para desplegar de verdad

Usá el **`.env.example` de la raíz del kit**, que es la plantilla de producción de
Hefesto Studio. Las plantillas de acá están para leer y comparar, no para copiar.

```shell
cp .env.example .env
chmod 600 .env
```

## Sobre los dos archivos de upstream

`01` y `02` son copias literales de las plantillas que publica LibreDTE en
<https://github.com/LibreDTE/libredte-docker-slim>, con un aviso al principio.
Se conservan para poder compararlas con el `.env` que Hefesto propose y ver qué
cambió, sin depender de la red.

- `01` es la de **desarrollo**: trae `SLIM_SEED_DEMO=1` y el perfil `mailpit`.
  **Nunca en un servidor.**
- `02` es la de **producción de LibreDTE**. Hefesto usa la propia porque separa
  mejor las secciones y advierte sobre `DB_PASSWORD` y `FIELD_ENCRYPTION_KEY`.

Ambas usan `COMPOSE_FILE=compose.yaml` solamente. Este kit agrega la capa Hefesto
con `compose.yaml:compose.hefesto.yaml`.

## Nunca hacer

- Subir un `.env` real a git, a un ticket o a un chat.
- Usar las contraseñas de ejemplo.
- Activar `mailpit` en producción: deja los correos del cliente a la vista en el
  servidor.
- Dejar `SLIM_SEED_DEMO=1` en un servidor.