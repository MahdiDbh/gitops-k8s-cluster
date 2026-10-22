#!/usr/bin/env bash
#
# install.sh — Installs the kube-prometheus-stack (Prometheus, Grafana,
# Alertmanager) via Helm into the `monitoring` namespace.
#
# Prerequisites: kubectl + helm configured (see docs/setup.md).

set -euo pipefail

NAMESPACE="monitoring"
RELEASE_NAME="kube-prometheus-stack"
VALUES_FILE="$(dirname "$0")/values.yaml"

echo "==> Adding the prometheus-community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "==> Creating namespace '${NAMESPACE}' (if missing)..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing / upgrading ${RELEASE_NAME}..."
helm upgrade --install "${RELEASE_NAME}" prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 15m

echo ""
echo "==> Monitoring pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "==> To access Grafana locally:"
echo "    kubectl port-forward svc/${RELEASE_NAME}-grafana -n ${NAMESPACE} 3000:80"
echo "    then open http://localhost:3000 (user: admin / see values.yaml)"
echo ""
echo "==> To access Prometheus locally:"
echo "    kubectl port-forward svc/${RELEASE_NAME}-prometheus -n ${NAMESPACE} 9090:9090"
echo ""
echo "==> To access Alertmanager locally:"
echo "    kubectl port-forward svc/${RELEASE_NAME}-alertmanager -n ${NAMESPACE} 9093:9093"
