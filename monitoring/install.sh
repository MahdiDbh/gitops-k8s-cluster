#!/usr/bin/env bash
#
# install.sh — Installe la stack kube-prometheus-stack (Prometheus,
# Grafana, Alertmanager) via Helm dans le namespace `monitoring`.
#
# Prérequis : kubectl + helm configurés (voir docs/setup.md).

set -euo pipefail

NAMESPACE="monitoring"
RELEASE_NAME="kube-prometheus-stack"
VALUES_FILE="$(dirname "$0")/values.yaml"

echo "==> Ajout du repo Helm prometheus-community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "==> Création du namespace '${NAMESPACE}' (si absent)..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installation / mise à jour de ${RELEASE_NAME}..."
helm upgrade --install "${RELEASE_NAME}" prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 15m

echo ""
echo "==> Pods monitoring :"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "==> Pour accéder à Grafana en local :"
echo "    kubectl port-forward svc/${RELEASE_NAME}-grafana -n ${NAMESPACE} 3000:80"
echo "    puis ouvrir http://localhost:3000 (user: admin / voir values.yaml)"
echo ""
echo "==> Pour accéder à Prometheus en local :"
echo "    kubectl port-forward svc/${RELEASE_NAME}-prometheus -n ${NAMESPACE} 9090:9090"
echo ""
echo "==> Pour accéder à Alertmanager en local :"
echo "    kubectl port-forward svc/${RELEASE_NAME}-alertmanager -n ${NAMESPACE} 9093:9093"
