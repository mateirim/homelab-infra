# Bootstrapping

## 1. Personalize

```bash
./setup.sh            # fills REPLACE_WITH_* placeholders, generates + encrypts secrets
./setup-validation.sh # verify no placeholders remain, all secrets encrypted
git add . && git commit -m "chore: personalize" && git push
```

## 2. Install ArgoCD

```bash
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd -n argocd \
  --values cluster/infrastructure/argocd/argocd-values.yaml
```

Connect your fork in ArgoCD: **Settings → Repositories → Connect Repo** (HTTPS + GitHub PAT).

## 3. Deploy Stages in Order

```bash
kubectl apply -f cluster/stages/stage-1/service.yaml  # CNI, namespaces, NFS, ArgoCD
# wait for all apps Healthy + Synced
kubectl apply -f cluster/stages/stage-2/service.yaml  # DBs, nginx, cert-manager, VPN
# wait for all apps Healthy + Synced
kubectl apply -f cluster/stages/stage-3/service.yaml  # LLM, HA, Keycloak, Jenkins, Grafana
```

Monitor: `kubectl get applications -n argocd -w`

## 4. Access

Find ingress IP: `kubectl get svc -n proxy`

All apps available at `https://<service>.yourdomain.com`.

## Ongoing Changes

Edit a file → `git push` → ArgoCD auto-syncs within ~3 minutes.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| ArgoCD "Unknown" status | Check repo credentials in Settings → Repositories |
| App stuck "Progressing" | `kubectl describe pod -n <ns>` → check image pull / resource limits |
| Secrets fail to decrypt | `gpg --list-secret-keys` → verify key matches `.sops.yaml` |
