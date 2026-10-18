#!/usr/bin/env bash
# scripts/coolify-check.sh
#
# Verifica que los compose "del contrato" del repo cumplan el contrato mínimo
# para Coolify en los servicios sin `profiles`:
#   - sin `ports` publicados al host (Coolify ya pone Traefik);
#   - sin `container_name` fijo, `privileged`, `cap_add`, `devices`,
#     `network_mode: host`, `pid: host`, `ipc: host`, `security_opt: unconfined`;
#   - sin bind a `/var/run/docker.sock`.
#
# Sale con código 0 si todo cumple, 1 si hay reglas rotas, 2 si el render del
# compose falla (por ejemplo, por una variable interpolada mal).
#
# Uso:
#   bash scripts/coolify-check.sh                 # prueba compose.yaml del repo
#   bash scripts/coolify-check.sh <ruta>...       # prueba las rutas indicadas

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && git rev-parse --show-toplevel 2>/dev/null \
    || { cd "$(dirname "$0")/.." && pwd; })"

# Valor ficticio, no secreto, para variables interpoladas sin forma especial.
DUMMY='x123example'
# Variables de URL.
URL_DUMMY='https://ejemplo.invalid'
# Hostname (no URL completa) para SITE_HOSTNAME y similares.
HOST_DUMMY='ejemplo.invalid'
# Esquema solo.
SCHEMA_DUMMY='https'
# IP de bind.
IP_DUMMY='0.0.0.0'
# Puerto.
PORT_DUMMY='9'
# Memoria (formato Docker válido).
MEMORY_DUMMY='1g'

fail=0
cleanup_files=()
cleanup() {
    local f
    for f in "${cleanup_files[@]:-}"; do
        [ -n "${f}" ] && [ -e "${f}" ] && rm -f "${f}"
    done
}
trap cleanup EXIT

if [ "$#" -gt 0 ]; then
    compose_files=("$@")
elif [ -f "${REPO_ROOT}/compose.yaml" ]; then
    compose_files=("${REPO_ROOT}/compose.yaml")
else
    echo "No se encontró compose.yaml en ${REPO_ROOT}" >&2
    exit 2
fi

# Clasifica una variable para elegir el dummy sintácticamente válido.
classify_var() {
    case "$1" in
        SITE_URL_SCHEMA)                                  echo 'schema'  ;;
        SITE_HOSTNAME|TRAEFIK_HOST|SITE_EXTRA_HOSTS)      echo 'host'    ;;
        PLUGIN_*_URL|PLUGIN_*_API_URL|*_URL|*_ADDRESS)    echo 'url'     ;;
        HTTP_BIND|TCP_BIND|UDP_BIND|*_BIND)               echo 'ip'      ;;
        HTTP_PORT|HTTPS_PORT|MAILPIT_PORT|*_PORT)         echo 'port'    ;;
        *_MEMORY_LIMIT|LOG_MAX_SIZE)                      echo 'memory'  ;;
        *)                                                echo 'plain'   ;;
    esac
}

# Extrae los nombres de variable únicos del estilo ${VAR}, ${VAR:-x}, ${VAR:?m}.
extract_vars() {
    grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*' "$1" \
        | sed 's/^\${//' | sort -u
}

for cf in "${compose_files[@]}"; do
    printf '==> %s\n' "$cf"

    if [ ! -f "${cf}" ]; then
        printf '  compose: no existe (%s)\n' "$cf"
        fail=$((fail + 1))
        continue
    fi

    tmpenv="$(mktemp -t coolify-check-XXXXXX.env)"
    cleanup_files+=("${tmpenv}")

    while IFS= read -r var; do
        [ -z "${var}" ] && continue
        case "$(classify_var "${var}")" in
            schema)  echo "${var}=${SCHEMA_DUMMY}"     >> "${tmpenv}" ;;
            host)    echo "${var}=${HOST_DUMMY}"       >> "${tmpenv}" ;;
            url)     echo "${var}=${URL_DUMMY}"        >> "${tmpenv}" ;;
            ip)      echo "${var}=${IP_DUMMY}"         >> "${tmpenv}" ;;
            port)    echo "${var}=${PORT_DUMMY}"       >> "${tmpenv}" ;;
            memory)  echo "${var}=${MEMORY_DUMMY}"     >> "${tmpenv}" ;;
            plain)   echo "${var}=${DUMMY}"            >> "${tmpenv}" ;;
        esac
    done < <(extract_vars "${cf}")

    # Renderiza. stdout = JSON; stderr = advertencias del cliente.
    stderr_file="$(mktemp -t coolify-check-stderr-XXXXXX.log)"
    cleanup_files+=("${stderr_file}")
    if ! rendered="$(docker compose \
            --project-directory "${REPO_ROOT}" \
            -f "${cf}" \
            --env-file "${tmpenv}" \
            config --format json 2> "${stderr_file}")"; then
        printf '  render: %s\n' "$(grep -E '(error|interpolat|invalid|missing)' \
            "${stderr_file}" | head -3 | tr '\n' ' ')"
        fail=$((fail + 1))
        continue
    fi

    # Servicios: revisamos reglas solo en los que NO tienen profiles.
    while IFS= read -r svc; do
        [ -z "${svc}" ] && continue
        issues="$(printf '%s' "${rendered}" | jq -r --arg s "${svc}" '
            .services[$s] as $svc
            | (if ($svc.profiles // []) | length > 0
               then []
               else
                  [
                    (if ($svc.ports // []) | length > 0
                         then "ports" else empty end),
                    (if $svc.container_name != null
                         then "container_name" else empty end),
                    (if ($svc.privileged // false) == true
                         then "privileged" else empty end),
                    (if ($svc.cap_add // []) | length > 0
                         then "cap_add" else empty end),
                    (if ($svc.devices // []) | length > 0
                         then "devices" else empty end),
                    (if $svc.network_mode == "host"
                         then "network_mode_host" else empty end),
                    (if $svc.pid == "host"
                         then "pid_host" else empty end),
                    (if $svc.ipc == "host"
                         then "ipc_host" else empty end),
                    (if ($svc.security_opt // []) | join(",")
                         | test("unconfined")
                         then "security_opt_unconfined" else empty end),
                    (if ($svc.volumes // [])
                         | map(.source // "") | join("\n")
                         | test("/var/run/docker.sock")
                         then "docker_sock" else empty end)
                  ]
               end)
            | join(",")
        ')"
        if [ -n "${issues}" ] && [ "${issues}" != "null" ]; then
            printf '  %s: %s\n' "${svc}" "${issues}"
            fail=$((fail + 1))
        fi
    done < <(printf '%s' "${rendered}" | jq -r '.services | keys[]')
done

if [ "${fail}" -gt 0 ]; then
    echo "FAIL: ${fail} regla(s) rota(s)"
    exit 1
fi

echo "OK: todos los compose cumplen el contrato"
exit 0
