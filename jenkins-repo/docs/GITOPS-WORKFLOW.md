# GitOps Workflow with Jenkins and ArgoCD

## Complete Workflow Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         DEVELOPER                                 │
│                              │                                    │
│                              ▼                                    │
│                     Git Push to App Repo                          │
└──────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                         JENKINS CI                                │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │  Checkout  │→│   Build    │→│    Test    │→│   Build    │ │
│  │   Source   │  │    Code    │  │    Code    │  │   Docker   │ │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘ │
│         │                                              │          │
│         ▼                                              ▼          │
│  ┌────────────┐                              ┌────────────┐      │
│  │   Push to  │                              │   Update   │      │
│  │  Registry  │                              │  Manifests │      │
│  └────────────┘                              └────────────┘      │
│                                                     │             │
│                                                     ▼             │
│                                            ┌────────────┐         │
│                                            │  Commit &  │         │
│                                            │  Push to   │         │
│                                            │ GitOps Repo│         │
│                                            └────────────┘         │
└──────────────────────────────────────────────────────────────────┘
                                                     │
                                                     ▼
┌──────────────────────────────────────────────────────────────────┐
│                      GITOPS REPOSITORY                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  apps/myapp/overlays/                                       │ │
│  │  ├── dev/         - Auto-synced                             │ │
│  │  ├── staging/     - Auto-synced                             │ │
│  │  └── production/  - Manual approval required                │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                         ArgoCD                                    │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐ │
│  │   Detect   │→│   Compare  │→│    Sync    │→│   Monitor  │ │
│  │   Changes  │  │   State    │  │  Changes   │  │   Health   │ │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘ │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                      KUBERNETES CLUSTER                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  Namespace  │  │  Namespace  │  │  Namespace  │              │
│  │  myapp-dev  │  │myapp-staging│  │myapp-prod   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└──────────────────────────────────────────────────────────────────┘
```

## Step-by-Step Process

### 1. Development Phase
```bash
# Developer makes changes
git checkout -b feature/new-feature
# ... make changes ...
git commit -m "Add new feature"
git push origin feature/new-feature

# Create pull request
gh pr create --title "New feature" --body "Description"
```

### 2. CI Phase (Jenkins)
Jenkins automatically:
1. Detects the commit via webhook
2. Checks out the code
3. Runs tests
4. Builds Docker image with tag `git-commit-sha`
5. Pushes image to registry
6. Clones GitOps repository
7. Updates Kubernetes manifests with new image tag
8. Commits and pushes to GitOps repo

**Jenkins Pipeline:**
```groovy
// Build image
docker build -t myapp:abc123 .
docker push myapp:abc123

// Update GitOps repo
cd gitops-repo
kustomize edit set image myapp=myapp:abc123
git commit -m "Update myapp to abc123"
git push
```

### 3. CD Phase (ArgoCD)
ArgoCD automatically:
1. Detects changes in GitOps repo (polling every 3 minutes)
2. Compares desired state vs actual state
3. Syncs changes to Kubernetes cluster

**For Dev/Staging:**
- Auto-sync enabled
- Immediate deployment

**For Production:**
- Manual sync required
- Requires approval in ArgoCD UI or CLI

### 4. Deployment Verification
```bash
# Check ArgoCD sync status
argocd app get myapp-dev

# Check Kubernetes deployment
kubectl get pods -n myapp-dev
kubectl rollout status deployment/myapp -n myapp-dev

# Run smoke tests
curl https://myapp-dev.example.com/health
```

## Environment Promotion Strategy

### Strategy 1: Branch-based
```
main branch      → Production
staging branch   → Staging
develop branch   → Dev
```

### Strategy 2: Tag-based (Recommended)
```
v1.2.3          → Production (semver tags)
staging/v1.2.3  → Staging
dev/abc123      → Dev (commit SHA)
```

### Strategy 3: Directory-based (Using Kustomize)
```
overlays/dev/        → Dev cluster
overlays/staging/    → Staging cluster
overlays/production/ → Production cluster
```

## Promoting to Production

### Option A: Auto-promotion (Dev → Staging → Prod)
```bash
# Jenkins pipeline automatically promotes
# after successful tests in staging

# Update staging
jenkins deploy --env=staging --version=v1.2.3

# Wait for tests
# ... automated tests run ...

# Auto-promote to production if tests pass
jenkins deploy --env=production --version=v1.2.3
```

### Option B: Manual approval
```bash
# Create PR for production deployment
gh pr create \
  --repo gitops-repo \
  --title "Deploy v1.2.3 to production" \
  --body "Reviewed and approved"

# Team reviews PR
# On approval, merge triggers ArgoCD sync
```

### Option C: ArgoCD UI approval
```bash
# Jenkins updates manifest but doesn't trigger sync
# Admin manually syncs in ArgoCD UI
argocd app sync myapp-production
```

## Rollback Procedures

### Method 1: Git Revert
```bash
# Find the commit to revert
git log --oneline

# Revert the deployment commit
git revert abc123
git push

# ArgoCD automatically syncs the revert
```

### Method 2: ArgoCD History
```bash
# List deployment history
argocd app history myapp-production

# Rollback to previous version
argocd app rollback myapp-production 10
```

### Method 3: Manual manifest update
```bash
# Update manifest to previous version
cd gitops-repo/apps/myapp/overlays/production
kustomize edit set image myapp=myapp:v1.2.2
git commit -m "Rollback to v1.2.2"
git push
```

## Monitoring and Notifications

### ArgoCD Notifications
Configure in `argocd-notifications-cm`:
```yaml
triggers:
  - name: on-deployed
    condition: app.status.operationState.phase in ['Succeeded']
  - name: on-health-degraded
    condition: app.status.health.status == 'Degraded'

subscriptions:
  - recipients:
    - slack:jenkins-deployments
    triggers:
    - on-deployed
    - on-health-degraded
```

### Jenkins Notifications
Already configured in `gitops-pipeline.jenkinsfile`:
- Slack notifications on success/failure
- Email notifications to team
- Build status in Git commits

## Best Practices

### 1. Image Tags
✅ **DO**: Use immutable tags (commit SHA, build number)
```yaml
image: myapp:abc123def
```

❌ **DON'T**: Use mutable tags
```yaml
image: myapp:latest  # Bad!
```

### 2. Manifest Structure
✅ **DO**: Separate base and overlays
```
base/           # Common configuration
overlays/       # Environment-specific
  dev/
  staging/
  production/
```

### 3. Security
✅ **DO**:
- Use separate credentials for Jenkins and ArgoCD
- Require PR approvals for production
- Sign commits with GPG
- Scan images before deployment

### 4. Testing
✅ **DO**: Test at every stage
```
Unit Tests      → In Jenkins CI
Integration     → In Jenkins CI
Smoke Tests     → After deployment
E2E Tests       → In staging environment
```

## Troubleshooting

### Issue: ArgoCD not syncing
```bash
# Check sync status
argocd app get myapp-dev

# Force refresh
argocd app get myapp-dev --refresh

# Check for errors
kubectl logs -n argocd deployment/argocd-application-controller
```

### Issue: Deployment stuck
```bash
# Check pod status
kubectl get pods -n myapp-dev

# Check events
kubectl get events -n myapp-dev --sort-by='.lastTimestamp'

# Check rollout status
kubectl rollout status deployment/myapp -n myapp-dev
```

### Issue: Image pull errors
```bash
# Verify image exists
docker pull myapp:abc123

# Check image pull secrets
kubectl get secrets -n myapp-dev
kubectl describe secret regcred -n myapp-dev
```

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
