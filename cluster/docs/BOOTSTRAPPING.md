# Bootstrapping homelab-infra: From Git to GitOps

This guide explains how `setup.sh` personalizes the repository and how ArgoCD syncs your cluster with the GitOps workflow.

## The Big Picture

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Fork on GitHub                                           │
│    ↓                                                         │
│ 2. Clone your fork → ./setup.sh (personalize)              │
│    ↓                                                         │
│ 3. git push → ArgoCD detects changes                        │
│    ↓                                                         │
│ 4. ArgoCD syncs 3 stages (stage-1 → stage-2 → stage-3)    │
│    ↓                                                         │
│ 5. Kubernetes cluster runs 30+ applications                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Setup (30 minutes)

### Step 1A: Prerequisites

Before running `setup.sh`, verify you have:

```bash
# Required tools
which sops gpg openssl kubectl git

# GPG key (generate one if you don't have it)
gpg --list-secret-keys --keyid-format LONG
# Output example:
# sec   rsa3072/F81E8088C755BB28 2026-05-03
#       F81E8088C755BB28 is your KEY_ID

# If no key, generate:
gpg --full-generate-key
# Choose: RSA 3072, no expiry, real name, email
```

### Step 1B: Personalization with setup.sh

```bash
./setup.sh
```

**What setup.sh does:**

1. **Checks prerequisites** — Verifies sops, gpg, openssl are installed

2. **Prompts for your environment** — Asks for:
   - `DOMAIN` — Your cluster domain (e.g., `example.com`)
   - `CONTROL_PLANE_HOSTNAME` — Control plane node name
   - `CONTROL_PLANE_IP` — Control plane node IP
   - `WORKER_NODES` — List of worker node names/IPs
   - `NFS_SERVER_IP` — NFS server IP for persistent storage
   - `DNS_SERVERS` — Your internal DNS servers (e.g., Pi-hole)
   - `GITHUB_TOKEN` — GitHub Personal Access Token for ArgoCD
   - `GPG_KEY_ID` — Your GPG key fingerprint (e.g., `F81E8088C755BB28`)

3. **Replaces placeholders** — Finds all `REPLACE_WITH_*` strings and substitutes:
   - `REPLACE_WITH_YOUR_DOMAIN` → `example.com`
   - `REPLACE_WITH_GITHUB_USERNAME` → `mateirim`
   - `REPLACE_WITH_GPG_KEY_ID` → `F81E8088C755BB28`
   - `REPLACE_WITH_WINDOWS_NODE_IP` → `192.168.1.50`
   - ... and 20+ others

4. **Generates secrets** — Creates random passwords for:
   - Database users and passwords
   - API keys for external services
   - ArgoCD admin password
   - Keycloak admin password
   - Jenkins secrets

5. **Encrypts secrets** — Runs `sops --encrypt` on all `*secret*.yaml` files
   - Uses your GPG key to encrypt them
   - Makes secrets safe to commit to git
   - Only you (with your private key) can decrypt them

6. **Configures ArgoCD** — Updates all Application resources:
   - Changes `YOUR_GITHUB_USERNAME` → your actual GitHub username
   - ArgoCD will watch your forked repository
   - When you push changes, ArgoCD automatically syncs

7. **Creates .sops.yaml** — Generates the SOPS config:
   - Tells SOPS which files to encrypt
   - Which GPG key to use
   - Example output (after setup.sh):
     ```yaml
     creation_rules:
       - path_regex: .*secret.*\.ya?ml$
         encrypted: true
         pgp: F81E8088C755BB28
       - encrypted: false
     ```

8. **Validates everything** — Warns about any uncaught placeholders

### Step 1C: Validation

```bash
./setup-validation.sh
```

This script verifies:
- ✅ No `REPLACE_WITH_*` placeholders remain
- ✅ All secrets are SOPS-encrypted
- ✅ `.sops.yaml` exists and is valid
- ✅ Your GPG key is accessible
- ✅ Encryption/decryption works
- ✅ ~30 ArgoCD Applications found
- ✅ Git is clean (no uncommitted changes)

If validation passes, you're ready to deploy.

---

## Phase 2: Commit & Push (5 minutes)

```bash
# Stage all personalized files
git add .

# Commit with a descriptive message
git commit -m "chore: personalize homelab-infra for my environment"

# Push to your fork
git push origin main
```

**What you're pushing:**
- ✅ Personalized YAML manifests (with your domain, IPs, etc.)
- ✅ Encrypted secrets (safe to commit)
- ✅ `.sops.yaml` (encrypted config, typically gitignored but you can commit it)
- ✅ Setup history (git log shows personalization was done)

---

## Phase 3: Bootstrap Kubernetes (30-60 minutes)

At this point, you have:
- ✅ A Git repository (your fork) with all configuration
- ✅ An empty Kubernetes cluster (bootstrapped manually with kubeadm)
- ❌ No applications running yet

### Step 3A: Install ArgoCD

ArgoCD is the bridge between Git and Kubernetes. It watches your Git repository and automatically syncs any changes to the cluster.

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD (use the Helm chart from the repo, or manually)
# Option 1: Using Helm directly
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values cluster/infrastructure/argocd/argocd-values.yaml

# Wait for ArgoCD server to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

# Get the ArgoCD admin password (default username is "admin")
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 3B: Configure ArgoCD for Your Fork

```bash
# Port-forward to ArgoCD server (in another terminal)
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Log in (in browser or CLI)
# Browser: https://localhost:8080
# CLI: argocd login localhost:8080
```

In ArgoCD UI:
1. Go to **Settings → Repositories**
2. Click **Connect Repo**
3. Choose **VIA HTTPS** or **VIA SSH**
4. Enter your fork URL: `https://github.com/YOUR_USERNAME/homelab-infra`
5. If HTTPS, provide your GitHub Personal Access Token
6. Click **Connect**

### Step 3C: Deploy Stage 1

Stage 1 sets up the cluster foundation: namespaces, CNI, NFS, ArgoCD itself, and Prometheus CRDs.

**Option A: Manual ArgoCD Application creation**

```bash
# Create the stage-1 Applications from git
kubectl apply -f cluster/stages/stage-1/service.yaml
```

**Option B: Using ArgoCD UI**

1. Click **New App** in ArgoCD
2. Set:
   - **Application Name:** `stage-1`
   - **Project:** `default`
   - **Repository:** Your forked repo URL
   - **Path:** `cluster/stages/stage-1`
   - **Destination:** `https://kubernetes.default.svc`
   - **Namespace:** `default`
3. Click **Create**
4. Click **Sync** to start deployment

**What stage-1 deploys:**
- ✅ 29 namespaces (organized by component)
- ✅ Cilium CNI (eBPF networking, BGP, native routing)
- ✅ NFS provisioner (for persistent volumes)
- ✅ Prometheus CRDs (required before prometheus-stack)
- ✅ ArgoCD server, repo server, controller

**Monitor stage-1:**
```bash
# Watch application sync
kubectl get applications -n argocd -w

# Check pod status
kubectl get pods -A | grep -E "^(argocd|cilium|prometheus)"

# Check if Cilium is ready
kubectl -n kube-system wait --for=condition=ready pod \
  -l k8s-app=cilium --timeout=300s
```

**⏸️ WAIT HERE** — Do not proceed to stage-2 until stage-1 is fully synced (all Applications Healthy=true, Synced=true).

### Step 3D: Deploy Stage 2

Stage 2 sets up infrastructure: databases, networking, monitoring, CI/CD.

```bash
# Apply stage-2 Applications
kubectl apply -f cluster/stages/stage-2/service.yaml

# Or in ArgoCD UI: Create new app, set path to `cluster/stages/stage-2`
```

**What stage-2 deploys:**
- ✅ PostgreSQL, MongoDB, Redis (databases)
- ✅ nginx ingress controller
- ✅ cert-manager + Let's Encrypt
- ✅ Prometheus + AlertManager (monitoring)
- ✅ Docker registry
- ✅ Wireguard VPN
- ✅ KEDA autoscaler
- ✅ GitHub Actions runners
- ✅ Pi-hole DNS
- ✅ NVIDIA GPU support (optional)

**Monitor stage-2:**
```bash
# Wait for all stage-2 applications
kubectl get applications -n argocd -w | grep -E "stage-2|database|postgres"

# Check database readiness
kubectl -n database wait --for=condition=ready pod \
  -l app=postgres --timeout=300s
```

**⏸️ WAIT HERE** — Ensure stage-2 is fully healthy before stage-3.

### Step 3E: Deploy Stage 3

Stage 3 deploys user-facing applications: Grafana, Jenkins, Keycloak, LLM stack, Home Assistant, etc.

```bash
# Apply stage-3 Applications
kubectl apply -f cluster/stages/stage-3/service.yaml
```

**What stage-3 deploys:**
- ✅ Grafana (dashboards)
- ✅ Loki + Mimir (logging + metrics storage)
- ✅ Jenkins (CI/CD)
- ✅ Keycloak (SSO)
- ✅ Home Assistant + Music Assistant + Ollama
- ✅ Nextcloud + PhotoPrism (file storage)
- ✅ Open-WebUI + wyoming-piper + Whisper (LLM apps)
- ✅ Puppet server + Foreman (configuration management)
- ✅ Tailscale (mesh VPN)
- ✅ Custom user apps (placeholder)

**Monitor stage-3:**
```bash
# Watch all applications sync
kubectl get applications -n argocd -w

# Get the list of deployed apps
kubectl get applications -n argocd
```

---

## Phase 4: Verify & Access

Once all three stages are synced, you have a fully operational cluster.

### Check All Applications

```bash
# All apps should be Healthy=true, Synced=true
kubectl get applications -n argocd

# Example output:
# NAME                SYNC STATUS   HEALTH STATUS
# argocd              Synced        Healthy
# cni                 Synced        Healthy
# database            Synced        Healthy
# foreman             Synced        Healthy
# grafana             Synced        Healthy
# homeassistant       Synced        Healthy
# ... (30 total)
```

### Access Applications

All applications are exposed via ingress. Update your DNS or local `/etc/hosts` to point to your ingress IP:

```bash
# Find the ingress LoadBalancer IP
kubectl get svc -A | grep -i ingress

# Example:
# proxy             nginx-ingress-controller   LoadBalancer   10.172.2.100   192.168.1.100

# Add to /etc/hosts (or configure DNS):
# 192.168.1.100 argo.example.com grafana.example.com jenkins.example.com ...
```

Then visit:
- **ArgoCD:** `https://argo.example.com`
- **Grafana:** `https://grafana.example.com`
- **Jenkins:** `https://jenkins.example.com`
- **Keycloak:** `https://keycloak.example.com`
- **Home Assistant:** `https://homeassistant.example.com`
- ... and 25+ others

---

## Phase 5: Ongoing Operations

### Making Changes

The GitOps workflow:

1. **Make a change** (e.g., update a Helm chart version, add a new application)
   ```bash
   # Edit a file
   vim cluster/infrastructure/grafana/grafana-values.yaml
   
   # Commit
   git add .
   git commit -m "chore: upgrade Grafana to 10.4.0"
   ```

2. **Push to Git**
   ```bash
   git push origin main
   ```

3. **ArgoCD detects the change** (within 3 minutes by default)
   - ArgoCD polls your Git repository for changes
   - Compares Git state with cluster state
   - Automatically syncs if `syncPolicy.automated` is enabled

4. **Cluster updates automatically**
   ```bash
   # Watch the update in real-time
   kubectl get applications -n argocd -w
   ```

### Rotating Secrets

If you need to rotate a secret (e.g., database password):

```bash
# 1. Edit the secret file
vim cluster/infrastructure/database/secret.yaml

# 2. Encrypt it with SOPS
sops --encrypt --in-place cluster/infrastructure/database/secret.yaml

# 3. Commit and push
git add .
git commit -m "chore: rotate database password"
git push

# 4. ArgoCD automatically syncs the new secret
```

See [cluster/docs/SECRETS-ROTATION.md](SECRETS-ROTATION.md) for detailed procedures.

---

## Troubleshooting

### ArgoCD Shows "Unknown" Status

**Cause:** ArgoCD cannot connect to your Git repository.

**Solution:**
1. Check ArgoCD settings: **Settings → Repositories**
2. Verify GitHub token is valid and has `repo` scope
3. Verify repository URL is correct (no typos)
4. Check ArgoCD repo server logs:
   ```bash
   kubectl logs -n argocd deploy/argocd-repo-server -f
   ```

### Applications Stuck in "Progressing"

**Cause:** Pods are not becoming ready (waiting for image pull, resource constraints, etc.).

**Solution:**
```bash
# Check pod status
kubectl get pods -n <app-namespace>

# Describe stuck pod
kubectl describe pod <pod-name> -n <app-namespace>

# Check logs
kubectl logs <pod-name> -n <app-namespace>

# Common issues:
# - ImagePullBackOff → Check image name, registry credentials
# - Pending → Check resource requests vs node capacity
# - CrashLoopBackOff → Check application logs
```

### Secrets Fail to Decrypt

**Cause:** Your GPG key is not accessible, or `.sops.yaml` is misconfigured.

**Solution:**
```bash
# Verify GPG key is in local keyring
gpg --list-secret-keys --keyid-format LONG

# Test SOPS encryption/decryption
sops --decrypt cluster/infrastructure/database/secret.yaml

# If decryption fails, check .sops.yaml
cat .sops.yaml | grep pgp

# Ensure the PGP key ID matches your GPG key
```

---

## Next Steps

- Read [docs/GETTING_STARTED.md](../docs/GETTING_STARTED.md) for detailed step-by-step deployment
- Read [docs/HARDWARE.md](../docs/HARDWARE.md) for node sizing recommendations
- Check [README.md](../README.md) for architecture overview
- See [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md) if you want to contribute changes back

---

## Summary

```
setup.sh                  → Personalize for your environment
setup-validation.sh       → Verify configuration
git push                  → Push to your fork
ArgoCD stage-1            → Foundation (CNI, namespaces, storage)
ArgoCD stage-2            → Infrastructure (databases, monitoring)
ArgoCD stage-3            → Applications (user-facing services)
GitOps workflow           → Automatic syncing for all future changes
```

You now have a fully GitOps-managed Kubernetes homelab! 🎉
