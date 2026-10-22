#!/usr/bin/env bash
#
# kill-random-pod.sh — Resilience test (basic chaos engineering)
#
# Deletes a random pod from an application and measures how long
# Kubernetes takes to recreate a Ready pod in its place (native
# self-healing, handled by the ReplicaSet — independent of ArgoCD).
#
# Usage:
#   ./chaos/kill-random-pod.sh [app_label] [namespace]
#
# Examples:
#   ./chaos/kill-random-pod.sh                      # app=hello-nginx, namespace=default
#   ./chaos/kill-random-pod.sh app=hello-nginx default
#   ./chaos/kill-random-pod.sh app.kubernetes.io/name=grafana monitoring

set -euo pipefail

LABEL_SELECTOR="${1:-app=hello-nginx}"
NAMESPACE="${2:-default}"

echo "==> Namespace: ${NAMESPACE}"
echo "==> Selector: ${LABEL_SELECTOR}"
echo ""

echo "==> Pods before the test:"
kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" -o wide

# Pick a random pod among the Running ones
TARGET_POD=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | shuf -n 1)

if [[ -z "${TARGET_POD}" ]]; then
  echo "Error: no Running pod found for this selector." >&2
  exit 1
fi

echo ""
echo "==> Pod targeted for deletion: ${TARGET_POD}"
echo ""

START_TIME=$(date +%s)

echo "==> Deleting the pod..."
kubectl delete pod "${TARGET_POD}" -n "${NAMESPACE}" --wait=false

echo "==> Waiting for a new pod to become Ready..."
# Wait until the number of Ready pods is back to the count observed just
# before the test (the ReplicaSet automatically recreates what's missing).
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
echo "==> Pods after the test:"
kubectl get pods -n "${NAMESPACE}" -l "${LABEL_SELECTOR}" -o wide

echo ""
echo "=================================================="
echo " Pod deleted     : ${TARGET_POD}"
echo " Recovery time    : ${RECOVERY_TIME}s"
echo " Expected replicas: ${DESIRED_REPLICAS}"
echo "=================================================="
echo ""
echo "==> Events related to the replacement:"
kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' \
  | grep -E "hello-nginx|${TARGET_POD}" | tail -10 || true
