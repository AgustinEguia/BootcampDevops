#!/usr/bin/env bash
#
# bootstrap-local.sh
# ---------------------
# Levanta todo el stack local (app + Prometheus + Grafana) con docker
# compose y verifica que los endpoints clave respondan, para que el
# alumno tenga feedback inmediato de si algo salió mal.
#
# Uso: ./scripts/bootstrap-local.sh
set -euo pipefail

# `set -euo pipefail` es una convención estándar en scripts de bash de
# CI/CD:
#   -e: corta el script apenas un comando falla (en vez de seguir como si
#       nada, que suele dejar el sistema en un estado inconsistente).
#   -u: trata el uso de una variable no definida como error.
#   -o pipefail: si un comando dentro de un pipe (cmd1 | cmd2) falla, todo
#       el pipe se considera fallido (por default bash sólo mira el
#       exit code del ÚLTIMO comando del pipe).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Levantando el stack con docker compose (app + prometheus + grafana)..."
docker compose up --build -d

echo "==> Esperando a que la app esté lista..."
# Reintentamos por hasta ~30 segundos: la primera vez que se buildea la
# imagen puede tardar unos segundos extra en levantar el proceso de
# uvicorn dentro del contenedor.
ATTEMPTS=15
until curl -fsS "http://localhost:8000/healthz" > /dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS - 1))
  if [ "$ATTEMPTS" -le 0 ]; then
    echo "ERROR: la app no respondió en /healthz después de esperar. Revisá los logs con: docker compose logs app"
    exit 1
  fi
  sleep 2
done

echo "==> Verificando endpoints clave..."
curl -fsS "http://localhost:8000/healthz"  | grep -q '"status":"ok"'    && echo "  [OK] /healthz"
curl -fsS "http://localhost:8000/readyz"    | grep -q '"status":"ready"' && echo "  [OK] /readyz"
curl -fsS "http://localhost:8000/metrics"    | grep -q 'http_requests_total' && echo "  [OK] /metrics expone métricas Prometheus"
curl -fsS "http://localhost:9090/-/healthy"   > /dev/null && echo "  [OK] Prometheus"
curl -fsS "http://localhost:3000/api/health"   > /dev/null && echo "  [OK] Grafana"

cat <<MSG

Todo listo. URLs disponibles:
  App:        http://localhost:8000  (docs interactivas en http://localhost:8000/docs)
  Prometheus: http://localhost:9090
  Grafana:    http://localhost:3000  (usuario/clave: admin/admin)

Para bajar todo: make down  (o: docker compose down -v)
MSG
