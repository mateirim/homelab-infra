# homelab-infra v1.0.0 — Initial Public Release

> **Release date:** 2026-05-05
> **Branch:** `main`
> **Commit:** `34f388c`

---

## 🎉 What is this?

**homelab-infra** is a production-grade, multi-architecture Kubernetes homelab GitOps template built on kubeadm, Cilium, and ArgoCD. It is designed to be forked, personalized via an interactive wizard (`setup.sh`), and deployed in roughly one hour.

This is the **first public release** — a complete, sanitized, and ready-to-fork infrastructure-as-code template.

---

## ✨ Highlights

- **3-stage deployment** (Foundation → Infrastructure → Applications) — ordered for clean dependency resolution
- **30+ applications** deployed via ArgoCD with Helm and Kustomize
- **SOPS + GPG** secrets encryption throughout — no plaintext credentials ever committed
- **Multi-arch** (amd64 + arm64) — Raspberry Pi workers supported alongside x86 control planes
- **Interactive setup wizard** (`setup.sh`) — fills all placeholders, generates passwords, encrypts secrets
- **Validation script** (`setup-validation.sh`) — verifies configuration before any cluster interaction
- **Full observability** — Prometheus, Grafana, Loki, Mimir, AlertManager, service monitors
- **AI/LLM stack** — Ollama, Open-WebUI, LiteLLM, Whisper (GPU-optional)
- **Puppet config management** — puppetserver, r10k, Hiera, Foreman reporting in-cluster

---

## 📦 What's Included

### Cluster Manifests (`cluster/`)
- `180` YAML manifests (Helm values, Kustomize overlays, ArgoCD Applications)
- `29` infrastructure namespaces
- `3` deployment stages (stage-1, stage-2, stage-3)
- `8` NetworkPolicies (database, Jenkins, ArgoCD)
- `26` RBAC roles (least-privilege per namespace)
- `133` health probes (liveness + readiness)

### Applications (Stage 3)
| Category | Applications |
|---|---|
| AI / LLM | Ollama · Open-WebUI · LiteLLM · Whisper |
| Observability | Prometheus · Grafana · Loki · Mimir · AlertManager |
| Identity | Keycloak SSO |
| CI/CD | Jenkins · GitHub Actions self-hosted runners |
| Config Management | Puppet · r10k · Foreman |
| Storage | Nextcloud · PhotoPrism · NFS provisioner |
| Smart Home | Home Assistant |
| Networking | Pi-hole DNS · WireGuard · Tailscale |
| Databases | PostgreSQL HA · MongoDB · Redis HA |

### Custom Containers (`homelab-helm-charts/containers/`)
- `puppetserver` — Puppet 8 server image (multi-arch)
- `r10k` — r10k control repo syncer
- `actions-runner` — self-hosted GitHub Actions runner
- `foreman` — Puppet reporting UI
- `promtail-syslog` — syslog-to-Loki forwarder
- `homelab-operator` — custom Kubernetes operator

### Architecture Decision Records (`cluster/docs/decisions/`)
- ADR-001: CNI Selection — Cilium (eBPF + BGP + IPAM)
- ADR-002: Secrets Management — SOPS + GPG
- ADR-003: Kubernetes Distribution — kubeadm vs k3s

---

## 🚀 Quick Start

```bash
# 1. Fork & clone
git clone https://github.com/YOUR_USERNAME/homelab-infra
cd homelab-infra

# 2. Personalize (fills placeholders, encrypts secrets)
./setup.sh

# 3. Validate before touching any cluster
./setup-validation.sh

# 4. Commit your personalized config and push
git add . && git commit -m "chore: personalize for my cluster" && git push

# 5. Bootstrap Kubernetes with kubeadm, then deploy stages
kubectl apply -f cluster/stages/stage-1/service.yaml
# wait → then:
kubectl apply -f cluster/stages/stage-2/service.yaml
# wait → then:
kubectl apply -f cluster/stages/stage-3/service.yaml
```

Full step-by-step: [GETTING_STARTED.md](GETTING_STARTED.md)

---

## 📋 Prerequisites

- 4–6 nodes (1 control plane + 3+ workers), 4GB RAM minimum per node
- NFS server for persistent storage
- Domain name + Cloudflare (or compatible) for Let's Encrypt DNS challenge
- GPG key for SOPS encryption
- GitHub Personal Access Token for ArgoCD repo access

See [HARDWARE.md](HARDWARE.md) for detailed sizing, degradation scenarios, and GPU guidance.

---

## 🔐 Security

All secrets are encrypted with SOPS + GPG and stored as `ENC[AES256_GCM,...]` blobs. No plaintext credentials are committed. See [SECURITY.md](SECURITY.md) for the vulnerability reporting policy.

---

## 📖 Documentation

| File | Purpose |
|---|---|
| [START_HERE.md](START_HERE.md) | 5-minute orientation for new users |
| [GETTING_STARTED.md](GETTING_STARTED.md) | Full step-by-step deployment guide |
| [HARDWARE.md](HARDWARE.md) | Node sizing, degradation scenarios, GPU guide |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [LICENSES.md](LICENSES.md) | Full license attribution for all 30+ OSS projects |
| [cluster/docs/](cluster/docs/) | ADRs, Helm charts reference, backup strategy, secrets rotation |

---

## ⚖️ License

[MIT License](LICENSE) — fork freely, modify as needed, keep the attribution.

Third-party software licenses documented in [LICENSES.md](LICENSES.md). Notable: Grafana, Loki, Mimir are AGPL 3.0 — see compliance notes.

---

## 🙏 Acknowledgements

Built on the shoulders of: Cilium, ArgoCD, Kubernetes, Prometheus, Grafana, cert-manager, Puppet, Jenkins, Keycloak, Ollama, and many more. See [LICENSES.md](LICENSES.md) for the full list.
