# Helm Charts

All charts are deployed via ArgoCD Applications in `cluster/infrastructure/<namespace>/service.yaml`.
License attribution: [docs/LICENSES.md](../../docs/LICENSES.md).

## External Charts

| Chart | Version | Repo |
| --- | --- | --- |
| cilium | ^1.15.0 | `https://helm.cilium.io/` |
| ingress-nginx | ^4.7.1 | `https://kubernetes.github.io/ingress-nginx` |
| cert-manager | ^1.13.0 | `https://charts.jetstack.io` |
| keda | ^2.16.0 | `https://kedacore.github.io/charts` |
| nfs-subdir-external-provisioner | ^4.0.18 | `https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner` |
| prometheus-stack | ^25.0.0 | `https://prometheus-community.github.io/helm-charts` |
| grafana | ^6.59.4 | `https://grafana.github.io/helm-charts` |
| loki-stack | ^2.9.11 | `https://grafana.github.io/helm-charts` |
| mimir-distributed | ^5.0.0 | `https://grafana.github.io/helm-charts` |
| redis-ha | ^4.1.0 | `https://dandydeveloper.github.io/charts` |
| community-operator | ^0.8.3 | `https://mongodb.github.io/helm-charts` |
| keycloak | ^19.3.3 | `https://charts.bitnami.com/bitnami` |
| open-webui | ^3.1.9 | `https://helm.openwebui.com/` |
| ollama | ^1.36.0 | `https://helm.otwld.com/` |
| litellm-helm | ^0.1.2 | `oci://docker.litellm.ai/berriai/litellm-helm` |
| openclaw | ^1.3.0 | `https://serhanekicii.github.io/openclaw-helm` |
| searxng | ^1.0.7 | `https://charts.kubito.dev` |
| n8n | ^2.0.1 | `oci://8gears.container-registry.com/library/n8n` |
| whisper | ^1.0.0 | `https://andrenarchy.github.io/helm-charts/` |
| wyoming-piper | 0.1.3 | `https://gitlab.com/api/v4/projects/62293226/packages/helm/stable` |
| home-assistant | ^1.34.0 | `https://charts.pree.dev` |
| music-assistant-server | ^0.1.9 | `https://lmatfy.github.io/charts` |
| jenkins | ^4.0.0 | `https://charts.jenkins.io` |
| argocd | ^6.0.0 | `https://argoproj.github.io/argo-helm` |
| puppetserver | ^9.2.0 | `https://puppetlabs.github.io/puppetserver-helm-chart` |
| actions-runner-controller | ^0.23.7 | `https://actions-runner-controller.github.io/actions-runner-controller` |
| metrics-server | 6.5.5 | `https://charts.bitnami.com/bitnami` |
| nvidia-device-plugin | ^0.14.0 | `https://nvidia.github.io/k8s-device-plugin` |

## Custom Charts & Images

Custom Helm charts live in [`helm-charts/charts/`](../../helm-charts/charts/).
Their Docker images are built from [`helm-charts/containers/`](../../helm-charts/containers/) and pushed to the **in-cluster registry** (`registry.yourdomain.com`).

| Chart | Dockerfile | Image | Description |
| --- | --- | --- | --- |
| foreman | `containers/foreman/` | `registry.yourdomain.com/foreman` | Puppet reporting + analytics |

Other available Dockerfiles (no chart, used directly): `puppetserver`, `actions-runner`, `promtail-syslog`, `r10k`.

### Pushing Images

The registry must be running (stage-2) before pushing.

```bash
docker build -t registry.REPLACE_WITH_YOUR_DOMAIN/<image>:<tag> helm-charts/containers/<image>/
docker push registry.REPLACE_WITH_YOUR_DOMAIN/<image>:<tag>
```

## Adding a New Chart

1. Add a source block to `cluster/infrastructure/<namespace>/service.yaml`
2. Add a values file `cluster/infrastructure/<namespace>/<chart>-values.yaml`
3. Update [docs/LICENSES.md](../../docs/LICENSES.md) with license info
4. `git push` — ArgoCD auto-syncs
