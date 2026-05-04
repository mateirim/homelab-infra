# Secrets Rotation Guide

This guide covers rotating encrypted secrets (SOPS) and database passwords in homelab-infra without downtime.

## GPG Key Rotation

**When:** Annually or if key is compromised.

### Generate a new GPG key

```bash
gpg --full-generate-key
# Follow prompts: RSA 4096, expire in 1 year, set passphrase
gpg --list-secret-keys --keyid-format LONG
# Copy the new 16-digit key ID
```

### Re-encrypt all secrets with new key

```bash
# Update .sops.yaml with new key ID
sed -i 's/F81E8088C755BB28/<NEW_KEY_ID>/g' .sops.yaml

# Re-encrypt all secret files
find . -name "*secret*.yaml" -o -name "*secrets*.yaml" | while read f; do
  sops -e --in-place --pgp "<NEW_KEY_ID>" "$f"
done

git add .sops.yaml && git commit -m "chore: rotate GPG key to <NEW_KEY_ID>"
git push
```

### Distribute new GPG key to cluster operators

```bash
# Export public key
gpg --export --armor <NEW_KEY_ID> > new-gpg-key.pub

# Import on operator machine
gpg --import new-gpg-key.pub

# Verify
gpg --list-keys <NEW_KEY_ID>
```

## Database Password Rotation

### PostgreSQL

Database migrations can happen without downtime using connection pooling (PgBouncer) as a proxy, but for simplicity, we'll update the secret and trigger a pod restart.

1. **Generate new password**
   ```bash
   NEW_PG_PASS=$(openssl rand -base64 16)
   echo "New PostgreSQL password: $NEW_PG_PASS"
   ```

2. **Update SOPS secret**
   ```bash
   kubectl get secret -n database postgres-secret -o yaml > /tmp/pg-secret.yaml
   # Edit /tmp/pg-secret.yaml, change password field
   kubectl apply -f /tmp/pg-secret.yaml
   ```

3. **Restart PostgreSQL pod**
   ```bash
   kubectl rollout restart statefulset/postgres -n database
   kubectl rollout status statefulset/postgres -n database
   ```

4. **Verify connectivity**
   ```bash
   kubectl run -it --rm debug --image=postgres:latest --restart=Never -- \
     psql -h postgres.database.svc.cluster.local -U postgres -c "SELECT 1;"
   ```

### MongoDB

Similar process to PostgreSQL:

```bash
kubectl exec -it mongodb-0 -n database -- mongosh --eval \
  "db.changeUserPassword('root', '<NEW_PASSWORD>')"

kubectl rollout restart statefulset/mongodb -n database
```

### Redis HA

Redis HA (Sentinel) doesn't require password for inter-node communication by default. If using password auth:

```bash
kubectl exec -it redis-master-0 -n database -- redis-cli CONFIG SET requirepass "<NEW_PASSWORD>"
kubectl rollout restart statefulset/redis -n database
```

## Application Secret Rotation

### Keycloak Admin Password

```bash
kubectl exec -it keycloak-0 -n keycloak -- \
  kcadm.sh update-password \
  --cclientid admin-cli \
  --username admin \
  --password-temp \
  --new-password "<NEW_PASSWORD>"
```

### Jenkins Admin Password

Jenkins stores passwords in encrypted format. Update via UI or CLI:

```bash
kubectl port-forward svc/jenkins 8080:8080 -n jenkins

# Via UI: Manage Jenkins → Security → User
# Or via Jenkins CLI (requires SSH key)
java -jar jenkins-cli.jar -s http://localhost:8080 \
  set-password admin "<NEW_PASSWORD>"
```

### Grafana Admin Password

```bash
kubectl exec -it grafana-0 -n grafana -- \
  grafana-cli admin reset-admin-password "<NEW_PASSWORD>"
```

## ArgoCD Secret Rotation

ArgoCD stores repository credentials and API tokens in sealed-secrets (or SOPS for this setup).

1. **Update repository credentials in ArgoCD**
   ```bash
   kubectl patch secret argocd-repo-creds -n argocd --type merge -p \
     '{"data":{"password":"'$(echo -n "<NEW_TOKEN>" | base64)'"}}' 
   ```

2. **Restart ArgoCD server to reload credentials**
   ```bash
   kubectl rollout restart deployment/argocd-server -n argocd
   ```

## Let's Encrypt Certificate Rotation

Handled automatically by cert-manager. Certificates are renewed 30 days before expiry.

To force renewal:

```bash
kubectl annotate certificate -n certs --all cert-manager.io/issue-temporary-certificate=true --overwrite
```

Check renewal status:

```bash
kubectl get certificate -n certs -o wide
```

## Backup Before Rotation

Always backup encrypted secrets before rotating:

```bash
# Backup all secrets
mkdir -p ~/.homelab-backups/$(date +%Y-%m-%d)
tar czf ~/.homelab-backups/$(date +%Y-%m-%d)/secrets-backup.tar.gz \
  $(find . -name "*secret*.yaml" -o -name "*secrets*.yaml")

# Backup GPG key
gpg --export-secret-keys --armor <KEY_ID> > ~/.homelab-backups/gpg-key-backup.asc
# Encrypt the backup
openssl enc -aes-256-cbc -in ~/.homelab-backups/gpg-key-backup.asc -out ~/.homelab-backups/gpg-key-backup.asc.enc
```

## Emergency Secret Recovery

If all secrets are lost and GPG key is inaccessible:

1. **Recover GPG key from backup**
   ```bash
   gpg --import ~/.homelab-backups/gpg-key-backup.asc
   gpg --edit-key <KEY_ID>
   # Type: trust → 5 (ultimate) → quit
   ```

2. **Restore from backup**
   ```bash
   tar xzf ~/.homelab-backups/$(date +%Y-%m-%d)/secrets-backup.tar.gz
   git add . && git commit -m "restore: recover from backup"
   ```

3. **Re-deploy cluster**
   ```bash
   ./setup.sh  # re-personalize
   # Redeploy via ArgoCD: kubectl apply -f cluster/stages/stage-1/service.yaml
   ```

## Best Practices

- **Rotate secrets quarterly** for production environments
- **Test rotation procedures** in non-production first
- **Keep GPG key backups encrypted** in a separate location (USB, password manager, etc.)
- **Document rotation dates** in a secure log
- **Use different passwords for each service** (no password reuse across PostgreSQL, Keycloak, Jenkins, etc.)
- **Monitor for failed authentication** after rotation (check pod logs for connection errors)
