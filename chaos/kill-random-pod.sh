#!/usr/bin/env bash
#
# kill-random-pod.sh — Test de résilience (chaos engineering basique)
#
# Supprime un pod aléatoire d'une application et mesure le temps mis par
# Kubernetes pour recréer un pod Ready à sa place (self-healing natif,
# assuré par le ReplicaSet — indépendant d'ArgoCD).
#
# Usage:
#   ./chaos/kill-random-pod.sh [app_label] [namespace]
#
# Exemples:
#   ./chaos/kill-random-pod.sh                      # app=hello-nginx, namespace=default
#   ./chaos/kill-random-pod.sh app=hello-nginx default
#   ./chaos/kill-random-pod.sh app.kubernetes.io/name=grafana monitoring

set -euo pipefail

LABEL_SELECTOR="${1:-app=hello-nginx}"
NAMESPACE="${2:-default}"

echo "==> Namespace: ${NAMESPACE}"
echo "==> Sélecteur: ${LABEL_SELECTOR}"
echo ""

echo "==> Pods avant le test :"
kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" -o wide

# Sélection d'un pod au hasard parmi ceux Running
TARGET_POD=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | shuf -n 1)

if [[ -z "${TARGET_POD}" ]]; then
  echo "Erreur : aucun pod Running trouvé pour ce sélecteur." >&2
  exit 1
fi

echo ""
echo "==> Pod ciblé pour suppression : ${TARGET_POD}"
echo ""

START_TIME=$(date +%s)

echo "==> Suppression du pod..."
kubectl delete pod "${TARGET_POD}" -n "${NAMESPACE}" --wait=false

echo "==> Attente qu'un nouveau pod devienne Ready..."
# On attend que le nombre de pods Ready remonte au nombre de pods présents
# juste avant le test (le ReplicaSet recrée automatiquement ce qui manque).
DESIRED_REPLICAS=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" \
  -o jsonpath='{.items[*].metadata.name}' | wc -w)

while true; do
  READY_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" \
    -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
    | grep -c "^True$" || true)
  if [[ "${READY_COUNT}" -ge "${DESIRED_REPLICAS}" ]]; then
    break
  fi
  sleep 1
done

END_TIME=$(date +%s)
RECOVERY_TIME=$((END_TIME - START_TIME))

echo ""
echo "==> Pods après le test :"
kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" -o wide

echo ""
echo "=================================================="
echo " Pod supprimé     : ${TARGET_POD}"
echo " Temps de recovery: ${RECOVERY_TIME}s"
echo " Replicas attendus: ${DESIRED_REPLICAS}"
echo "=================================================="
echo ""
echo "==> Événements liés au remplacement :"
kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' \
  | grep -E "hello-nginx|${TARGET_POD}" | tail -10 || true
