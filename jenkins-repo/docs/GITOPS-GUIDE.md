# GitOps Integration Guide

This guide explains how to integrate Jenkins pipelines with GitOps workflows using ArgoCD, Flux, or similar tools.

## What is GitOps?

GitOps is a way of implementing Continuous Deployment where:
- Git is the single source of truth for declarative infrastructure and applications
- Changes are made through pull requests
- Automated processes sync the actual state with the desired state in Git
- Rollback is as simple as reverting a Git commit

## Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Jenkins   │─────▶│  Git Repo    │◀─────│   ArgoCD    │
│  (CI/Build) │      │ (GitOps Repo)│      │ (CD/Sync)   │
└─────────────┘      └──────────────┘      └─────────────┘
                            │                      │
                            │                      ▼
                            │              ┌─────────────┐
                            └─────────────▶│ Kubernetes  │
                                          └─────────────┘
```

## Repository Structure

We recommend a **separate GitOps repository** structure:

### Option 1: Mono-repo (All in one)
```
my-app/
├── src/                    # Application source code
├── .jenkins/              # Jenkins pipelines
├── manifests/             # Kubernetes manifests
│   ├── base/             # Base configurations
│   └── overlays/         # Environment-specific overlays
│       ├── dev/
│       ├── staging/
│       └── production/
└── argocd/               # ArgoCD applications
```

### Option 2: Separate repos (Recommended)
```
app-repo/                  # Application source code
├── src/
└── Jenkinsfile

gitops-repo/              # GitOps configuration
├── apps/
│   └── myapp/
│       ├── base/
│       └── overlays/
│           ├── dev/
│           ├── staging/
│           └── production/
└── argocd-apps/
```

## Jenkins + GitOps Workflow

### Step 1: Build & Test (Jenkins)
1. Jenkins builds the application
2. Runs tests
3. Creates Docker image
4. Pushes image to registry with tag (e.g., `v1.2.3` or commit SHA)

### Step 2: Update GitOps Repo (Jenkins)
1. Jenkins clones the GitOps repository
2. Updates Kubernetes manifests with new image tag
3. Commits and pushes changes to GitOps repo
4. Creates a pull request (optional, for production)

### Step 3: Sync to Cluster (ArgoCD/Flux)
1. ArgoCD detects changes in GitOps repo
2. Automatically syncs to Kubernetes cluster
3. Application is deployed

## Tools Comparison

| Tool | Type | Pros | Cons |
|------|------|------|------|
| **ArgoCD** | Pull-based | UI, sync waves, rollback | Requires running in cluster |
| **Flux** | Pull-based | Lightweight, GitOps toolkit | Less user-friendly UI |
| **Jenkins X** | Push-based | Full CI/CD platform | Heavy, opinionated |
| **Tekton** | Kubernetes-native | Cloud-native, flexible | Requires more setup |

## Implementation Options

### 1. ArgoCD (Recommended)
- Pull-based GitOps
- Jenkins updates manifests, ArgoCD syncs
- Best for Kubernetes deployments

### 2. Flux CD
- Pull-based GitOps
- Automated image updates
- GitOps toolkit approach

### 3. Jenkins with kubectl (Push-based)
- Jenkins applies manifests directly
- Not true GitOps, but simpler
- Good for getting started

## Security Best Practices

1. **Separate Credentials**: Jenkins builds, ArgoCD deploys
2. **Pull Requests**: Require PR approval for production
3. **RBAC**: Limit Jenkins access to GitOps repo updates only
4. **Image Scanning**: Scan images before updating manifests
5. **Signed Commits**: Use GPG signing for manifest updates

## Getting Started

See the examples in:
- `gitops/` - GitOps repository structure
- `gitops-pipeline.jenkinsfile` - Jenkins pipeline for GitOps
- `argocd/` - ArgoCD application definitions
- `kustomize/` - Kustomize configurations

## Useful Commands

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Create application
kubectl apply -f argocd-apps/myapp.yaml

# Sync application
argocd app sync myapp

# Check sync status
argocd app get myapp
```
