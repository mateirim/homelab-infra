# Contributing to homelab-infra

Thank you for your interest in contributing! This guide explains how to fork, modify, and submit pull requests for homelab-infra.

## Quick Summary

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Run `./setup.sh`** to personalize for your environment
4. **Make changes** (add features, fix bugs, improve docs)
5. **Test** with `./setup-validation.sh`
6. **Commit** with descriptive messages
7. **Push** to your fork
8. **Create a PR** with a clear description of changes

---

## Getting Started

### Prerequisites

Before you begin, ensure you have:

- Git installed (with SSH or HTTPS authentication configured)
- `sops` and `gpg` installed (for secret handling)
- Kubernetes knowledge (this is an intermediate-level project)
- A homelab environment to test against (or willingness to test locally with `kubectl --dry-run`)

### Fork and Clone

```bash
# 1. Fork on GitHub (click "Fork" button)
# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/homelab-infra.git
cd homelab-infra

# 3. Add upstream remote for syncing
git remote add upstream https://github.com/mateirim/homelab-infra.git
```

---

## Making Changes

### Understanding the Structure

The repository is organized as follows:

```
cluster/
├── stages/              # 3-stage ArgoCD deployment (stage-1, stage-2, stage-3)
├── infrastructure/      # Kubernetes manifests organized by component
│   ├── namespaces/     # Namespace definitions
│   ├── cni/            # Cilium CNI configuration
│   ├── argocd/         # ArgoCD configuration
│   ├── database/       # PostgreSQL, MongoDB, Redis
│   ├── llm/            # LLM stack (Open-WebUI, Ollama, etc.)
│   └── ...             # 25+ other components
├── config/             # kubeadm config, kernel settings
└── docs/               # Architecture docs, ADRs, runbooks

homelab-helm-charts/
├── charts/             # Custom Helm charts (foreman, etc.)
├── containers/         # Custom Dockerfiles (puppetserver, r10k, etc.)

jenkins-repo/          # Jenkins pipelines and shared libraries

puppet-control-repo/   # Puppet roles, profiles, Hiera data
```

### Placeholder Pattern: REPLACE_WITH_*

This repo uses a templating pattern where environment-specific values are replaced by `setup.sh`.

**Key placeholders:**
- `REPLACE_WITH_YOUR_DOMAIN` — Your cluster domain (e.g., `example.com`)
- `REPLACE_WITH_WINDOWS_NODE_IP` — Windows node IP for Prometheus scraping (optional)
- `REPLACE_WITH_*` — Any other user-specific value

**When adding new features:**
- If you introduce an environment-specific value, prefix it with `REPLACE_WITH_`
- `setup.sh` automatically finds and replaces these across all YAML/shell/config files
- Document the placeholder in `GETTING_STARTED.md` prerequisites if it's critical

### Adding a New Application

**Example: Adding a new app to Stage 3**

1. **Create the infrastructure directory:**
   ```bash
   mkdir -p cluster/infrastructure/my-app
   ```

2. **Create manifests** (Helm values, kustomization, or raw YAML):
   ```bash
   # Option A: Helm-based (recommended)
   cat > cluster/infrastructure/my-app/my-app-values.yaml << 'EOF'
   image:
     repository: my-app
     tag: "1.2.3"
   
   resources:
     requests:
       cpu: 100m
       memory: 128Mi
     limits:
       cpu: 500m
       memory: 512Mi
   EOF
   
   # Option B: Raw manifests
   cat > cluster/infrastructure/my-app/deployment.yaml << 'EOF'
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-app
     namespace: my-app
   spec:
     ...
   EOF
   ```

3. **Add to kustomization.yaml:**
   ```bash
   cat > cluster/infrastructure/my-app/kustomization.yaml << 'EOF'
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   namespace: my-app
   
   resources:
     - deployment.yaml
   EOF
   ```

4. **Create an ArgoCD Application** in the appropriate stage file:
   ```bash
   # For stage-3, edit cluster/stages/stage-3/service.yaml
   cat >> cluster/stages/stage-3/service.yaml << 'EOF'
   ---
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-app
     namespace: argocd
   spec:
     destination:
       namespace: default
       server: 'https://kubernetes.default.svc'
     source:
       path: infrastructure/my-app
       repoURL: 'https://github.com/YOUR_GITHUB_USERNAME/homelab-infra'
       targetRevision: main
     project: default
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   EOF
   ```

5. **If using a new namespace**, add it to `cluster/infrastructure/namespaces/service.yaml`:
   ```yaml
   ---
   apiVersion: v1
   kind: Namespace
   metadata:
     labels:
       environment: common
     annotations:
       argocd.argoproj.io/sync-options: Delete=false
     name: my-app
   ```

### Manifest Quality Standards

All manifests should follow these patterns (visible in existing manifests):

✅ **DO:**
- Include resource requests **and** limits (CPU/memory)
- Add liveness and readiness probes for long-running services
- Use RBAC (ServiceAccount, Role, RoleBinding) for least-privilege access
- Apply NetworkPolicies if accessing sensitive data
- Label all resources with `app`, `version`, `managed-by` labels
- Use specific image tags (not `latest`)
- Environment-specific values should be `REPLACE_WITH_*` placeholders

❌ **DON'T:**
- Use `imagePullPolicy: Always` unless necessary
- Hardcode IPs or domain names (use DNS or ConfigMap)
- Store secrets in ConfigMaps (use Kubernetes Secrets or SOPS)
- Assume unlimited resources
- Deploy without health checks

**Example manifest:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  namespace: apps
  labels:
    app: example-app
    version: "1.0"
    managed-by: Helm
spec:
  replicas: 2
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      serviceAccountName: example-app
      containers:
      - name: app
        image: example/app:1.2.3
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ENV
          value: production
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
```

---

## Testing Your Changes

### 1. Validate YAML Syntax

```bash
# Check that all YAML is valid
find cluster/ -name "*.yaml" -o -name "*.yml" | xargs -I {} sh -c 'echo "Validating {}..." && kubectl apply -f {} --dry-run=client'
```

### 2. Run Validation Script

```bash
# Check that setup works and validates correctly
./setup.sh  # Answer prompts to personalize for your environment
./setup-validation.sh
```

If both pass:
- ✅ All `REPLACE_WITH_*` placeholders are filled
- ✅ SOPS encryption works
- ✅ ArgoCD Applications are correctly formatted
- ✅ No hardcoded environment-specific values remain

### 3. Test in Your Homelab (Optional but Recommended)

```bash
# Deploy the changes to your cluster
git push origin your-branch-name
# Then in your cluster, manually sync ArgoCD or wait for auto-sync
```

---

## Commit Messages

Write clear, descriptive commit messages that explain **why** the change was made, not just what changed.

**Format:**
```
<type>: <subject>

<body (optional)>
```

**Types:**
- `feat:` — New feature (e.g., "feat: add Velero backup manifests")
- `fix:` — Bug fix (e.g., "fix: correct Cilium BGP ASN for rpi nodes")
- `docs:` — Documentation (e.g., "docs: add SOPS setup guide")
- `refactor:` — Code refactoring (e.g., "refactor: consolidate duplicate Helm values")
- `chore:` — Maintenance (e.g., "chore: update prometheus-stack chart version")

**Examples:**
```
feat: add LiteLLM proxy for multi-provider LLM access

- Supports OpenAI, Ollama, and local LLM backends
- Includes rate limiting and cost tracking
- ARgCD Application added to stage-3

fix: allow database pods to resolve DNS via CoreDNS

Previously, the database-deny-all NetworkPolicy blocked DNS egress
to kube-system. Now allows TCP/UDP 53 to kube-system namespace.

docs: document SOPS setup for contributors

Added .sops.yaml.example and updated GETTING_STARTED.md with
step-by-step SOPS configuration instructions.
```

---

## Secrets and SOPS

**Important:** Never commit unencrypted secrets to version control.

### Encrypting New Secrets

If you add a new secret file:

1. **Create the secret template:**
   ```yaml
   # cluster/infrastructure/my-app/secret.yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: my-app-secret
     namespace: my-app
   stringData:
     api_key: REPLACE_WITH_API_KEY
     password: REPLACE_WITH_PASSWORD
   ```

2. **Run `sops` to encrypt it:**
   ```bash
   sops --encrypt --in-place cluster/infrastructure/my-app/secret.yaml
   ```

   This requires `.sops.yaml` to be configured (run `./setup.sh` first).

3. **Commit the encrypted file:**
   ```bash
   git add cluster/infrastructure/my-app/secret.yaml
   ```

For more details, see [cluster/docs/SECRETS-ROTATION.md](cluster/docs/SECRETS-ROTATION.md).

---

## Submitting a Pull Request

### Before Opening a PR

1. **Sync with upstream:**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run validation:**
   ```bash
   ./setup-validation.sh
   ```

3. **Check your changes:**
   ```bash
   git diff upstream/main
   ```

### Create the PR

1. **Push to your fork:**
   ```bash
   git push origin your-branch-name
   ```

2. **Open a PR on GitHub:**
   - Use the PR template (GitHub will provide one)
   - Link related issues (e.g., "Closes #42")
   - Describe what changed and why

3. **PR Title and Description:**

   **Title:** Keep it short and clear
   ```
   feat: add backup strategy with Velero
   ```

   **Description:** Use the template below
   ```markdown
   ## Summary
   - Adds Velero manifests for etcd and persistent volume backups
   - Includes hourly backup schedule and 30-day retention
   - Documented in cluster/docs/BACKUP-STRATEGY.md

   ## Testing
   - Validated YAML with `kubectl apply --dry-run`
   - Ran ./setup-validation.sh successfully
   - Tested restore procedure in test cluster

   ## Related Issues
   Closes #15
   ```

### PR Review Process

- Your PR will be reviewed for:
  - Adherence to manifest quality standards (above)
  - Clear documentation
  - No unencrypted secrets
  - Compatibility with the 3-stage deployment model
- Address feedback by pushing additional commits (don't force-push)
- Once approved, your PR will be merged to `main`

---

## Code Style and Conventions

### YAML / Kubernetes Manifests

- Use **2-space indentation** (not tabs)
- Organize fields in this order:
  ```yaml
  apiVersion: ...
  kind: ...
  metadata:
    name: ...
    namespace: ...
    labels: ...
    annotations: ...
  spec: ...
  ```
- Use descriptive names: `my-app-deployment` not `app1`
- Always include `namespace` in metadata

### Helm Values

- Organize by component (match the chart structure)
- Use comments for non-obvious settings
- Document any `REPLACE_WITH_*` placeholders
- Example:
  ```yaml
  # PostgreSQL configuration
  postgresql:
    enabled: true
    auth:
      username: postgres
      password: REPLACE_WITH_DB_PASSWORD
    primary:
      resources:
        requests:
          cpu: 250m
          memory: 512Mi
  ```

### Documentation

- Use clear, active voice
- Link to related docs (e.g., [GETTING_STARTED.md](GETTING_STARTED.md))
- Include examples and code blocks
- Keep line length ~80 characters for readability

---

## Questions or Issues?

- **Ask a question:** [Open a GitHub Discussion](https://github.com/mateirim/homelab-infra/discussions)
- **Report a bug:** [Open a GitHub Issue](https://github.com/mateirim/homelab-infra/issues)
- **Security issue:** See [SECURITY.md](SECURITY.md) (do NOT open a public issue)

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

Happy contributing! 🚀
