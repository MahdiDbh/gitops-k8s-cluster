#!/usr/bin/env bash
#
# install-argocd.sh — Bootstrap ArgoCD on the k3s cluster
#
# This script installs ArgoCD via the project's official manifest in the
# `argocd` namespace, waits for the pods to become ready, then prints the
# initial admin password.
#
# Prerequisites: kubectl configured and pointing at the target cluster
# (see docs/setup.md).

set -euo pipefail

NAMESPACE="argocd"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "==> Checking cluster connectivity..."
kubectl cluster-info >/dev/null

echo "==> Creating namespace '${NAMESPACE}' (if missing)..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying the official ArgoCD manifest (server-side apply)..."
# Note: the ArgoCD manifest contains a large CRD
# (applicationsets.argoproj.io) that exceeds the annotation size limit of
# a classic `kubectl apply` (client-side, last-applied-configuration).
# We use --server-side, the method recommended by Kubernetes for large
# manifests.
kubectl apply -n "${NAMESPACE}" -f "${ARGOCD_MANIFEST_URL}" --server-side --force-conflicts

echo "==> Waiting for ArgoCD pods to become ready (up to 10 min)..."
# Image pulls (quay.io, ghcr.io) can be slow depending on connectivity on
# first start; the argocd-dex-server pod in particular can take longer
# than the others.
kubectl wait --for=condition=Ready pods --all -n "${NAMESPACE}" --timeout=600s || \
  echo "⚠️  Some pods are not ready yet, see 'kubectl get pods -n ${NAMESPACE}' below."

echo "==> ArgoCD pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "==> Initial admin password:"
kubectl -n "${NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ""
echo "==> To access the ArgoCD UI locally:"
echo "    kubectl port-forward svc/argocd-server -n ${NAMESPACE} 8080:443"
echo "    then open https://localhost:8080 (user: admin)"
echo ""
echo "==> To install the argocd CLI (optional):"
echo "    https://argo-cd.readthedocs.io/en/stable/cli_installation/"
