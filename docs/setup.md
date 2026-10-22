# Setup — k3s, kubectl, Helm

Ce document décrit l'installation des outils nécessaires au cluster, telle
qu'effectuée sur l'environnement de développement (Kali Linux, x86_64).

## Prérequis

- Un utilisateur avec accès `sudo`
- `curl`
- `systemd` (pour piloter k3s comme service)

## 1. Installation de k3s

k3s est une distribution Kubernetes légère (single binary, base de données
SQLite embarquée par défaut), adaptée aux environnements de dev/lab.

```bash
curl -sfL https://get.k3s.io | sh -
```

Cette commande installe k3s en mode serveur (control-plane) et l'enregistre
comme service systemd (`k3s.service`).

### Démarrer / activer le service

```bash
sudo systemctl enable --now k3s
```

### Vérifier le statut

```bash
systemctl status k3s
```

## 2. Configuration de kubectl

k3s embarque son propre `kubectl` mais on utilise ici le binaire `kubectl`
standard, configuré via le kubeconfig généré par k3s.

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

Par défaut `kubectl` lit `~/.kube/config`. Pour utiliser un chemin différent :

```bash
export KUBECONFIG=~/.kube/config
```

(à ajouter dans `~/.bashrc` pour le rendre permanent)

### Vérification

```bash
kubectl get nodes -o wide
```

Résultat attendu : un nœud `Ready` avec le rôle `control-plane`.

## 3. Installation de Helm

Helm est le gestionnaire de packages Kubernetes, utilisé ici pour installer
ArgoCD (optionnel, on utilise le manifest officiel) et surtout
`kube-prometheus-stack`.

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Vérification

```bash
helm version
```

## Résumé des vérifications

| Commande | Résultat attendu |
|---|---|
| `systemctl is-active k3s` | `active` |
| `kubectl get nodes` | 1 nœud `Ready` |
| `helm version` | version Helm affichée |

## Étape suivante

Voir [`bootstrap/install-argocd.sh`](../bootstrap/install-argocd.sh) pour le
déploiement d'ArgoCD dans le cluster.

## Alerting — Alertmanager → Discord

La configuration du routage des alertes vers Discord se trouve dans
[`monitoring/alertmanager-config.yaml`](../monitoring/alertmanager-config.yaml).
Ce fichier ne contient **jamais** l'URL réelle du webhook : elle est stockée
dans un Secret Kubernetes créé manuellement, une seule fois, sur chaque
environnement :

```bash
kubectl create secret generic alertmanager-discord-webhook \
  --namespace monitoring \
  --from-literal=webhookURL='<URL_DU_WEBHOOK_DISCORD>'
```

Puis on applique la config :

```bash
kubectl apply -f monitoring/alertmanager-config.yaml
```

### Créer un webhook Discord

1. Dans Discord : Paramètres du serveur → Intégrations → Webhooks → Nouveau
   webhook
2. Choisir le salon cible, copier l'URL du webhook
3. L'utiliser dans la commande `kubectl create secret` ci-dessus

### Vérifier que ça fonctionne

Déclencher une alerte de test via l'API Alertmanager (depuis le pod) :

```bash
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 \
  -c alertmanager -- wget -qO- --post-data='[{"labels":{"alertname":"Test","namespace":"monitoring","severity":"warning"},"annotations":{"summary":"Test","description":"Test"}}]' \
  --header='Content-Type: application/json' http://localhost:9093/api/v2/alerts
```

Le message doit apparaître dans le salon Discord configuré après
`groupWait` (30s par défaut).
