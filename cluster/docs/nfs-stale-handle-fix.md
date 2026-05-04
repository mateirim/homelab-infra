# NFS Stale File Handle Fix

## Problem
Kubernetes pods using NFS volumes may encounter the "stale NFS file handle" error (ESTALE). This typically happens when the NFS server restarts or when an inode on the server is changed/removed/replaced, but the client (the Kubernetes node) still holds a reference to the old inode in its cache.

In our cluster, this was specifically occurring on the `gpu-node-2` node for the Home Assistant deployment.

## Solution
To solve this persistently, the `PersistentVolume` (PV) mount options were updated to be more resilient by disabling client-side attribute and name caching.

### Updated Mount Options
The following options were added to the PV definitions:

- `lookupcache=none`: Forces the client to re-validate name lookups with the server instead of relying on local cache. This is the most effective way to prevent stale handles in Kubernetes.
- `noac` (or `actimeo=0`): Disables attribute caching entirely. While this has a minor performance impact, it ensures the client always has the correct file metadata.
- `vers=4.2`: Updated to use NFS version 4.2 for better stability and performance.
- `noatime`: Disables access time updates to reduce write operations on the NFS server.

### Implementation
The changes were applied to:
- `infrastructure/homeassistant/pvc.yaml`

### Manual Recovery
If a node is already in a stale state, it may be necessary to manually unmount the stale handle on the host:
```bash
# On the affected node
sudo umount -f -l /var/lib/kubelet/pods/<pod-uid>/volumes/kubernetes.io~nfs/<pv-name>
```
Or use a privileged pod to perform the unmount if direct SSH is not available.
