# Backup Strategy: Protecting Your Homelab

This guide explains the backup strategy for homelab-infra and how to implement it.

## What Needs Backing Up?

Your Kubernetes cluster has critical data that must be protected:

| Component | Data | Criticality | Backup Method |
|-----------|------|------------|---------------|
| **etcd** | Cluster state, all resources | Critical | Velero (automated) |
| **Persistent Volumes** | Database data, config files | Critical | Velero (automated) |
| **Git Repository** | Infrastructure code | Medium | GitHub (automatic) |
| **ArgoCD State** | Application configurations | Low | Stored in etcd |
| **Application Data** | Grafana dashboards, Jenkins jobs, etc. | Medium | App-specific backups |

---

## Overview: 3-Layer Backup Strategy

```
┌─────────────────────────────────────────────┐
│ Layer 1: Cluster State (etcd) + Volumes     │
│ Tool: Velero                                 │
│ Frequency: Hourly                           │
│ Retention: 30 days                          │
│ Restore Time: ~10 minutes                   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ Layer 2: Database Backups                   │
│ Tool: App-native (pg_dump, mongodump, etc.) │
│ Frequency: Daily                            │
│ Retention: 7 days                           │
│ Restore Time: ~2-5 minutes                  │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ Layer 3: Offsite Archives                   │
│ Tool: S3, NFS, USB (external storage)       │
│ Frequency: Weekly                           │
│ Retention: 3 months                         │
│ Restore Time: Manual, depends on size      │
└─────────────────────────────────────────────┘
```

---

## Layer 1: Cluster State with Velero

Velero is a Kubernetes-native backup tool that backs up:
- All etcd data (cluster state)
- All persistent volumes
- All Kubernetes objects

### Installation (Manual or via Helm)

Choose your backup storage:

#### Option A: NFS (Homelab-friendly)

If you already have NFS storage:

```bash
# 1. Create backup directory on NFS
mkdir -p /mnt/nfs/velero-backups
chmod 777 /mnt/nfs/velero-backups

# 2. Create PersistentVolume for Velero
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: velero-backups-pv
spec:
  capacity:
    storage: 500Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: REPLACE_WITH_NFS_SERVER_IP
    path: "/mnt/nfs/velero-backups"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: velero-backups-pvc
  namespace: velero
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ""
  volumeName: velero-backups-pv
  resources:
    requests:
      storage: 500Gi
EOF

# 3. Install Velero via Helm
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  --set configuration.backupStorageLocation.provider=openebs \
  --set configuration.backupStorageLocation.bucket=velero \
  --set configuration.schedules.daily.schedule="0 2 * * *" \
  --set configuration.schedules.daily.template.ttl="720h"
```

#### Option B: Minio (S3-compatible, if you have it)

```bash
helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  --set configuration.backupStorageLocation.provider=aws \
  --set configuration.backupStorageLocation.bucket=velero \
  --set configuration.backupStorageLocation.config.s3Url=https://minio.REPLACE_WITH_YOUR_DOMAIN \
  --set configuration.backupStorageLocation.config.s3ForcePathStyle=true \
  --set configuration.schedules.hourly.schedule="0 * * * *" \
  --set configuration.schedules.hourly.template.ttl="720h"
```

#### Option C: AWS S3 (Cloud-based)

```bash
# Requires AWS credentials in secret
helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  --set configuration.backupStorageLocation.provider=aws \
  --set configuration.backupStorageLocation.bucket=homelab-backups \
  --set configuration.backupStorageLocation.config.region=us-east-1 \
  --set configuration.schedules.daily.schedule="0 2 * * *" \
  --set configuration.schedules.daily.template.ttl="720h"
```

### Verify Velero Installation

```bash
# Check Velero is running
kubectl get pods -n velero

# Check storage location
velero backup-location get

# Expected output:
# NAME      PROVIDER   BUCKET/PREFIX             STATUS
# default   openebs    velero                    Available
```

### Manual Backup

```bash
# Create an ad-hoc backup (e.g., before making major changes)
velero backup create my-manual-backup-$(date +%Y%m%d-%H%M%S)

# List all backups
velero backup get

# Check backup progress
velero backup describe my-manual-backup-20260504-120000 --details

# Wait for completion
velero backup logs my-manual-backup-20260504-120000
```

### Restore from Velero Backup

```bash
# List available backups
velero backup get

# Restore the entire cluster from a specific backup
velero restore create --from-backup my-manual-backup-20260504-120000

# Monitor restore progress
velero restore get
velero restore logs my-manual-backup-20260504-120000-20260504-120100

# Verify cluster state after restore
kubectl get all -A
```

---

## Layer 2: Database Backups

Each database (PostgreSQL, MongoDB, Redis) should have automated backups.

### PostgreSQL Backup

PostgreSQL operator in `cluster/infrastructure/postgresql/` includes automated backups.

**Manual backup:**
```bash
# Find PostgreSQL pod
kubectl get pods -n database | grep postgres

# Create backup
kubectl exec -it <postgres-pod> -n database -- \
  pg_dump -U postgres > /tmp/homelab-$(date +%Y%m%d).sql

# Restore from backup
kubectl exec -it <postgres-pod> -n database -- \
  psql -U postgres < /tmp/homelab-20260504.sql
```

### MongoDB Backup

```bash
# Find MongoDB pod
kubectl get pods -n database | grep mongo

# Create backup
kubectl exec -it <mongo-pod> -n database -- \
  mongodump --out /tmp/mongo-backup-$(date +%Y%m%d)

# Compress and save
kubectl exec -it <mongo-pod> -n database -- tar czf - /tmp/mongo-backup-* > /tmp/mongo.tar.gz

# Restore
kubectl exec -it <mongo-pod> -n database -- \
  mongorestore /tmp/mongo-backup-20260504
```

### Redis Backup

Redis stores snapshots in a `dump.rdb` file:

```bash
# Find Redis pod
kubectl get pods -n database | grep redis

# Save a snapshot
kubectl exec -it <redis-pod> -n database -- redis-cli BGSAVE

# Copy the RDB file
kubectl cp database/<redis-pod>:/data/dump.rdb /tmp/redis-dump-$(date +%Y%m%d).rdb

# Restore
kubectl cp /tmp/redis-dump-20260504.rdb database/<redis-pod>:/data/dump.rdb
```

---

## Layer 3: Offsite Archives

For disaster recovery, archive backups to external storage:

### Option A: NFS External Drive

```bash
# Mount external NFS on your workstation
mkdir -p ~/backups/homelab
mount -t nfs REPLACE_WITH_EXTERNAL_NFS_IP:/export/homelab ~/backups/homelab

# Copy Velero backups
rsync -avz /var/lib/velero/backups/ ~/backups/homelab/velero/

# Copy database backups
rsync -avz /tmp/*.sql ~/backups/homelab/databases/
```

### Option B: S3 Synchronization

```bash
# Sync Velero backups to S3 bucket (once per week)
aws s3 sync /var/lib/velero/backups/ s3://homelab-archives/velero/ --storage-class GLACIER

# Or with MinIO CLI (mc)
mc cp --recursive /var/lib/velero/backups/ s3/homelab-archives/velero/
```

### Option C: USB Drive (Cold Backup)

```bash
# Mount USB drive
sudo mount /dev/sdb1 /mnt/usb

# Copy backups
sudo cp -r /var/lib/velero/backups/* /mnt/usb/velero/
sudo cp /tmp/*.sql /mnt/usb/databases/

# Unmount
sudo umount /mnt/usb
```

---

## Backup Testing & Validation

**A backup that hasn't been tested is not a backup.**

### Monthly Restore Test

Every month, test restoration:

```bash
# 1. Create a test namespace
kubectl create namespace backup-test

# 2. Restore latest backup into the test namespace
velero restore create --from-backup <latest-backup> \
  --namespace-mappings default=backup-test

# 3. Verify restoration
kubectl get all -n backup-test

# 4. Spot-check key data
kubectl exec -it backup-test/postgres-pod -- psql -U postgres -l  # List databases

# 5. Clean up test
kubectl delete namespace backup-test
```

### Backup Monitoring

Monitor backup success in Prometheus/Grafana:

```bash
# Velero exports metrics like:
# velero_backup_duration_seconds  (how long backups take)
# velero_backup_total_size_bytes  (backup size)
# velero_backup_failure_total     (failed backup count)

# Create Prometheus alert for failed backups:
# alert: VeleroBackupFailure
#   expr: increase(velero_backup_failure_total[1h]) > 0
#   for: 1h
#   annotations:
#     summary: "Velero backup failed"
```

---

## Recovery Procedures

### Scenario 1: Single Pod Crash

**Symptom:** One application pod crashed and lost data

```bash
# Find the backup before the crash
velero backup get

# Restore just that pod's data
velero restore create \
  --from-backup <backup-name> \
  --include-resources pods \
  --include-namespaces <app-namespace>
```

### Scenario 2: Entire Application Down

**Symptom:** A whole application namespace is broken

```bash
# Restore the entire namespace from Velero
velero restore create \
  --from-backup <backup-name> \
  --include-namespaces <app-namespace>
```

### Scenario 3: Complete Cluster Failure

**Symptom:** Entire cluster is down, need full restore

1. **Bootstrap a fresh cluster** (using kubeadm or similar)
2. **Install Velero** (same configuration as before)
3. **Restore from backup:**
   ```bash
   velero restore create --from-backup <latest-backup>
   ```
4. **Verify cluster came up:** `kubectl get all -A`

### Scenario 4: etcd Corruption

**Symptom:** Cluster works but some objects are corrupted/missing

```bash
# Restore from Velero snapshot
velero restore create --from-backup <backup-before-corruption>

# Carefully apply only the corrupted objects if needed
kubectl apply -f <objects-to-restore>.yaml
```

---

## Backup Checklist

Use this checklist to verify your backup strategy is working:

- [ ] Velero installed and running (`kubectl get pods -n velero`)
- [ ] Backups scheduled (daily/hourly) and running (`velero backup get`)
- [ ] Backup storage location is available and has space
- [ ] Database backups (PostgreSQL, MongoDB) are running
- [ ] Archives are synced offsite (weekly)
- [ ] Monthly restore test completed successfully
- [ ] Alerts configured for failed backups
- [ ] Team members know restore procedure
- [ ] Recovery Time Objective (RTO) documented: __ minutes
- [ ] Recovery Point Objective (RPO) documented: __ minutes

---

## Retention Policies

| Backup Type | Frequency | Retention | Use Case |
|-------------|-----------|-----------|----------|
| **Velero hourly** | Every hour | 7 days | Recent mishaps, quick recovery |
| **Velero daily** | Every day | 30 days | Standard disaster recovery |
| **Database backups** | Every night | 7 days | Database-specific recovery |
| **Offsite archives** | Weekly | 3 months | Ransomware, hardware failure |
| **Annual archives** | Yearly | 1 year | Compliance, historical data |

---

## Cost Estimation

Backup storage costs (rough estimates):

- **NFS (external drive):** $100-300 one-time
- **Minio (self-hosted S3):** $0 (use existing hardware)
- **AWS S3 Glacier:** ~$1-5/month for homelab-sized data
- **Total:** Minimal for homelab; higher for enterprise

---

## References

- [Velero Documentation](https://velero.io/docs/)
- [Kubernetes Backup Best Practices](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- [PostgreSQL Backup Guide](https://www.postgresql.org/docs/current/backup.html)
- [MongoDB Backup Guide](https://docs.mongodb.com/manual/core/backups/)
