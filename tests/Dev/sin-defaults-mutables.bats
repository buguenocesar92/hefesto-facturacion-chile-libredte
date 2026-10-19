#!/usr/bin/env bats
#
# Candado contra defaults mutables en compose.yaml del stack LibreDTE Slim.
# — HIGH-3 del consolidado 2026-10-19.
#
# Verifica que ningún tag de imagen cae a `:latest` o `master` por default,
# y que FORWARDED_ALLOW_IPS no es literalmente "*".
#
# Ejecutar desde la raíz del repo:
#   bats tests/Dev/sin-defaults-mutables.bats
#
# Requiere: bats (apt install bats). Solo lectura con grep literal (`-F`).

setup() {
  COMPOSE="$BATS_TEST_DIRNAME/../../compose.yaml"
  [ -f "$COMPOSE" ] || skip "compose.yaml no existe en $BATS_TEST_DIRNAME/../.."
}

# Helper: ejecuta `grep -F patron archivo` y devuelve solo el status.
# bats opera por status del último comando (no por `$status`); usamos este
# helper para que el último comando del @test sea explícitamente el grep
# (o el `[`, lo que corresponda) sin perder el `$output`.
grep_q() {
  # $1: patron, $2: archivo
  grep -F -- "$1" "$2"
  return $?
}

@test "lib-core-api imagen no cae a :latest por default" {
  # El default mutable `$\{CORE_API_VERSION:-latest\}` NO debe estar en el archivo.
  run grep -F '${CORE_API_VERSION:-latest}' "$COMPOSE"
  [ "$status" -eq 1 ]   # grep retorna 1 cuando NO matchea
}

@test "lib-core-api imagen exige CORE_API_VERSION con sentinel" {
  # El sentinel fail-fast del fix debe estar presente (`:?<mensaje>`).
  grep -F 'CORE_API_VERSION:?Define' "$COMPOSE"
}

@test "SLIM build context no cae a master por default" {
  run grep -F '${SLIM_VERSION:-master}' "$COMPOSE"
  [ "$status" -eq 1 ]
}

@test "SLIM build context exige SLIM_VERSION con sentinel" {
  grep -F 'SLIM_VERSION:?Define SLIM_VERSION' "$COMPOSE"
}

@test "FORWARDED_ALLOW_IPS no es literal wildcard" {
  run grep -F 'FORWARDED_ALLOW_IPS: "*"' "$COMPOSE"
  [ "$status" -eq 1 ]
}

@test "FORWARDED_ALLOW_IPS esta detras de variable (default seguro)" {
  grep -F 'FORWARDED_ALLOW_IPS: ${FORWARDED_ALLOW_IPS' "$COMPOSE"
}
