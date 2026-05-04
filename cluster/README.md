# Cluster Configuration

Kubernetes cluster definition managed by ArgoCD.

## Structure

- **config/** — kubeadm init config, containerd setup, CNI IP pool
- **infrastructure/** — ArgoCD Applications (one per namespace)
- **stages/** — 3-stage deployment (Stage 1: infra, Stage 2: databases, Stage 3: apps)
- **monitoring/** — Grafana dashboards
- **docs/** — Architecture diagrams and references

## Charts & Applications

All Helm charts (external + custom) are documented in **[docs/HELM-CHARTS.md](docs/HELM-CHARTS.md)**. This guide lists:
- External chart repositories and URLs
- Custom charts in `helm-charts/charts/`
- How to add new charts to the cluster

## Setup Order

1. Run `./setup.sh` from repo root
2. Install containerd (see helm-charts/commands/containerd/README.md)
3. Bootstrap control plane: `kubeadm init --config cluster/config/kubeadm-init-2026.yaml`
4. Join workers: `kubeadm join ...`
5. Install CNI: `helm install cilium cilium/cilium -n kube-system -f cluster/infrastructure/cni/cilium-values.yaml`
6. Deploy stages via ArgoCD

## Deploy Order

Infrastructure must deploy in this order:
1. **cni** — Cilium (required by all)
2. **namespaces** — Kubernetes namespaces
3. **certs** — TLS certificates
4. **registry** — Container registry
5. Rest in any order

## Networking

- Pod subnet: 10.200.0.0/16
- Service subnet: 10.172.0.0/16
- CNI: Cilium with BGP + LoadBalancer IPAM

## WSL / Windows

For Cilium on WSL, ensure shared propagation:
```bash
mount --make-rshared /
```
