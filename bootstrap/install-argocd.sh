#!/usr/bin/env bash
#
# install-argocd.sh — Bootstrap ArgoCD dans le cluster k3s
#
# Ce script installe ArgoCD via le manifest officiel du projet dans le
# namespace `argocd`, attend que les pods soient prêts, puis affiche le
# mot de passe admin initial.
#
# Prérequis : kubectl configuré et pointant vers le cluster cible
# (voir docs/setup.md).

set -euo pipefail

NAMESPACE="argocd"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "==> Vérification de la connexion au cluster..."
kubectl cluster-info >/dev/null

echo "==> Création du namespace '${NAMESPACE}' (si absent)..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Application du manifest ArgoCD officiel..."
kubectl apply -n "${NAMESPACE}" -f "${ARGOCD_MANIFEST_URL}"

echo "==> Attente que les pods ArgoCD soient prêts (jusqu'à 5 min)..."
kubectl wait --for=condition=Ready pods --all -n "${NAMESPACE}" --timeout=300s

echo "==> Pods ArgoCD :"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "==> Mot de passe admin initial :"
kubectl -n "${NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ""
echo "==> Pour accéder à l'UI ArgoCD en local :"
echo "    kubectl port-forward svc/argocd-server -n ${NAMESPACE} 8080:443"
echo "    puis ouvrir https://localhost:8080 (user: admin)"
echo ""
echo "==> Pour installer la CLI argocd (optionnel) :"
echo "    https://argo-cd.readthedocs.io/en/stable/cli_installation/"
