#!/usr/bin/env bash
# Crea el entorno de pruebas completo en kind: cluster + ingress-nginx + metrics-server
# + kube-prometheus-stack + app. Lo usan el pipeline (job deploy-test) y la ejecución local.
#
# Uso: IMAGE=tasks-api:local ./scripts/kind-up.sh
#   IMAGE        imagen ya construida localmente (se carga en kind)
#   GRAFANA_PASSWORD  contraseña admin de Grafana (por defecto se genera una aleatoria)
#   SKIP_MONITORING=1 para omitir Prometheus/Grafana
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER="${CLUSTER:-tasks-api}"
IMAGE="${IMAGE:-tasks-api:local}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')}"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

log "Cluster kind '${CLUSTER}'"
if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER}"; then
  kind create cluster --name "${CLUSTER}" --config "${ROOT}/k8s/kind-config.yaml" --wait 120s
fi
kubectl config use-context "kind-${CLUSTER}"

log "Cargando imagen ${IMAGE} en el cluster"
kind load docker-image "${IMAGE}" --name "${CLUSTER}"

log "Instalando ingress-nginx"
# Manifiesto mantenido por el proyecto kind (ingress-nginx preparado para extraPortMappings).
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout=180s
kubectl -n ingress-nginx wait --for=condition=complete job --all --timeout=120s || true

log "Instalando metrics-server (requerido por el HPA)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.1/components.yaml
# kind usa certificados autofirmados en el kubelet.
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s

if [[ "${SKIP_MONITORING:-0}" != "1" ]]; then
  log "Instalando kube-prometheus-stack (Prometheus + Grafana + Alertmanager)"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update prometheus-community >/dev/null
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    -f "${ROOT}/monitoring/kube-prometheus-stack-values.yaml" \
    --set grafana.adminPassword="${GRAFANA_PASSWORD}" \
    --set "grafana.grafana\.ini.auth\.anonymous.enabled=true" \
    --set "grafana.grafana\.ini.auth\.anonymous.org_role=Viewer" \
    --wait --timeout 10m
  kubectl apply -k "${ROOT}/monitoring/k8s"
fi

log "Desplegando la aplicación (overlay kind)"
OVERLAY="$(mktemp -d)"
cp -r "${ROOT}/k8s/." "${OVERLAY}/"
( cd "${OVERLAY}/overlays/kind" && kubectl kustomize . \
    | sed "s#image: tasks-api:local#image: ${IMAGE}#" > "${OVERLAY}/rendered.yaml" )
kubectl apply -f "${OVERLAY}/rendered.yaml"
kubectl -n tasks-api rollout status deployment/tasks-api --timeout=180s

log "Entorno listo"
kubectl -n tasks-api get deploy,po,svc,ingress,hpa -o wide
echo "App:      http://localhost:8080/"
echo "Grafana:  kubectl -n monitoring port-forward svc/monitoring-grafana 3001:80  (admin / ver GRAFANA_PASSWORD)"
