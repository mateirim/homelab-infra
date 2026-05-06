# Backup Strategy

## What to Back Up

| Component | Tool | Frequency | Retention |
| --- | --- | --- | --- |
| Cluster state + PVs | Velero | Hourly | 7 days |
| Databases (pg_dump, mongodump) | App-native | Daily | 7 days |
| Offsite archive | rsync / S3 | Weekly | 3 months |

Git repo is backed up automatically via GitHub.

## Velero (NFS)

```bash
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero -n velero --create-namespace \
  --set configuration.backupStorageLocation.provider=openebs \
  --set configuration.schedules.hourly.schedule="0 * * * *" \
  --set configuration.schedules.hourly.template.ttl="168h"
```

Manual backup before major changes:

```bash
velero backup create pre-change-$(date +%Y%m%d-%H%M%S)
```

## Restore

```bash
velero backup get
velero restore create --from-backup <backup-name>
kubectl get all -A  # verify
```

For a full cluster rebuild: bootstrap fresh cluster → install Velero with same config → restore latest backup.

## Checklist

- [ ] Velero running and backups scheduled
- [ ] Database backups running (PostgreSQL, MongoDB)
- [ ] Offsite sync configured
- [ ] Restore tested at least once
- [ ] Velero failure alert in Prometheus (`velero_backup_failure_total`)
