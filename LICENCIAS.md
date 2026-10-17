# LICENCIAS.md

Resumen rápido. Las obligaciones reales y las fuentes están en
`docs/10-LICENCIAS-Y-FUENTES.md`.

---

## 1. Aplicación y stack

| Componente | Licencia | Fuente oficial |
|---|---|---|
| LibreDTE Slim (app + stack Docker) | **AGPL-3.0** | https://github.com/LibreDTE/libredte-app-slim · https://github.com/LibreDTE/libredte-docker-slim |
| LibreDTE Lib Core API | **AGPL-3.0** | https://github.com/LibreDTE/libredte-lib-core-api |
| Términos de uso de LibreDTE Slim | Contrato de uso | https://slim.libredte.cl/legal |

El texto AGPL-3.0 completo está en `COPYING` (copiado del upstream, sin
modificar).

## 2. Infraestructura

| Componente | Licencia | Enlace |
|---|---|---|
| Caddy 2.11 | Apache-2.0 | https://github.com/caddyserver/caddy/blob/master/LICENSE |
| PostgreSQL 18 | PostgreSQL License | https://www.postgresql.org/about/licence/ |
| Valkey 9.2 | BSD-3-Clause | https://github.com/valkey-io/valkey/blob/unstable/COPYING |
| Mailpit v1.31 (desarrollo) | MIT | https://github.com/axllent/mailpit/blob/master/LICENSE |

## 3. Capa Hefesto Studio

`compose.hefesto.yaml`, `scripts/backup-hefesto.sh`, `.env.example`,
`README.md`, `VERSION.md`, `LICENCIAS.md`, `docs/` y `ejemplos/` son obra de
**Hefesto Studio** y se pueden usar/modificar libremente.

> Licencia deliberadamente no declarada en este kit. Antes de distribuirlo
> comercialmente, Hefesto Studio debe elegir y escribir una licencia para su
> capa (por ejemplo MIT o AGPL-3.0) y anotarla acá. Queda anotado como
> pendiente en `docs/07-PRUEBAS-DE-ACEPTACION.md`.

## 4. El punto que más se malinterpreta: AGPL y servicios

De los términos oficiales (https://slim.libredte.cl/legal), textual:

> "Si incorporas el código de LibreDTE dentro de tu propio software, ese
> software debe liberarse públicamente bajo licencia AGPL. Conectar tu software
> a LibreDTE Slim por su API, como un proceso separado, no te obliga a liberar
> tu software."

En la práctica, para este kit:

- **No queda sujeto a AGPL:** el software de un tercero que consume Slim
  **por HTTP** (API REST) o **como servicio aparte** (la imagen Docker corriendo
  sola, en su servidor). El copyleft de AGPL alcanza al código de Slim que se
  modifica, no a quien lo usa por red.
- **Sí queda sujeto a AGPL:** quien **incorpore** el código de LibreDTE dentro de
  su propio proceso — por ejemplo una biblioteca PHP, un *dispatcher* o un
  *bridge* en Python que importe el código de Slim. Ahí laderivación obliga a
  liberar el trabajo derivado bajo AGPL.
- **Obligación para todos:** reconocimiento público del proyecto y de su autor
  original (LibreDTE), tanto si se usa sin modificar como si se modifica.

Este matiz es una decisión comercial legítima y debe ir siempre por escrito en
la propuesta, sin insinuar que LibreDTE "libera" el software del cliente: lo
que hay es un límite legal claro, no una dispensa.

## 5. Marca

**LibreDTE es marca registrada de SASCO SpA.** Según los términos oficiales se
puede decir "compatible con LibreDTE" o "construido sobre LibreDTE"; **no** se
puede presentar como LibreDTE oficial ni usar el nombre o el logo de forma que
sugiera respaldo o afiliación.

Este kit es de Hefesto Studio. Debajo del panel de Slim debe quedar el aviso de
atribución que exige AGPL; ver `docs/10-LICENCIAS-Y-FUENTES.md` para el texto
concreto propuesto.