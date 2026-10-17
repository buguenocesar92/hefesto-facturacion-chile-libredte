# 08 — Servicios comerciales

Qué se puede vender, qué no, y qué límites tiene el producto en su edición
gratuita. Todo lo que sigue sale de las páginas oficiales de LibreDTE Slim
(<https://slim.libredte.cl/legal>, `/services`, `/compare`), consultadas el
2026-10-16, y de la lectura del código de la app.

---

## 1. A quién le sirve

- Contribuyentes chilenos que necesitan **emitir DTE** y hoy pagan licencias
  comerciales por otro sistema.
- Empresas que quieren **autocontrolar sus datos**: el software corre en el
  servidor del cliente, no en el de un tercero.
- Estudios yrieves que lo instalan para clientes, cada instancia aparte.

## 2. El primer requisito, y no es del kit

> **Para emitir documentos reales, el SII exige que la empresa complete su
> proceso de certificación.**

Fuente: https://slim.libredte.cl/services — *"Para emitir documentos reales, el
SII exige que tu empresa complete su proceso de certificación"*.

Esto significa:

- **La certificación es del cliente, no de Hefesto ni del kit.** Es un trámite
  ante el SII.
- **La primera emisión es un acto del cliente.** Instalar Slim no habilita
  automáticamente a nadie para timbrar.
- En la propuesta hay que separar explícitamente: (a) despliegue del software, que
  es lo que hacemos; (b) certificación ante el SII, que es del cliente.
- LibreDTE ofrece el trámite como servicio aparte
  (<https://www.libredte.cl/certificacion-dte>), pero es **una tercera
  plataforma en el negocio**: no es lo mismo que vender un despliegue, y hay que
  decirlo claro si se menciona.
- El kit **no verifica** el estado de certificación de nadie ni automatiza el
  trámite. Cualquier función de ese tipo que se prometa sería inventada.

## 3. La edición gratuita: qué incluye y qué no

La opción gratuita se llama **"Slim + Core"** en la comparación oficial de
LibreDTE. Es **gratis** (más IVA) y trae el núcleo de facturación (`Lib Core
API`) corriendo **en el servidor del cliente**.

Lo que trae:

| Funcionalidad | Slim + Core |
|---|---|
| Dónde corre | Tu servidor |
| Núcleo de facturación | Lib Core API en tu servidor |
| Límite de consultas al SII | **Sin límite** |
| Creación de documentos | Sí |
| Emisión masiva | **CSV** (no XLSX) |
| API REST | Sí (pero ver la advertencia de abajo) |
| Documentación OpenAPI | Sí |
| Base de datos | PostgreSQL |
| Actualizaciones | **Las aplicas tú** |

Lo que **no** trae:

| Limitación | Detalle |
|---|---|
| **Envío de boletas al SII** | **"Todos menos boletas"**. Con Pro, API Gateway o Flex: "Todos, incluidas boletas". **Este es el límite funcional más importante de la edición gratuita** |
| Emisión masiva en XLSX | Solo CSV |
| Soporte de servicios externos | No incluye |
| Soporte de la plataforma | **"A cotizar"** |

### El soporte no viene incluido

Textual del FAQ oficial: *"Tienes la documentación y la Academia. Pro y API
Gateway incluyen soporte para sus propios servicios, **no para la plataforma**.
Si quieres soporte directo para LibreDTE Slim, incluso continuo, lo cotizamos
según tu caso."*

Y la tabla de comparación, para "Soporte de la plataforma (instalación y uso de la
plataforma web)": **"A cotizar"** en las tres opciones de Slim.

**Lectura comercial correcta:** el software es gratis y **el soporte es un
servicio aparte**. Por eso el trabajo de Hefesto (instalación, configuración,
traspaso, mantención) es justamente lo que se vende. No hay que inventar una
"versión gratis con soporte incluido".

**Y ojo:** el soporte de LibreDTE para Slim es un servicio de **SASCO SpA**
(<https://slim.libredte.cl/legal>: *"LibreDTE es marca registrada de SASCO
SpA"*). Hefesto no es LibreDTE: **no se puede ofrecer "el soporte de LibreDTE"
como si fuera propio.** Lo que se ofrece es el trabajo de despliegue y mantención
de Hefesto; el soporte de la plataforma es el de LibreDTE, contratado aparte.

## 4. La API: el punto que más se promete de más

La tabla de comparación de LibreDTE dice, para "API REST": *"Conecta tu software
para **emitir documentos**"*, y le pone un visto bueno a Slim + Core.

**El código de la versión publicada dice otra cosa.** La documentación interna de
la propia app (`apps/core/api_docs/010-introduccion.md`) es explícita:

> "Todos los recursos son de **solo lectura** (`GET`). Emitir, confirmar o
> eliminar documentos se hace desde la aplicación web."

Y los endpoints registrados en `apps/*/api/urls.py` son solo listados
(`DteEmitidoListView`, `ReceptorListView`, `ItemListView`, `SucursalListView`,
`ComprasPeriodoDocumentosListView`, etc.). No hay vistas de creación ni de
emisión.

**Consecuencia comercial, y hay que decirlo antes de cotizar:** con
`v0.1.0b1`, la API sirve para **consultar** datos (reportes, sincronización de
lectura, tableros), **no para emitir**. Un conector de WooCommerce u Odoo que
"emite vía API de Slim" no es posible con esta versión.

Es una discrepancia entre el material comercial de LibreDTE y el código
publicado. Puede ser que la capacidad de emitir llegue en una versión posterior.
**Lo responsable:** decirlo, no venderlo.

## 5. AGPL: el argumento de venta real

De los términos oficiales, textual:

> "Si incorporas el código de LibreDTE dentro de tu propio software, ese software
> debe liberarse públicamente bajo licencia AGPL. **Conectar tu software a LibreDTE
> Slim por su API, como un proceso separado, no te obliga a liberar tu software.**"

Qué significa al vender:

- **A favor del cliente:** si su e-commerce o su ERP habla con Slim **por HTTP**
  —o consume la imagen Docker como un servicio aparte en su servidor—, **su
  software no queda obligado a AGPL**. Puede mantenerlo cerrado.
- **En contra, si se embedde:** si alguien incrusta el código de Slim dentro de su
  propio proceso (una biblioteca PHP, un *dispatcher*, un *bridge* en Python),
  **sí** queda sujeto a AGPL.
- **Obligación para todos:** reconocer públicamente al proyecto LibreDTE y a su
  autor original, modifique o no el software.
- **No existe licencia comercial de LibreDTE Slim.** No hay una vía para
  comprarla y liberationar el código del cliente.

**No exagerar esto en la venta.** Es un límite legal claro y favorable en el caso
más común (conectar por API), **no** una dispensa: si el cliente embedde,
pierde esa protección. Y siempre hay que hablar con un abogado para casos
reales.

Detalle completo en `10-LICENCIAS-Y-FUENTES.md`.

## 6. Qué se puede vender (Hefesto Studio)

- Instalación y despliegue del stack en un VPS del cliente.
- Configuración inicial: dominio, TLS, correo SMTP, límites de memoria.
- Traspaso y capacitación al equipo del cliente.
- Plan de mantención: actualizaciones, respaldos, monitoreo.
- Integraciones **de lectura** por API (reportes, sincronización de consulta),
  como desarrollo a medida.
- Auditoría inicial de la instalación y de los respaldos.

## 7. Qué NO se puede prometer

- **No emitir DTE automáticamente** desde WooCommerce/Odoo con esta versión
  (la API es de solo lectura).
- **No emitir boletas al SII** con la edición gratuita.
- **No prometer soporte incluido** en el software: no viene.
- **No prometer que el cliente está "certificado"** por instalar esto: la
  certificación es suya, ante el SII.
- **No prometer versionado estable**: `v0.1.0b1` es beta.
- **No prometer que "los datos están en Chile"** si el VPS no lo está.
- **No prometer SLA** sin un acuerdo de nivel de servicio firmado y capacidad
  real de cumplirlo.
- **No prometer aislamiento multi-cliente**: cada instalación es independiente.
- **No prometer compatibilidad con Supabase**: no está verificada
  (ver `09-EXPORTACION-O-TRASPASO.md`).

## 8. Datos personales

La aplicación maneja datos de contribuyentes y receptores (RUT, razón social,
direcciones). Eso implica:

- El VPS es del cliente y los datos no salen de ahí: es a favor.
- El navegador carga recursos desde `cdn.jsdelivr.net`: eso es una conexión
  saliente desde el equipo del usuario, aunque no se envíen datos tributarios.
- Si se agrega Mailpit en producción, quedan correos interceptados en el propio
  servidor: nunca en producción.
- Los respaldos contienen `.env`, contraseñas y **claves privadas de
  certificados**: son secretos de alto valor. `umask 077` y copia externa
  cifrada.

**Verificación pendiente:** no se auditó el cumplimiento de la Ley 19.628 de
protección de datos personales por parte de la aplicación (políticas, registro de
consentimientos, etc.). Si el cliente tiene obligations legales sobre esto, hay
que revisar la documentación de LibreDTE al respecto. No afirmar que cumple sin
revisar.

## 9. Costos que el cliente verá

| Concepto | Quién cobra |
|---|---|
| Licencia de Slim + Core | Gratis (LibreDTE) |
| Hosting / VPS | El cliente, al proveedor que elija |
| Certificación DTE | LibreDTE, como servicio aparte |
| API Gateway (opcional, para consultas al SII) | apigateway.cl |
| Soporte de la plataforma | LibreDTE, a cotizar |
| **Despliegue, traspaso y mantención** | **Hefesto Studio** |

LibreDTE **no vende hosting ni ofrece Slim como SaaS**
(<https://slim.libredte.cl/services>): *"No, en ningún caso. No vendemos
hosting, servidores ni VPS, y tampoco ofrecemos LibreDTE Slim como servicio
(SaaS)."* Si el cliente no quiere administrar un servidor, el camino es otro
producto (LibreDTE Flex) y **no** es este kit.