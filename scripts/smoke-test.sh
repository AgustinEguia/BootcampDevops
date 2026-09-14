#!/usr/bin/env bash
#
# smoke-test.sh
# ---------------
# Smoke test post-deploy: verifica que la app recién desplegada responda
# lo mínimo esperado. NO reemplaza a los tests automatizados de
# app/tests/ (esos ya corrieron en la etapa "test" del pipeline, ANTES de
# buildear la imagen): este script corre DESPUÉS del deploy, contra el
# ambiente real (dev o prod), para confirmar que el DEPLOY en sí
# funcionó (no que la lógica de negocio es correcta).
#
# Uso:
#   ./scripts/smoke-test.sh http://localhost:8000
#   ./scripts/smoke-test.sh https://demo-app-dev.tu-dominio.com
#
# Exit code 0 si todo OK, distinto de 0 si algo falló (así el job de CI/CD
# que lo invoca — ver ci/gitlab/40-deploy.yml — falla correctamente y
# corta el pipeline antes de llegar a deploy-prod).
set -euo pipefail

BASE_URL="${1:?Uso: $0 <URL_BASE_DE_LA_APP>  (ej: http://localhost:8000)}"
# Sacamos una posible barra final para no terminar con "//healthz".
BASE_URL="${BASE_URL%/}"

FAILED=0

# Función auxiliar: hace un curl y chequea el status code esperado.
# La usamos en vez de repetir la misma lógica de curl+if para cada
# endpoint, siguiendo el mismo principio de "no te repitas" (DRY) que
# aplicamos con las shared libraries de Jenkins.
check_endpoint() {
  local method="$1"
  local path="$2"
  local expected_status="$3"
  local url="${BASE_URL}${path}"

  local actual_status
  actual_status="$(curl -s -o /dev/null -w '%{http_code}' -X "${method}" "${url}" || echo "000")"

  if [ "${actual_status}" = "${expected_status}" ]; then
    echo "  [OK]   ${method} ${path} -> ${actual_status}"
  else
    echo "  [FAIL] ${method} ${path} -> esperado ${expected_status}, recibido ${actual_status}"
    FAILED=1
  fi
}

echo "==> Smoke test contra: ${BASE_URL}"

check_endpoint "GET" "/healthz"    "200"
check_endpoint "GET" "/readyz"      "200"
check_endpoint "GET" "/metrics"      "200"
check_endpoint "GET" "/api/tasks"     "200"

# Chequeo funcional mínimo: crear una tarea y confirmar que el CRUD
# responde de punta a punta (no sólo que el proceso está "up", sino que
# la lógica básica funciona contra el deploy real).
echo "==> Probando el CRUD de /api/tasks..."
CREATE_RESPONSE="$(curl -s -X POST "${BASE_URL}/api/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title": "smoke-test task"}')"

if echo "${CREATE_RESPONSE}" | grep -q '"title":"smoke-test task"'; then
  echo "  [OK]   POST /api/tasks creó una tarea correctamente"
else
  echo "  [FAIL] POST /api/tasks no devolvió el resultado esperado: ${CREATE_RESPONSE}"
  FAILED=1
fi

if [ "${FAILED}" -eq 0 ]; then
  echo "==> Smoke test OK: el deploy parece funcionar correctamente."
  exit 0
else
  echo "==> Smoke test FALLÓ: revisar los endpoints marcados [FAIL] arriba."
  exit 1
fi
