# Helm Charts Reference

This document lists all **external** Helm charts deployed in the homelab-infra cluster with their repository URLs, versions, and source projects.

**License & Attribution:** See [LICENSES.md](../../LICENSES.md) for full license information and attribution for all third-party projects.

For **custom/local** charts, see [homelab-helm-charts/charts/](../../homelab-helm-charts/charts/).

## External Chart Repositories

### Core Infrastructure

- **cilium** (^1.15.0)
  - Helm Repo: https://helm.cilium.io/
  - Source: [Cilium](https://github.com/cilium/cilium) (Apache 2.0)

- **ingress-nginx** (^4.7.1)
  - Helm Repo: https://kubernetes.github.io/ingress-nginx
  - Source: [NGINX Ingress](https://github.com/kubernetes/ingress-nginx) (Apache 2.0)

### Databases & Storage

- **redis-ha** (^14.3.3)
  - Helm Repo: https://charts.bitnami.com/bitnami
  - Source: [Bitnami Charts](https://github.com/bitnami/charts) (Apache 2.0)

### Security & TLS

- **cert-manager** (^v1.13+)
  - Helm Repo: https://charts.jetstack.io
  - Source: [cert-manager](https://github.com/cert-manager/cert-manager) (Apache 2.0)

### Monitoring & Observability

- **prometheus** (^25+)
  - Helm Repo: https://prometheus-community.github.io/helm-charts
  - Source: [Prometheus Community](https://github.com/prometheus-community/helm-charts) (Apache 2.0)

- **grafana** (^7.0+)
  - Helm Repo: https://grafana.github.io/helm-charts
  - Source: [Grafana](https://github.com/grafana/helm-charts) (AGPL 3.0)
  - ⚠️ Note: AGPL 3.0 - See [LICENSES.md](../../LICENSES.md) for compliance info

- **loki** (^6.0+)
  - Helm Repo: https://grafana.github.io/helm-charts
  - Source: [Loki](https://github.com/grafana/loki) (AGPL 3.0)
  - ⚠️ Note: AGPL 3.0 - See [LICENSES.md](../../LICENSES.md) for compliance info

- **mimir** (^5.0+)
  - Helm Repo: https://grafana.github.io/helm-charts
  - Source: [Mimir](https://github.com/grafana/mimir) (AGPL 3.0)
  - ⚠️ Note: AGPL 3.0 - See [LICENSES.md](../../LICENSES.md) for compliance info

- **alertmanager** (^1.0+)
  - Helm Repo: https://prometheus-community.github.io/helm-charts
  - Source: [Prometheus Community](https://github.com/prometheus-community/helm-charts) (Apache 2.0)

### AI/LLM Stack

- **open-webui** (^3.1.9)
  - Helm Repo: https://helm.openwebui.com/
  - Source: [Open WebUI](https://github.com/open-webui/open-webui) (MIT)

- **ollama** (^1.36)
  - Helm Repo: https://helm.otwld.com/
  - Source: [Ollama](https://github.com/ollama/ollama) (MIT)

- **wyoming-piper** (^0.1.3)
  - Helm Repo: https://gitlab.com/api/v4/projects/62293226/packages/helm/stable
  - Source: [Piper](https://github.com/rhasspy/piper) (MIT)
  - ⚠️ Note: GitLab project 62293226 may be unavailable. If deployment fails, check [School-Guy/HelmCharts](https://github.com/School-Guy/HelmCharts) for alternatives or use the Whisper chart instead.

- **whisper** (^1.0.0)
  - Helm Repo: https://andrenarchy.github.io/helm-charts/
  - Source: [OpenAI Whisper](https://github.com/openai/whisper) (MIT)

- **searxng** (^1.0.7)
  - Helm Repo: https://charts.kubito.dev
  - Source: [SearXNG](https://github.com/searxng/searxng) (AGPL 3.0)
  - ⚠️ Note: AGPL 3.0 - See [LICENSES.md](../../LICENSES.md) for compliance info

- **n8n** (^2.0.1)
  - Helm Repo: oci://8gears.container-registry.com/library/n8n
  - Source: [n8n](https://github.com/n8n-io/n8n) (Elastic License 2.0)
  - ⚠️ Note: Elastic License 2.0 - See [LICENSES.md](../../LICENSES.md) for usage terms

- **litellm-helm** (^0.1.2)
  - Helm Repo: oci://docker.litellm.ai/berriai/litellm-helm
  - Source: [LiteLLM](https://github.com/BerriAI/litellm) (MIT)

- **openclaw** (^1.3.0)
  - Helm Repo: https://serhanekicii.github.io/openclaw-helm
  - Source: [OpenClaw](https://github.com/serhanekicii/openclaw) (MIT)

### Home Automation

- **home-assistant** (^1.34.0)
  - Helm Repo: https://charts.pree.dev
  - Source: [Home Assistant](https://github.com/home-assistant/core) (Apache 2.0)

- **music-assistant-server** (^0.1.9)
  - Helm Repo: https://lmatfy.github.io/charts
  - Source: [Music Assistant](https://github.com/music-assistant/music-assistant) (MIT)

### Identity & Access

- **keycloak** (^21.0+)
  - Helm Repo: https://codecentric.github.io/helm-charts
  - Source: [Keycloak](https://github.com/keycloak/keycloak) (Apache 2.0)

### VPN & Networking

- **tailscale** (^1.0+)
  - Helm Repo: https://pkgs.tailscale.com/tailscale-helm/
  - Source: [Tailscale](https://github.com/tailscale/tailscale) (BSD)

### CI/CD & Automation

- **jenkins** (^4.0+)
  - Helm Repo: https://charts.jenkins.io
  - Source: [Jenkins](https://github.com/jenkinsci/jenkins) (MIT)

- **argocd** (^6.0+)
  - Helm Repo: https://argoproj.github.io/argo-helm
  - Source: [ArgoCD](https://github.com/argoproj/argo-cd) (Apache 2.0)

### Autoscaling

- **keda** (^2.13+)
  - Helm Repo: https://kedacore.github.io/charts
  - Source: [KEDA](https://github.com/kedacore/keda) (Apache 2.0)

### GPU Support (Optional)

- **nvidia-device-plugin** (^0.14+)
  - Helm Repo: https://nvidia.github.io/k8s-device-plugin
  - Source: [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin) (Apache 2.0)

---

## Custom/Local Charts

Custom charts are maintained in [`homelab-helm-charts/charts/`](../../homelab-helm-charts/charts/). These are built and deployed from this repository:

- **foreman** — Puppet reporting + analytics
  - Location: [homelab-helm-charts/charts/foreman/](../../homelab-helm-charts/charts/foreman/)
  - Based on [Foreman](https://github.com/theforeman/foreman) (GPL 3.0)
  - Docker image: [lu1as/docker-foreman](https://github.com/lu1as/docker-foreman)
  - License: GPL 3.0 (See [LICENSES.md](../../LICENSES.md) for compliance details)

---

## Installation Reference

Most charts are installed via **ArgoCD Applications** in the `cluster/infrastructure/` directory. Each namespace (e.g., `llm/`, `homeassistant/`, `database/`) contains a `service.yaml` file that defines the Helm sources and chart versions.

### Example: LLM Stack
See [cluster/infrastructure/llm/service.yaml](../infrastructure/llm/service.yaml) for the complete LLM application definition.

### Example: Home Assistant
See [cluster/infrastructure/homeassistant/service.yaml](../infrastructure/homeassistant/service.yaml) for the Home Assistant application definition.

---

## Adding New Charts

To add a new **external** chart:

1. **Find the chart repository**: `helm search repo <chart-name>`
2. **Check the license** in the chart's source project
3. **Add to the appropriate namespace's `service.yaml`**:
   ```yaml
   - chart: <chart-name>
     targetRevision: '<version>'
     repoURL: https://example.com/charts
     helm:
       releaseName: <release-name>
       valueFiles:
         - $myRepo/infrastructure/<namespace>/<chart-name>-values.yaml
   ```
4. **Update [LICENSES.md](../../LICENSES.md)** with the source project, license, and GitHub link
5. **Update this file** with the new chart information
6. **Commit and push**: ArgoCD will auto-sync

To create a **custom** chart:

1. Create directory: `homelab-helm-charts/charts/<chart-name>/`
2. Follow standard Helm chart structure (`Chart.yaml`, `values.yaml`, `templates/`)
3. Include `LICENSE` file in the chart directory
4. Reference it in the appropriate namespace's `service.yaml` with `repoURL: https://github.com/YOUR_GITHUB_USERNAME/homelab-infra`
5. Update [LICENSES.md](../../LICENSES.md) with the chart details
6. See [foreman chart](../../homelab-helm-charts/charts/foreman/) for an example

---

## License Compliance

- **AGPL 3.0 Components**: Grafana, Loki, Mimir, SearXNG require source code availability if modified
- **Elastic License 2.0**: n8n has usage restrictions - see [LICENSES.md](../../LICENSES.md)
- **GPL 3.0**: Foreman and Puppet - see [LICENSES.md](../../LICENSES.md)
- **Open Source**: All other components use permissive open-source licenses (MIT, Apache 2.0, BSD)

For complete details, see [LICENSES.md](../../LICENSES.md).

---

## Notes

- **Private Registries**: OCI-based charts (like `litellm` and `n8n`) may require authentication
- **Version Pinning**: Always use caret (`^`) or tilde (`~`) versioning for stability
- **Custom Charts**: Charts in `homelab-helm-charts/charts/` are deployed from the git repo itself
- **Chart Updates**: Keep chart repos updated with `helm repo update`
- **License Compliance**: Review [LICENSES.md](../../LICENSES.md) before commercial deployment
