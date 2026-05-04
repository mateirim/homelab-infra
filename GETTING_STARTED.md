# Getting Started: Deploy homelab-infra

This guide walks you through personalizing the template and deploying your Kubernetes cluster.

> **First time?** Check [HARDWARE.md](HARDWARE.md) to ensure your nodes meet minimum requirements. See [README.md](README.md) for a quick overview.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] **5+ nodes** (1 control plane + 4+ workers)
- [ ] **NFS server** with shared storage configured
- [ ] **Domain name** (e.g., `example.com`)
- [ ] **DNS servers** (for external-dns integration)
- [ ] **GPG key** — run `gpg --list-secret-keys --keyid-format LONG` (or `gpg --full-generate-key` to create one)
- [ ] **GitHub Personal Access Token** (Settings → Developer settings → Personal access tokens)
- [ ] **DNS/Certificate provider** (e.g., Cloudflare API token for Let's Encrypt validation)

If you're missing any of these, stop here and set them up first. The setup script will ask for them all.

---

## Step 1: Personalize Configuration (5 min)

Run the setup wizard:

```bash
./setup.sh
```

You'll be prompted for:

1. **Domain** — Your cluster's base domain (e.g., `example.com`)
2. **Control plane node** — Hostname and IP address
3. **Worker nodes** — Hostnames and IPs
4. **NFS server** — IP address and export path
5. **DNS forwarders** — IPs of your DNS servers
6. **GitHub token** — For ArgoCD to access your forked repo
7. **GPG key ID** — For SOPS encryption (from `gpg --list-secret-keys`)

**What the script does:**
- Fills all `REPLACE_WITH_*` placeholders
- Generates random passwords for databases, API keys, etc.
- Encrypts all secrets with SOPS + your GPG key
- Creates `.sops.yaml` with your key configuration
- Configures ArgoCD to sync from your forked repository

**About SOPS + `.sops.yaml`:**

Before running `setup.sh`, you can preview the expected SOPS configuration by reading [`.sops.yaml.example`](.sops.yaml.example). This file shows the structure that `setup.sh` will generate with your GPG key. The actual `.sops.yaml` file (created by `setup.sh`) is automatically gitignored to protect your key fingerprint.

**Output:** All files in `cluster/`, `jenkins-repo/`, and `puppet-control-repo/` are personalized and encrypted.

---

## Step 2: Validate Configuration (1 min)

Run the validation script:

```bash
./setup-validation.sh
```

**Expected output:**
```
✓ All REPLACE_WITH_ placeholders filled
✓ SOPS configured with GPG key: <YOUR_KEY_ID>
✓ GPG key is installed and accessible
✓ SOPS encryption works
✓ SOPS decryption works
✓ Found 30 ArgoCD Applications
✓ All infrastructure namespaces have ArgoCD Applications
✓ No hardcoded infrastructure details found
✓ All secrets are SOPS-encrypted
✓ Git repository initialized
✓ Working tree clean

=== Summary ===
✓ All checks passed!
```

If any checks fail:
- **Placeholders remain** — Re-run `./setup.sh` and check its output
- **GPG key not found** — Ensure your GPG key is in your local keyring: `gpg --list-keys YOUR_KEY_ID`
- **SOPS encryption failed** — Check that your GPG key is accessible and not password-protected (or use `gpg-agent`)

---

## Step 3: Commit and Push (2 min)

Save your personalized configuration:

```bash
git add .
git commit -m "chore: personalize homelab-infra for my cluster"
git push origin main
```

**Why:** ArgoCD needs your forked repo URL (not upstream) to sync with your personalized config.

---

## Step 4: Prepare Your Nodes

On each node, install prerequisites:

```bash
# Install containerd, kubeadm, kubelet, kubectl
curl -fsSL https://get.docker.com/releases/containerd/install.sh | sh
sudo apt-get install -y kubeadm kubelet kubectl

# Copy containerd config
sudo cp cluster/config/containerd.yaml /etc/containerd/config.toml
sudo systemctl restart containerd

# Optional: If using NVIDIA GPUs
sudo cp cluster/config/nvidia-config.toml /etc/containerd/config.d/nvidia.toml
```

See `cluster/README.md` for full node setup instructions.

---

## Step 5: Bootstrap Kubernetes (10-15 min)

### On Control Plane Node

```bash
# Initialize cluster
sudo kubeadm init --config=cluster/config/kubeadm-init-2026.yaml

# Set up kubeconfig
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
kubectl get nodes
```

### On Each Worker Node

```bash
# Get the join command from control plane
kubeadm token create --print-join-command

# Run the join command on each worker
sudo kubeadm join <control-plane-ip>:6443 --token=... --discovery-token-ca-cert-hash=...

# Verify on control plane
kubectl get nodes
```

Wait for all nodes to be `Ready`:

```bash
kubectl get nodes -w
```

---

## Step 6: Deploy Stage 1 (Foundation) (5-10 min)

Stage 1 deploys the network foundation: Cilium CNI, namespaces, NFS provisioner, Prometheus CRDs, and ArgoCD.

```bash
kubectl apply -f cluster/stages/stage-1/service.yaml
```

**What gets deployed:**
- Cilium CNI (networking + BGP)
- 29 infrastructure namespaces
- NFS dynamic provisioner
- Prometheus CustomResourceDefinitions
- ArgoCD (GitOps controller)

**Monitor progress:**

```bash
# Watch ArgoCD Application status
kubectl get applications -A

# Check pod status
kubectl get pods -A -w

# View logs if needed
kubectl logs -n argocd deployment/argocd-application-controller
```

**Wait until:**
- All ArgoCD Applications show `Synced` status
- All pods in `kube-system`, `argocd`, `nfs` are `Running`

---

## Step 7: Deploy Stage 2 (Infrastructure) (10-20 min)

Stage 2 deploys databases, TLS, DNS, registry, VPN, and other infrastructure.

```bash
kubectl apply -f cluster/stages/stage-2/service.yaml
```

**What gets deployed:**
- PostgreSQL, MongoDB, Redis (HA)
- cert-manager + Let's Encrypt
- nginx ingress controller
- Pi-hole DNS
- Docker container registry
- WireGuard VPN
- GitHub Actions self-hosted runners

**Monitor progress:**

```bash
kubectl get applications -A
kubectl get pods -A --sort-by=.status.phase
```

### ⏸️ CRITICAL WAITING POINT: LoadBalancer IPs

Before proceeding to Stage 3, **all LoadBalancer services must have external IPs**. This can take 2-5 minutes.

```bash
# Check LoadBalancer status (watch until all have IPs)
kubectl get svc -A | grep LoadBalancer

# Expected output:
# NAMESPACE     NAME                TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)
# proxy         nginx               LoadBalancer   10.96.100.1     192.168.1.100  80:30080/TCP
# database      postgres            LoadBalancer   10.96.100.2     192.168.1.101  5432:32543/TCP
```

**Wait until:**

- ✅ nginx LoadBalancer has external IP (from Cilium IPAM pool)
- ✅ All databases are `Running` (especially PostgreSQL — other stages depend on it)
- ✅ cert-manager has issued certificates (check: `kubectl get certificates -A`)

**Troubleshooting LoadBalancer IPs:**

If services stay `<pending>` after 5 minutes:

```bash
# Check Cilium BGP status
kubectl -n cilium exec -it <cilium-pod> -- cilium bgp peers

# Check IPAM pool
kubectl -n kube-system get ippools.cilium.io
```

---

## Step 8: Deploy Stage 3 (Applications) (20-30 min)

Stage 3 deploys user-facing applications: Nextcloud, Jenkins, Keycloak, LLM stack, Home Assistant, Grafana, etc.

```bash
kubectl apply -f cluster/stages/stage-3/service.yaml
```

**What gets deployed:**
- Nextcloud + PhotoPrism
- Jenkins CI/CD
- Keycloak SSO
- Open-WebUI + Ollama (AI/LLM)
- Home Assistant
- Grafana dashboards
- Prometheus monitoring
- Puppet server + Foreman

**Monitor progress:**

```bash
kubectl get applications -A
kubectl get pods -A --sort-by=.metadata.creationTimestamp | tail -20
```

**Access your applications:**

Once all pods are `Running`, applications are accessible at:

- **ArgoCD** — `https://argo.yourdomain.com`
- **Grafana** — `https://grafana.yourdomain.com`
- **Nextcloud** — `https://nextcloud.yourdomain.com`
- **Jenkins** — `https://jenkins.yourdomain.com`
- **Keycloak** — `https://keycloak.yourdomain.com`
- **Home Assistant** — `https://ha.yourdomain.com`

(Replace `yourdomain.com` with your actual domain)

---

## Troubleshooting

### Pods stuck in `Pending`

```bash
# Check what's blocking
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - PVC waiting for storage — ensure NFS provisioner is running
# - Node affinity — pod requires specific node labels
# - Resource limits — cluster has insufficient CPU/memory
```

### Secrets not decrypting

```bash
# Verify GPG key is accessible
gpg --list-keys <YOUR_KEY_ID>

# Check SOPS config
cat .sops.yaml | grep pgp

# Try decrypting a test secret
sops -d cluster/infrastructure/argocd/secrets.yaml | head -5
```

### ArgoCD not syncing

```bash
# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller -f

# Check git credentials
kubectl get secret argocd-repository-credentials -n argocd -o yaml | grep url

# Resync manually
kubectl patch application <app-name> -n <ns> -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge
```

### LoadBalancer stuck in `<pending>`

```bash
# Check Cilium has IP pool
kubectl get ippools.cilium.io

# Check service configuration
kubectl get svc -n <namespace> -o yaml | grep -A 5 "spec:"

# Force resync of LoadBalancers
kubectl delete pod -n cilium -l k8s-app=cilium
```

---

## Next Steps

Once deployed:

1. **Configure DNS** — Point your domain to the nginx LoadBalancer IP
2. **Set up backups** — Configure Velero for etcd + persistent volumes
3. **Monitor** — Access Grafana dashboards at `https://grafana.yourdomain.com`
4. **Customize** — Add your applications to `cluster/infrastructure/apps/`

---

## Questions?

- **Setup failed?** — Check output of `./setup-validation.sh`
- **Pod stuck?** — Check `kubectl describe pod <pod>` and `kubectl logs <pod>`
- **Secrets broken?** — Verify GPG key with `gpg --list-keys`
- **Found a bug?** — Open a GitHub Issue at https://github.com/mateirim/homelab-infra/issues

---

**Ready?** Run `./setup.sh` and follow the prompts. Good luck! 🚀
