# Homelab Helm Charts

Custom Helm charts and container images for the homelab-infra cluster.

## Contents

- **charts/** — Custom Helm charts maintained in this repo
- **containers/** — Dockerfiles for custom container images

## Custom Charts

### Foreman Chart
**Location:** [charts/foreman/](charts/foreman/)

Helm chart for Foreman (Puppet reporting + analytics). Based on an existing chart and customized for this homelab deployment.

See [cluster/docs/HELM-CHARTS.md](../cluster/docs/HELM-CHARTS.md#customlocal-charts) for more details on custom charts.

## External Charts

For a complete list of all external Helm charts (with repository URLs), see:

👉 **[cluster/docs/HELM-CHARTS.md](../cluster/docs/HELM-CHARTS.md)**

This document lists:
- All external chart repositories and their URLs
- Chart versions used in the cluster
- Instructions for adding new charts

## Container Images

Custom Docker images are built from `containers/` and pushed to your registry. See individual Dockerfile directories for build instructions.

## Adding New Charts

### Custom Chart

1. Create directory: `charts/<chart-name>/`
2. Follow standard Helm chart structure:
   ```
   charts/<chart-name>/
   ├── Chart.yaml
   ├── values.yaml
   └── templates/
   ```
3. Reference in appropriate namespace's `service.yaml`:
   ```yaml
   - chart: <chart-name>
     targetRevision: '<version>'
     repoURL: https://github.com/YOUR_GITHUB_USERNAME/homelab-infra
     helm:
       releaseName: <release-name>
       valueFiles:
         - $myRepo/infrastructure/<namespace>/<chart-name>-values.yaml
   ```
4. Commit and push — ArgoCD will auto-sync

### External Chart

See [cluster/docs/HELM-CHARTS.md#adding-new-charts](../cluster/docs/HELM-CHARTS.md#adding-new-charts) for instructions on adding external Helm charts.

## Building Container Images

Each directory in `containers/` contains a Dockerfile. To build:

```bash
docker build -t registry.yourdomain.com/<image>:<tag> -f containers/<image>/Dockerfile .
docker push registry.yourdomain.com/<image>:<tag>
```

For multi-architecture builds (amd64 + arm64):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t registry.yourdomain.com/<image>:<tag> -f containers/<image>/Dockerfile . --push
```

---

**For more details on chart management, see [cluster/docs/HELM-CHARTS.md](../cluster/docs/HELM-CHARTS.md)**
