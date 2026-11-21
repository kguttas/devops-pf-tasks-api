#!/usr/bin/env bash
# Genera carga de CPU para demostrar el auto-escalado (HPA) y registra la evolución.
# Uso: BASE_URL=http://localhost:8080 DURATION=120 ./scripts/load-test.sh
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
DURATION="${DURATION:-120}"
CONCURRENCY="${CONCURRENCY:-6}"
OUT="${OUT:-evidence}"
mkdir -p "${OUT}"

echo "Carga: ${CONCURRENCY} clientes durante ${DURATION}s contra ${BASE_URL}/api/work"
end=$(( $(date +%s) + DURATION ))

worker() {
  while (( $(date +%s) < end )); do
    curl -s -o /dev/null "${BASE_URL}/api/work?ms=200" || true
  done
}
for _ in $(seq 1 "${CONCURRENCY}"); do worker & done

# Registra réplicas y CPU cada 15 s mientras dura la carga y un rato después.
{
  echo "# Evolución del HPA durante la prueba de carga ($(date -u +%FT%TZ))"
  while (( $(date +%s) < end + 30 )); do
    echo "--- $(date -u +%T)"
    kubectl -n tasks-api get hpa tasks-api --no-headers || true
    kubectl -n tasks-api top pods --no-headers 2>/dev/null || true
    sleep 15
  done
} | tee "${OUT}/hpa-scaling.log"

wait
max=$(grep 'Deployment/' "${OUT}/hpa-scaling.log" | awk '{print $(NF-1)}' | sort -n | tail -1)
echo "Réplicas máximas observadas: ${max:-?}" | tee -a "${OUT}/hpa-scaling.log"
