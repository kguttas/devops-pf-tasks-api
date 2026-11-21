#!/usr/bin/env bash
# Pruebas de humo contra un despliegue (por defecto el ingress de kind en localhost:8080).
# Uso: BASE_URL=http://<host> ./scripts/smoke-test.sh
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "Smoke tests contra ${BASE_URL}"

# El ingress puede tardar unos segundos en enrutar tras el primer deploy.
for i in $(seq 1 30); do
  if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then break; fi
  [[ $i == 30 ]] && fail "la app no respondió en ${BASE_URL}/healthz"
  sleep 2
done

curl -fsS "${BASE_URL}/" | tee /dev/stderr | grep -q '"name":"tasks-api"' || fail "GET /"
echo
curl -fsS "${BASE_URL}/readyz" | grep -q ready || fail "GET /readyz"

created=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d '{"title":"smoke test"}' "${BASE_URL}/api/tasks")
id=$(echo "${created}" | sed -E 's/.*"id":"([^"]+)".*/\1/')
[[ -n "${id}" ]] || fail "POST /api/tasks"
curl -fsS "${BASE_URL}/api/tasks/${id}" | grep -q "smoke test" || fail "GET /api/tasks/:id"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -d '{}' "${BASE_URL}/api/tasks")
[[ "${code}" == "400" ]] || fail "la validación debía devolver 400 y devolvió ${code}"

curl -fsS "${BASE_URL}/metrics" | grep -q http_requests_total || fail "GET /metrics"

echo "OK: todas las pruebas de humo pasaron"
