#!/usr/bin/env bash
# Reúne evidencias del despliegue y del monitoreo en ./evidence (se suben como artefacto del pipeline).
set -uo pipefail

OUT="${OUT:-evidence}"
PROM_PORT="${PROM_PORT:-9090}"   # cambiar si el 9090 local está ocupado
mkdir -p "${OUT}"

kubectl get nodes -o wide                                   > "${OUT}/nodes.txt" 2>&1
kubectl -n tasks-api get all,ingress,hpa,pdb,networkpolicy,resourcequota,cronjob -o wide \
                                                            > "${OUT}/k8s-resources.txt" 2>&1
kubectl -n tasks-api describe hpa tasks-api                 > "${OUT}/hpa-describe.txt" 2>&1
kubectl -n tasks-api get events --sort-by=.lastTimestamp    > "${OUT}/events.txt" 2>&1
kubectl -n tasks-api logs -l app.kubernetes.io/name=tasks-api --tail=50 --prefix \
                                                            > "${OUT}/app-logs.txt" 2>&1
kubectl top pods -A                                         > "${OUT}/top-pods.txt" 2>&1
kubectl -n monitoring get pods,svc,servicemonitor,prometheusrule \
                                                            > "${OUT}/monitoring-resources.txt" 2>&1

# Consultas a Prometheus a través de un port-forward temporal.
if kubectl -n monitoring get svc monitoring-prometheus >/dev/null 2>&1; then
  kubectl -n monitoring port-forward svc/monitoring-prometheus "${PROM_PORT}":9090 >/dev/null 2>&1 &
  PF=$!
  sleep 5
  q() { curl -s --get "http://localhost:${PROM_PORT}/api/v1/query" --data-urlencode "query=$1"; echo; }
  {
    echo "## Targets de tasks-api (up)";              q 'up{job="tasks-api"}'
    echo "## Peticiones totales por ruta";            q 'sum by (route,status) (http_requests_total{job="tasks-api"})'
    echo "## Latencia p95 (5m)";                      q 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job="tasks-api"}[5m])))'
    echo "## Réplicas actuales del HPA";              q 'kube_horizontalpodautoscaler_status_current_replicas{horizontalpodautoscaler="tasks-api"}'
    echo "## Reglas de alerta cargadas";              curl -s "http://localhost:${PROM_PORT}/api/v1/rules?type=alert" | grep -o '"name":"TasksApi[A-Za-z0-9]*"' | sort -u
  } > "${OUT}/prometheus-queries.txt" 2>&1
  kill "${PF}" 2>/dev/null || true
fi

echo "Evidencias guardadas en ${OUT}/:"
ls -1 "${OUT}"
