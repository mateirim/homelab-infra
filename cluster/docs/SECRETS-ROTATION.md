# Secrets Rotation

## GPG Key Rotation

```bash
gpg --full-generate-key
NEW_KEY_ID=<new-16-digit-id>

# Re-encrypt all secrets with new key
sed -i "s/OLD_KEY_ID/$NEW_KEY_ID/" .sops.yaml
find . -name "*secret*.yaml" | xargs -I{} sops -e --in-place --pgp "$NEW_KEY_ID" {}

git add .sops.yaml && git commit -m "chore: rotate GPG key" && git push
```

Backup the new key: `gpg --export-secret-keys --armor $NEW_KEY_ID > gpg-backup.asc`

## Database Passwords

```bash
# PostgreSQL
NEW_PASS=$(openssl rand -base64 16)
# Edit cluster/infrastructure/postgresql/secret.yaml, set new password
sops --encrypt --in-place cluster/infrastructure/postgresql/secret.yaml
git add . && git commit -m "chore: rotate postgres password" && git push
kubectl rollout restart statefulset/postgres -n database

# MongoDB
kubectl exec -it mongodb-0 -n database -- \
  mongosh --eval "db.changeUserPassword('root', '$NEW_PASS')"

# Redis
kubectl exec -it redis-master-0 -n database -- \
  redis-cli CONFIG SET requirepass "$NEW_PASS"
```

## ArgoCD Repo Credentials

```bash
kubectl patch secret argocd-repo-creds -n argocd --type merge \
  -p '{"data":{"password":"'$(echo -n "<NEW_TOKEN>" | base64)'"}}'
kubectl rollout restart deployment/argocd-server -n argocd
```

## TLS Certificates

Handled automatically by cert-manager (renews 30 days before expiry). Force renewal:

```bash
kubectl annotate certificate -n certs --all \
  cert-manager.io/issue-temporary-certificate=true --overwrite
```

## Emergency Recovery

If GPG key is lost, restore from backup then re-deploy:

```bash
gpg --import gpg-backup.asc
./setup.sh  # re-personalize with restored key
kubectl apply -f cluster/stages/stage-1/service.yaml
```
