# 09 — Exportación de datos y traspaso

> **Aviso que va primero, en todas las propuestas:**
> lo que hay en este kit es una **guía de integración contra la API pública**.
> **No es un conector implementado**, **no hay sincronización automática** y
> **no se emitió ni un documento real desde este kit**.

---

## 1. Lo que realmente se puede exportar

| Vía | Formato | Estado | Alcance |
|---|---|---|---|
| API REST `/api/v1/…` | JSON (paginación Tabulator) | **Verificado en el código** | Documentos emitidos, recibidos, borradores, receptores, emisores, ítems, sucursales y resúmenes por período |
| `pg_dump` | Formato custom de PostgreSQL | **Verificado** (lo usa `backup.sh` de upstream) | **Todo**: la base completa, incluidos usuarios, tokens, certificados cifrados y secretos |
| Emisión masiva (entrada) | CSV | **Verificado** (tabla comparativa de LibreDTE) | Es **entrada** para emitir, no salida |

**Lo que NO existe y no hay que prometer:**

- **No hay exportación a Excel/XLSX** en la edición gratuita (solo CSV, y como
  *entrada* de emisión masiva; XLSX viene con Pro/API Gateway/Flex).
- **No se verificó** que exista un botón de "exportar a CSV" en la interfaz. La
  API devuelve JSON; un CSV habría que generarlo a mano desde el JSON.
- **La API no emite.** Ver la sección 3.

### La vía completa de traspaso: `pg_dump`

Es la única que se lleva **todo**, incluidos los secretos. Para traspasar la
instalación completa a otro servidor:

```shell
# En el servidor viejo
docker compose exec -T db pg_dump -U libredte_slim -Fc libredte_slim > slim.dump
docker compose exec -T db tar -C /var/lib/slim -czf - media state > datos.tar.gz
cp .env .env.traspaso        # ¡contiene secretos! Trasporto cifrado, nunca por correo

# En el nuevo: restaurar con backup-hefesto
docker compose run --rm --no-deps backup-hefesto restore <ts>
```

Los secretos van dentro de `state`, así que `tar de media/state + pg_dump` es un
traspaso completo. **`FIELD_ENCRYPTION_KEY` incluida**: sin ella, los certificados
del cliente quedan ilegibles en el servidor nuevo.

---

## 2. La API pública, verificada

Documentación interactiva, servida por la propia aplicación:

- `https://tu-dominio/api/docs/` (Swagger UI)
- `https://tu-dominio/api/redoc/` (ReDoc)
- `https://tu-dominio/api/schema/` (OpenAPI)

El esquema se genera desde el propio código con `drf-spectacular`, así que
**`/api/schema/` es la fuente de verdad**: no hay que confiar en una lista escrita
a mano.

### Autenticación

```http
GET /api/v1/emitidos/ HTTP/1.1
Authorization: Token 9944b09199c62bcf9418ad846dd0e4bbdfc6ee4b
```

- El token se genera en **Mi perfil → API**
  (`/accounts/profile/token/generate/`).
- **Es uno solo por usuario**: generar uno nuevo invalida el anterior al instante.
- Sin token, o con uno inexistente: `401`.
- **El token no pasa por el segundo factor.** Es una contraseña con todo el
  alcance: trátalo como una llave.

### Permisos

Textual de la propia documentación de la app: *"Todos los recursos son del
contribuyente activo: no hay permisos por usuario ni por documento, así que
cualquier token válido ve lo mismo."*

**Cualquier token válido ve todos los datos del contribuyente activo.** No hay
lecturas con alcance parcial.

### Paginación y filtros

Respuesta con el formato de la grilla interna:

```json
{"last_page": 4, "data": [{"...": "..."}]}
```

| Parámetro | Ejemplo | Efecto |
|---|---|---|
| `page` | `page=2` | Página, desde 1 |
| `size` | `size=50` | Filas por página |
| `filter[0][field]` + `filter[0][value]` | `filter[0][field]=receptor&filter[0][value]=sasco` | Filtra (el índice permite encadenar) |
| `sort[0][field]` + `sort[0][dir]` | `sort[0][field]=fecha&sort[0][dir]=desc` | Ordena (`asc`/`desc`) |

Los campos aceptables en `filter` y `sort` son los que documenta cada endpoint y
**no siempre coinciden con los del modelo**: varios son calculados (`receptor`
busca a la vez en razón social y RUT; `tipo` en glosa y código del DTE). Para
saberlo, `/api/schema/`.

### Endpoints registrados en el código

```
/api/v1/emitidos/                    /api/v1/items/
/api/v1/recibidos/                   /api/v1/items/categorias/
/api/v1/borradores/                  /api/v1/items/buscar/
/api/v1/receptores/                  /api/v1/ventas/periodos/
/api/v1/receptores/buscar/           /api/v1/compras/periodos/
/api/v1/emisores/                    /api/v1/compras/documentos/
/api/v1/sucursales/
```

Todos de **solo lectura**.

---

## 3. La limitación que hay que decir antes de cotizar

Textual de `apps/core/api_docs/010-introduccion.md`:

> "Todos los recursos son de **solo lectura** (`GET`). Emitir, confirmar o
> eliminar documentos se hace desde la aplicación web."

Y en `apps/*/api/urls.py` solo hay vistas de listado. **No hay endpoint de
emisión.**

Esto contrasta con la tabla comparativa de LibreDTE, que para "API REST" dice
*"Conecta tu software para emitir documentos"* y le pone visto bueno a Slim +
Core. **Con `v0.1.0b1`, esa capacidad no está en el código publicado.**

**Implicancia práctica:** con esta versión, un WooCommerce u Odoo **no puede
emitir** a través de Slim. Solo puede **consultar** lo emitido.

Alternativas reales, y hay que ofrecerlas con honestidad:

1. **Esperar una versión con escritura** (si aparece). No se puede prometer.
2. **Usar LibreDTE Pro o API Gateway** (servicios externos de pago) con LibreDTE
   Slim: la tabla oficial indica que ambos offering "API REST" para emitir.
3. **Operación manual asistida**: exportar CSV desde el ERP, subirlo a la emisión
   masiva de Slim. Es trabajo humano, no integración.

---

## 4. Guía de integración con WooCommerce u Odoo

> **Esto es una guía. El kit no incluye ni un archivo de integración.**
> Hay que desarrollarlo, probarlo y mantenerlo, y es un proyecto aparte con su
> cotización.

### Ordenadores (WooCommerce)

**Lo viable hoy: lectura.**

```
WooCommerce  --(cron)-->  GET /api/v1/emitidos/   (Authorization: Token …)
                        GET /api/v1/receptores/buscar/
                        GET /api/v1/ventas/periodos/
             --> informe, panel o contraste de datos
```

Guía de implementación:

1. Crear un usuario dedicado en Slim y generar **su** token en el perfil.
2. Guardar el token en el servidor de WooCommerce (nunca en el repositorio, ni
   en el checkout del cliente).
3. Llamar con `curl` desde un cron:
   ```shell
   curl -sS -H "Authorization: Token $SLIM_TOKEN" \
     "https://tu-dominio/api/v1/emitidos/?size=200&sort[0][field]=fecha&sort[0][dir]=desc"
   ```
4. Recorrer páginas con `page=1..last_page` hasta vaciar la cola.
5. **Programar el borrado del token al terminar el proyecto**: cada usuario tiene
   uno solo, y no hay "revocar y crear otro" sin invalidar.

**Lo que NO se puede ofrecer:** "el plugin emite la boleta al cerrar la compra".
No hay endpoint de emisión. Un plugin que lo prometa o va a fallar, o va a
inventar un camino que no existe.

### ERP (Odoo)

**Lo viable hoy: lectura y traspaso manual.**

- Consulta periódica de emitidos/recibidos/ítems para reportes o conciliación.
- Para migrar **histórico**: `pg_dump` o lectura masiva de la API y carga en Odoo.
  Odoo tiene módulo de localización chilena con su propia lógica fiscal: **el DTE
  no se importa "as is"**, hay que mapear tipos de documento, IIT/IVA, y las
  referencias. Es un proyecto de datos, no una importación directa.

### Sobre "sincronización automática"

Un CSV exportado **no es** una sincronización. Y esta kit tampoco tiene ninguna:

- No hay ningún webhook en el stack.
- No hay ningún cron que empuje datos.
- No hay ningún servicio que escriba en Slim.

Si alguien pide sincronización automática, hay que cotizar **desarrollo,
mantenimiento y manejo de errores**, y explicar que sin endpoint de escritura el
sentido posible es **Slim → ERP** (solo lectura), no **ERP → Slim**.

---

## 5. Supabase: evaluación

### Lo que sí se verificó

Leyendo el código de la app (tag `v0.1.0b1`):

- Usa **PostgreSQL de forma nativa**: `psycopg[binary]>=3.1` (psycopg 3),
  `django==6.1.*`, `django-celery-results>=2.6`.
- **No usa extensiones de PostgreSQL.** Búsqueda de `CREATE EXTENSION`,
  `pg_trgm`, `unaccent`, `uuid-ossp`, `citext` y del módulo
  `django.contrib.postgres`: **cero resultados** en todo el repositorio.
- No usa tipos propios de PostgreSQL (jsonb se ve como campo de Django normal).
- El stack upstream corre `postgres:18-alpine`.

### Lo que NO se verificó

- **Qué versión de PostgreSQL ofrece Supabase hoy.** La documentación oficial de
  conexión revisada (<https://supabase.com/docs/guides/database/connecting-to-postgres>)
  **no declara las versiones soportadas**. Sin ese dato, **no se puede afirmar
  compatibilidad** entre la versión 18 que usa el stack y la que exista en
  Supabase.
- Que las migraciones de Django corran sin cambios sobre Supabase.
- El comportamiento con el pooler de Supabase.
- Cualquier prueba real: no hay Docker ni credenciales de Supabase acá.

**Conclusión: no se puede afirmar compatibilidad con Supabase.** Si un cliente la
pide, hay que probarla en un entorno de pruebas antes de comprometer nada.

### Obstáculos técnicos concretos (verificados en el código y la doc)

1. **El compose fija la base a la red interna.** `x-slim-env` define
   `DB_HOST: db` y `DB_PORT: "5432"` como valores fijos, **no tomados del `.env`**.
   Apuntar a Supabase **exige un override propio** que redefina `DB_HOST` y
   `DB_PORT` en los servicios `setup`, `web`, `worker` y
   `worker-emision-masiva`.
2. **El servicio `backup` y `backup-hefesto` asumen `DB_HOST: db` también.**
   Hay que redefinirlos.
3. **Conexión directa vs pooler.** La documentación de Supabase indica usar
   **conexión directa** para `pg_dump`, respaldos y migraciones, y que la
   **conexión directa es IPv6** (o IPv4 con el add-on). Un VPS IPv4-only necesita
   el add-on o el pooler en modo sesión.
4. **El modo transacción del pooler no soporta *prepared statements*** y pierde
   estado de sesión (*advisory locks*, `LISTEN/NOTIFY`). Con Celery guardando
   resultados en la base, hay que probarlo.
5. **Supabase exige TLS.** Nunca `sslmode=disable`. Y para verificar el servidor
   de verdad, `sslmode=verify-full` con el certificado raíz, no solo `require`.
6. **Rol exclusivo y base dedicada.** Si se llega a probar: rol propio con
   permisos mínimos, una base dedicada por instalación, y **nunca** el rol
   `postgres` de administración ni credenciales en el navegador.

**El navegador nunca se conecta a la base.** En este kit la base no está
publicada en ningún puerto; solo Caddy expone HTTP/HTTPS. Eso se mantiene aunque
la base esté fuera.

---

## 6. Checklist de traspaso

- [ ] `pg_dump` completo generado.
- [ ] `media` y `state` respaldados (con `FIELD_ENCRYPTION_KEY`).
- [ ] `.env` copiado por canal seguro.
- [ ] Restauración probada en el destino **antes** de cortar producción.
- [ ] Si hay API: token dedicado, guardado fuera del repositorio, y plan de
      revocarlo.
- [ ] Si hay integración: es lectura, y está escrito que lo es.
- [ ] Si se pidió Supabase: está escrito que **no está verificado** y hay un plan
      de pruebas.