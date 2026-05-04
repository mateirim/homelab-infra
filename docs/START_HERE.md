# 🚀 You Just Cloned homelab-infra

Welcome! Here's what to do next (5 minutes).

## What Is This?

A production-ready Kubernetes cluster template: 28 namespaces, 30+ applications, GitOps-first, security-hardened. Designed for homelabs (5-6 node clusters), not toy projects.

## Two Paths

**Path 1: Want to Deploy It?**
→ Continue below (this is you)

**Path 2: Want to Understand the Architecture First?**
→ Read [../README.md](README.md) (15 min)

---

## Deploying? Check Prerequisites (2 min)

Do you have:
- [ ] 5+ nodes (1 control plane + 4+ workers)
- [ ] NFS server(s) for storage
- [ ] Domain name (e.g., example.com)
- [ ] DNS server IPs
- [ ] GPG key (or `gpg --full-generate-key`)
- [ ] GitHub PAT token
- [ ] DNS/certificate provider (e.g., Cloudflare API token)

**If NO:** Stop. Read [GETTING_STARTED.md](GETTING_STARTED.md) for full prerequisites.

**If YES:** Continue below.

---

## Deploy in 3 Steps

### 1. Personalize (5 min)

```bash
../setup.sh
```

You'll be prompted for:
- Domain name
- NFS server IPs
- DNS servers
- API tokens (GitHub, Cloudflare)

The script will:
- Fill in all `REPLACE_WITH_*` placeholders
- Generate random passwords
- Encrypt secrets with SOPS
- Configure ArgoCD to your fork

### 2. Validate (1 min)

```bash
../setup-validation.sh
```

This checks:
- All placeholders filled
- Secrets encrypted
- No hardcoded values

### 3. Deploy (30 min)

```bash
git add .
git commit -m "chore: personalize homelab-infra"
git push
```

Then follow [GETTING_STARTED.md](GETTING_STARTED.md) **Step 2 onwards** which walks you through:
- Node setup (kernel tuning, containerd, kubeadm)
- Control plane bootstrap
- Cilium CNI deployment
- ArgoCD syncing

---

## Next: Read Full Guides

In this order:

1. **[GETTING_STARTED.md](GETTING_STARTED.md)** — Step-by-step deployment guide
2. **[../cluster/README.md](cluster/README.md)** — Node setup and Kubernetes bootstrap

---

## Questions?

- **"What's inside?"** → [../README.md](README.md)
- **"What do I need?"** → [GETTING_STARTED.md](GETTING_STARTED.md) Prerequisites section
- **"How do I deploy?"** → [GETTING_STARTED.md](GETTING_STARTED.md)
- **"What if something breaks?"** → [GETTING_STARTED.md](GETTING_STARTED.md#troubleshooting)
- **"Found a bug?"** → [GitHub Issues](https://github.com/mateirim/homelab-infra/issues)

---

**Ready?** Run `../setup.sh` and proceed. Good luck! 🎯
