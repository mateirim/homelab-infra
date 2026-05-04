# Mount your NFS/data disk — replace UUID and mount point with your values
# UUID=YOUR_DISK_UUID /mnt/data ntfs-3g async,permissions,locale=en_US.utf8,rsize=131072,wsize=131072 0 2

# /etc/exports entries for your NFS server — replace path with your base path
# /mnt/data *(sync,rw,no_wdelay,no_subtree_check,no_root_squash,insecure)
# /mnt/data/kube *(sync,rw,no_wdelay,no_subtree_check,no_root_squash,insecure)
# /mnt/data/docker *(sync,rw,no_wdelay,no_subtree_check,anonuid=0,anongid=0)
