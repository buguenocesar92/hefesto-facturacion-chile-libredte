#!/bin/bash
# ---------------------------------------------------------------------------
# Respaldos Hefesto Studio de LibreDTE Slim.
#
# Complementa (no reemplaza) al `backup.sh` oficial de LibreDTE, que queda
# intacto en este mismo kit. Lo que agrega esta capa:
#
#   1. Manifiesto JSON + SHA-256 de cada artefacto del respaldo.
#   2. Marcador `<ts>-COMPLETE` escrito AL FINAL: un respaldo sin marcador no
#      existe para efectos de listado, verificación y restauración.
#   3. Verificación de integridad previa a restaurar (nunca se extrae a ciegas).
#   4. Defensa contra path traversal al extraer el tar.
#   5. Se NIEGA a restaurar sobre un destino ocupado salvo `--force` explícito.
#   6. No sobrescribe ni borra datos por su cuenta: `restore` requiere que
#      alguien lo pida a mano.
#
# Uso (dentro del contenedor del servicio `backup-hefesto`, perfil `hefesto`):
#   backup-hefesto.sh                 # ciclo: respalda ahora y cada N horas
#   backup-hefesto.sh now             # un respaldo ahora
#   backup-hefesto.sh list            # lista SOLO respaldos completos
#   backup-hefesto.sh verify <ts>     # revalida SHA-256 de un respaldo
#   backup-hefesto.sh restore <ts>    # restaura (exige stack detenido)
#   backup-hefesto.sh restore <ts> --force   # restaura sobre datos existentes
#   backup-hefesto.sh health          # healthcheck: hay un respaldo reciente
#
# El script NUNCA deja el stack andando: no tiene acceso al socket de Docker.
# Por eso `restore` verifica que no haya escritores conectados y, al terminar,
# deja todo detenido para que alguien revise antes de arrancar de nuevo.
# ---------------------------------------------------------------------------
set -euo pipefail
# Los respaldos contienen contraseñas, claves privadas y el .env: solo el dueño.
umask 077

BACKUP_DIR="${HEFESTO_BACKUP_DIR:-/backups}"
DATA_DIR="${HEFESTO_DATA_DIR:-/data}"
ENV_HOST="${HEFESTO_ENV_HOST:-/host/.env}"
# Dueño de los archivos: el usuario `slim` (UID 10001) de la imagen de Slim.
APP_UID=10001
APP_GID=10001
SUFIJO_MANIFIESTO="-manifest.json"
SUFIJO_COMPLETO="-COMPLETE"

export PGHOST="${DB_HOST}" PGPORT="${DB_PORT}" PGUSER="${DB_USER}" PGPASSWORD="${DB_PASSWORD}"

# --- utilidades ------------------------------------------------------------

error() { echo "ERROR: $*" >&2; }
info()  { echo "==> $*"; }

# Un respaldo solo existe si tiene los tres artefactos y el marcador final.
existe_respaldo() {
    local ts="$1"
    [ -f "${BACKUP_DIR}/${ts}-db.dump" ] \
        && [ -f "${BACKUP_DIR}/${ts}-files.tar.gz" ] \
        && [ -f "${BACKUP_DIR}/${ts}-manifest.json" ] \
        && [ -f "${BACKUP_DIR}/${ts}${SUFIJO_COMPLETO}" ]
}

sha256_de() {
    sha256sum "$1" | cut -d' ' -f1
}

listar_completos() {
    local f ts
    for f in "${BACKUP_DIR}"/*"${SUFIJO_COMPLETO}"; do
        [ -e "${f}" ] || continue
        ts="$(basename "${f}")"
        echo "${ts%${SUFIJO_COMPLETO}}"
    done | sort
}

# --- respaldo --------------------------------------------------------------

backup() {
    local ts db_tmp files_tmp env_tmp manifiesto tmp_sha
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    info "Respaldando LibreDTE Slim (base de datos, media, secretos y .env)"

    # Todo se escribe con prefijo temporal: si algo falla, no queda un
    # respaldo "a medias" que parezca bueno.
    db_tmp="${BACKUP_DIR}/.${ts}.tmp-db.dump"
    files_tmp="${BACKUP_DIR}/.${ts}.tmp-files.tar.gz"
    env_tmp="${BACKUP_DIR}/.${ts}.tmp-env"
    manifiesto="${BACKUP_DIR}/.${ts}.tmp${SUFIJO_MANIFIESTO}"

    limpiar_temporales() {
        local f
        for f in "${db_tmp}" "${files_tmp}" "${env_tmp}" "${manifiosto}"; do
            [ -f "${f}" ] && rm -f "${f}"
        done
    }
    trap limpiar_temporales ERR

    pg_dump --format=custom --no-owner --dbname="${DB_NAME}" --file="${db_tmp}"
    tar -C "${DATA_DIR}" -czf "${files_tmp}" media state
    cp "${ENV_HOST}" "${env_tmp}"

    # Verificación mínima antes de publicar: los tres artefactos no pueden
    # estar vacíos ni truncados.
    for f in "${db_tmp}" "${files_tmp}" "${env_tmp}"; do
        [ -s "${f}" ] || { error "Artefacto vacío: ${f}"; exit 1; }
    done
    pg_restore --list "${db_tmp}" > /dev/null

    mv "${db_tmp}"     "${BACKUP_DIR}/${ts}-db.dump"
    mv "${files_tmp}"  "${BACKUP_DIR}/${ts}-files.tar.gz"
    mv "${env_tmp}"    "${BACKUP_DIR}/${ts}-env"

    {
        echo '{'
        echo "  \"kit\": \"hefesto-libredte-facturacion\","
        echo "  \"creado_utc\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"host\": \"$(hostname)\","
        echo "  \"db_name\": \"${DB_NAME}\","
        echo "  \"db_user\": \"${DB_USER}\","
        echo "  \"pg_dump_version\": \"$(pg_dump --version)\","
        echo "  \"contenido\": ["
        echo "    { \"artefacto\": \"${ts}-db.dump\",      \"sha256\": \"$(sha256_de "${BACKUP_DIR}/${ts}-db.dump")\",     \"bytes\": $(stat -c %s "${BACKUP_DIR}/${ts}-db.dump") },"
        echo "    { \"artefacto\": \"${ts}-files.tar.gz\", \"sha256\": \"$(sha256_de "${BACKUP_DIR}/${ts}-files.tar.gz")\", \"bytes\": $(stat -c %s "${BACKUP_DIR}/${ts}-files.tar.gz") },"
        echo "    { \"artefacto\": \"${ts}-env\",          \"sha256\": \"$(sha256_de "${BACKUP_DIR}/${ts}-env")\",          \"bytes\": $(stat -c %s "${BACKUP_DIR}/${ts}-env") }"
        echo '  ]'
        echo '}'
    } > "${manifiesto}"

    # El marcador se escribe AL FINAL y lleva el SHA-256 del manifiesto:
    # si alguien lo altera después, la verificación lo detecta.
    tmp_sha="$(sha256_de "${manifiesto}")"
    {
        echo "completo=1"
        echo "marca_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "manifiesto_sha256=${tmp_sha}"
    } > "${BACKUP_DIR}/.${ts}.tmp${SUFIJO_COMPLETO}"
    mv "${BACKUP_DIR}/.${ts}.tmp${SUFIJO_COMPLETO}" "${BACKUP_DIR}/${ts}${SUFIJO_COMPLETO}"
    mv "${manifiesto}" "${BACKUP_DIR}/${ts}${SUFIJO_MANIFIESTO}"

    trap - ERR

    # Purga: SOLO respaldos completos y vencidos. Un respaldo a medias nunca
    # se borra automáticamente, para que se pueda investigar.
    while read -r viejo; do
        [ -n "${viejo}" ] || continue
        find "${BACKUP_DIR}" -maxdepth 1 -name "${viejo}-*" -mtime +"${BACKUP_KEEP_DAYS}" -delete
    done < <(listar_completos)

    info "Respaldo completo: ${ts}"
    ls -lh "${BACKUP_DIR}/${ts}-"* | sed 's/^/    /'
}

# --- verificación ----------------------------------------------------------

verificar() {
    local ts="${1:?Uso: backup-hefesto.sh verify <timestamp>}"
    local manifiesto="${BACKUP_DIR}/${ts}${SUFIJO_MANIFIESTO}"
    local artefacto sha guardado leidos ok=0

    existe_respaldo "${ts}" || { error "No hay un respaldo completo para ${ts}"; return 1; }

    # 1) el marcador debe seguir cuadrando con el manifiesto
    local esperado
    esperado="$(sed -n 's/^manifiesto_sha256=//p' "${BACKUP_DIR}/${ts}${SUFIJO_COMPLETO}" | head -n 1)"
    [ -n "${esperado}" ] || { error "Marcador sin SHA-256 del manifiesto"; return 1; }
    [ "$(sha256_de "${manifiesto}")" = "${esperado}" ] \
        || { error "El manifiesto fue alterado después de marcarse completo"; return 1; }

    # 2) cada artefacto contra el SHA-256 del manifiesto
    while read -r artefacto sha leidos; do
        [ -n "${artefacto}" ] || continue
        [ -f "${BACKUP_DIR}/${artefacto}" ] || { error "Falta ${artefacto}"; return 1; }
        guardado="$(sha256_de "${BACKUP_DIR}/${artefacto}")"
        if [ "${guardado}" != "${sha}" ]; then
            error "SHA-256 no coincide en ${artefacto}"
            return 1
        fi
        ok=$((ok + 1))
    done < <(sed -n 's/.*"artefacto"[[:space:]]*:[[:space:]]*"\([^"]*\)".*"sha256"[[:space:]]*:[[:space:]]*"\([^"]*\)".*"bytes"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1 \2 \3/p' "${manifiesto}")

    [ "${ok}" -eq 3 ] || { error "El manifiesto no lista los 3 artefactos esperados (listó ${ok})"; return 1; }
    info "Respaldo ${ts} íntegro (${ok} artefactos, SHA-256 correctos)"
}

# --- restauración ----------------------------------------------------------

# Valida que el tar no pueda escribir fuera de DATA_DIR (path traversal,
# rutas absolutas o enlaces simbólicos hacia afuera).
validar_tar() {
    local archivo="$1" entrada listado
    # Un archivo que no existe o que no se puede leer NUNCA pasa por bueno:
    # sin esto, un `tar -tzf` fallido dejaría la lista vacía y la validación
    # devolvería "correcto" sin haber mirado nada.
    [ -f "${archivo}" ] || { error "No existe el archivo de respaldo: ${archivo}"; return 1; }
    listado="$(tar -tzf "${archivo}")" || { error "No se pudo leer el tar: ${archivo}"; return 1; }
    while read -r entrada; do
        case "${entrada}" in
            /*)
                error "El tar contiene una ruta absoluta: ${entrada}"; return 1 ;;
            ..|../*|*/../*|*/..)
                error "El tar contiene una ruta con '..': ${entrada}"; return 1 ;;
        esac
    done < <(tar -tzf "${archivo}")
    # Un enlace simbólico o un tipo de archivo inesperado tampoco se extrae.
    # El listado se lee completo antes de filtrar: con `grep -q` en el medio de
    # un pipe y `pipefail`, un SIGPIPE haría que el chequeo pasara en falso.
    local listado
    listado="$(tar -tvzf "${archivo}")"
    if printf '%s\n' "${listado}" | grep -Eq '^l|^h'; then
        error "El tar contiene enlaces simbólicos o duros; no se extrae"
        return 1
    fi
}

directorio_vacio() {
    [ -d "$1" ] || return 0
    [ -z "$(ls -A "$1" 2>/dev/null)" ]
}

restore() {
    local ts="${1:?Uso: backup-hefesto.sh restore <timestamp> [--force]}"
    local forzar=0
    [ "${2:-}" = "--force" ] && forzar=1

    # 1) Integridad primero: nada se toca antes de validar el respaldo.
    verificar "${ts}"
    validar_tar "${BACKUP_DIR}/${ts}-files.tar.gz"

    # 2) Escritores conectados. La app usa el mismo rol que este script, así que
    #    cualquier conexión viva (salvo la nuestra) es Slim o un worker.
    local conexiones
    conexiones="$(psql --no-psqlrc --tuples-only --no-align \
        --dbname=postgres --set=db="${DB_NAME}" <<'SQL' | tr -d '[:space:]'
SELECT count(*) FROM pg_stat_activity
 WHERE datname = :'db' AND pid <> pg_backend_pid();
SQL
)"
    if [ "${conexiones}" != "0" ]; then
        error "Hay ${conexiones} conexión(es) activas a '${DB_NAME}'."
        error "Detén la aplicación antes de restaurar:"
        error "  docker compose stop web worker worker-emision-masiva"
        exit 1
    fi

    # 3) Destino ocupado: no se pisa nada sin --force.
    local ocupado=""
    if psql --no-psqlrc --tuples-only --no-align --dbname="${DB_NAME}" \
        --command="SELECT 1" > /dev/null 2>&1; then
        local tablas
        # `|| echo 0` para que un fallo de conteo no aborte el script antes de
        # poder avisar que el destino está ocupado.
        tablas="$(psql --no-psqlrc --tuples-only --no-align --dbname="${DB_NAME}" \
            --command="SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" \
            | tr -d '[:space:]' || echo 0)"
        if [ "${tablas:-0}" -gt 0 ] 2>/dev/null; then
            ocupado="la base '${DB_NAME}' (${tablas} tablas)"
        fi
    fi
    for d in "${DATA_DIR}/media" "${DATA_DIR}/state"; do
        directorio_vacio "${d}" || ocupado="${ocupado:+$ocupado, }${d}"
    done
    if [ -n "${ocupado}" ] && [ "${forzar}" -ne 1 ]; then
        error "El destino tiene datos: ${ocupado}"
        error "Nada se sobrescribió. Si de verdad quieres reemplazarlo, repite con --force:"
        error "  docker compose run --rm --no-deps backup-hefesto restore ${ts} --force"
        exit 1
    fi

    # 4) A partir de aquí sí se modifica, y solo porque alguien lo pidió.
    if [ "${forzar}" -eq 1 ]; then
        info "AVISO: --force. Lo que exista se IRÁ; no queda copia de lo que se borra."
        info "Reponiendo la base de datos '${DB_NAME}' desde ${ts}-db.dump"
        dropdb --if-exists --force --maintenance-db=postgres "${DB_NAME}"
    fi
    # Con o sin --force la base tiene que existir antes de restaurar.
    if ! psql --no-psqlrc --tuples-only --no-align --dbname="${DB_NAME}" \
        --command="SELECT 1" > /dev/null 2>&1; then
        createdb --maintenance-db=postgres "${DB_NAME}"
    fi
    pg_restore --no-owner --exit-on-error --dbname="${DB_NAME}" "${BACKUP_DIR}/${ts}-db.dump"

    info "Reponiendo media y secretos desde ${ts}-files.tar.gz"
    if [ "${forzar}" -eq 1 ]; then
        find "${DATA_DIR}/media" "${DATA_DIR}/state" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    fi
    tar -C "${DATA_DIR}" --no-same-owner -xzpf "${BACKUP_DIR}/${ts}-files.tar.gz"
    chown -R "${APP_UID}:${APP_GID}" "${DATA_DIR}/media" "${DATA_DIR}/state"

    # 5) Comprobación posterior: lo repuesto tiene que abrir.
    psql --no-psqlrc --tuples-only --no-align --dbname="${DB_NAME}" \
        --command="SELECT 1" > /dev/null

    info "Restaurado ${ts}. La aplicación QUEDA DETENIDA a propósito."
    echo "    Revisa antes de arrancar:"
    echo "      docker compose up -d setup && docker compose logs -f setup"
    echo "      docker compose up -d web worker worker-emision-masiva caddy"
    echo "    El .env de ese respaldo está en ${BACKUP_DIR}/${ts}-env (no se tocó el del"
    echo "    host: compáralo y cópialo a mano si hace falta)."
}

# --- despacho --------------------------------------------------------------

case "${1:-loop}" in
    now)
        backup
        ;;
    list)
        listar_completos
        ;;
    verify)
        verificar "${2:-}"
        ;;
    restore)
        restore "${2:-}" "${3:-}"
        ;;
    health)
        # El healthcheck mira solo respaldos completos y recientes.
        ts_reciente="$(listar_completos | tail -n 1)"
        [ -n "${ts_reciente}" ] || exit 1
        find "${BACKUP_DIR}" -maxdepth 1 -name "${ts_reciente}${SUFIJO_COMPLETO}" \
            -mmin -$(( BACKUP_INTERVAL_HOURS * 60 + 60 )) 2>/dev/null | grep -q .
        ;;
    loop)
        while :; do
            backup || echo "Falló el respaldo; se reintenta en ${BACKUP_INTERVAL_HOURS}h" >&2
            sleep $(( BACKUP_INTERVAL_HOURS * 3600 ))
        done
        ;;
    *)
        echo "Comando desconocido: ${1:-}" >&2
        echo "Uso: now | list | verify <ts> | restore <ts> [--force] | health" >&2
        exit 2
        ;;
esac