# ADR-003: Kubernetes Distribution — kubeadm

**Status:** Accepted (Active)

**Date:** 2026-05-04

**Authors:** Matei Rimboaca

---

## Context

Multiple ways to bootstrap a Kubernetes cluster exist:
- **kubeadm** — Official Kubernetes tool, full-featured, verbose setup
- **k3s** — Lightweight, single binary, designed for edge/IoT
- **RKE / RKE2** — Rancher's offerings, excellent for production clusters
- **kops** — AWS-focused Kubernetes operations
- **Kubespray** — Ansible-based, enterprise-grade

This homelab environment is:
- Self-hosted on multiple node types (x86 servers + Raspberry Pi)
- Educational (learning how Kubernetes works internally)
- Multi-node (6+ nodes, not just one cluster)
- Needs full control over configurations (kernel tuning, container runtime, etc.)

---

## Decision

**Use kubeadm for cluster bootstrapping** with:
- Official kubeadm tool for control plane and worker setup
- Manual kernel tuning and system preparation (Puppet)
- containerd as the container runtime
- v1.35.0+ (latest stable Kubernetes version)

---

## Rationale

### Why kubeadm over k3s

1. **Educational value**
   - kubeadm teaches how Kubernetes components work
   - You interact with etcd, scheduler, controller-manager configs
   - Good for learning; k3s hides complexity (opinionated defaults)
   - This repo is partly educational

2. **Full-featured Kubernetes**
   - kubeadm = official Kubernetes (unmodified)
   - k3s = stripped-down distribution (some features removed by default)
   - We need all features (NetworkPolicies, metrics-server, etc.)

3. **Multi-node heterogeneous setup**
   - kubeadm works seamlessly on any Linux (amd64, ARM64, ARM)
   - k3s can be slower on weak hardware (Raspberry Pi)
   - We run both; kubeadm has better performance parity

4. **System tuning control**
   - kubeadm requires explicit kernel tuning (Puppet does this)
   - Teaches what Linux needs for Kubernetes
   - k3s abstracts away these details

5. **Industry standard**
   - kubeadm is what enterprises use
   - Learning kubeadm prepares you for real Kubernetes work
   - k3s is good for specific use cases (edge, IoT, demo), not learning

### Why not k3s

- **Opinionated:** k3s makes decisions for you (no choice in CNI, storage, etc.)
- **Resource overhead:** Lightweight claim is overstated (etcd, etc. still needed)
- **Less flexible:** Harder to customize components
- **Edge/IoT focus:** Designed for constrained devices, not learning environments

**Exception:** If you have a single-node hobby cluster, k3s is better.

### Why not RKE / RKE2

- **Vendor lock-in:** Rancher-specific (though excellent products)
- **Overkill:** Enterprise features we don't need
- **Learning value:** Less educational about core Kubernetes

### Why not Kubespray

- **Complexity:** Ansible-based setup is overkill for this use case
- **Flexibility trade-off:** More options = harder to learn
- **Puppet-based approach:** We use Puppet for node prep, kubeadm for Kubernetes

---

## Implementation

### Bootstrap Process

1. **Prepare nodes with Puppet** (cluster/config/kubeadm-init-2026.yaml)
   - Kernel tuning (ip_forward, bridge settings, etc.)
   - Install containerd
   - Install kubelet, kubeadm, kubectl
   - Disable swap

2. **Run kubeadm init** (control plane)
   ```bash
   kubeadm init --config=/path/to/kubeadm-init-2026.yaml
   ```

3. **Configure CNI** (Cilium, via ArgoCD)
   - Cilium deployed after cluster is up
   - kubeadm doesn't install CNI; you choose one

4. **Join worker nodes**
   ```bash
   kubeadm join --token=<token> --discovery-token-ca-cert-hash=<hash>
   ```

5. **Verify cluster**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

### Configuration File (cluster/config/kubeadm-init-2026.yaml)

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
bootstrapToken:
  token: REPLACE_WITH_BOOTSTRAP_TOKEN
  ttl: 24h
certificateKey: REPLACE_WITH_CERTIFICATE_KEY
localAPIEndpoint:
  advertiseAddress: REPLACE_WITH_CONTROL_PLANE_IP
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  taints:
    - effect: NoSchedule
      key: node-role.kubernetes.io/control-plane
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.35.0
networking:
  podSubnet: 10.200.0.0/16
  serviceSubnet: 10.172.0.0/16
controlPlaneEndpoint: kube.REPLACE_WITH_YOUR_DOMAIN:6443
certificateDir: /etc/kubernetes/pki
certificateValidity:
  duration: 8760h0m0s  # 1 year
etcd:
  local:
    dataDir: /var/lib/etcd
```

---

## Consequences

### Positive

✅ **Full Kubernetes:** No stripped features, all tools available
✅ **Educational:** Learn how Kubernetes actually works
✅ **Flexible:** Configure every component
✅ **Industry standard:** Skills transfer to enterprise Kubernetes
✅ **Multi-arch:** Seamless amd64 + ARM64 support
✅ **Proven:** kubeadm is battle-tested in production clusters

### Negative

❌ **Manual setup:** More steps than k3s
❌ **Documentation:** Requires understanding Kubernetes concepts
❌ **Debugging:** More moving parts (etcd, scheduler, controller-manager, etc.)
❌ **Resource overhead:** Full Kubernetes uses more resources than k3s (but marginal)

### Mitigations

- Puppet automates node preparation
- `setup.sh` personalizes kubeadm config
- Documentation and troubleshooting guides provided
- ArgoCD handles cluster management (after bootstrap)

---

## Comparison Table

| Aspect | kubeadm | k3s | RKE2 | Kubespray |
|--------|---------|-----|------|-----------|
| **Kubernetes version** | Latest official | Fixed distro | Recent official | Latest official |
| **Learning value** | Excellent | Poor | Good | Complex |
| **Setup time** | 30-45 min | 5 min | 15 min | 1-2 hours |
| **Customization** | Full | Limited | Good | Excellent |
| **Resource usage** | Standard K8s | Lightweight | Standard K8s | Standard K8s |
| **Multi-arch** | Excellent | Good | Good | Excellent |
| **Enterprise** | Standard | Edge/IoT | Good | Very good |
| **Community** | Largest | Growing | Large | Growing |

---

## Future Considerations

If this repo evolves:
- **Single-node demo cluster?** Consider k3s
- **Managed Kubernetes (cloud)?** Skip this entirely; use EKS/GKE/AKS
- **Larger production cluster?** Consider Kubespray or RKE2 for automation

---

## Related Decisions

- [ADR-001: CNI (Cilium)](ADR-001-CNI-Cilium.md)
- [ADR-002: Secrets Management (SOPS)](ADR-002-Secrets-SOPS.md)

---

## References

- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [kubeadm Configuration Reference](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/)
- [k3s Documentation](https://docs.k3s.io/)
- [kubeadm vs k3s Comparison](https://stackoverflow.com/questions/57433643/kubeadm-vs-k3s)
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) (excellent learning resource)
