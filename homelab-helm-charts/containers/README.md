# Container Images

Multi-architecture Docker builds (amd64 + arm64) for Kubernetes workloads.

## Architecture Support

| Image | Architectures | Notes |
| --- | --- | --- |
| homelab-operator | amd64, arm64 | ✅ Full multi-arch |
| r10k | amd64, arm64 | ✅ Full multi-arch |
| actions-runner | amd64, arm64 | ✅ Depends on upstream |
| promtail-syslog | amd64, arm64 | ✅ Depends on upstream |
| puppetserver | amd64, arm64 | ✅ Depends on upstream |
| foreman | amd64 only | ❌ CentOS Stream 9 (ARM not available) |
| foreman-centos | amd64 only | ❌ CentOS Stream 9 (ARM not available) |

## Build

Single architecture (local):
```bash
docker build -t registry.homelab.local/homelab-operator:latest containers/homelab-operator/
```

Multi-architecture (requires buildx):
```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t registry.homelab.local/homelab-operator:latest \
  --push containers/homelab-operator/
```

## Automated Releases

GitHub Actions (`.github/workflows/containers.yml`) automatically:
1. Detects changed container directories on push to main
2. Builds multi-arch images (amd64 + arm64)
3. Pushes to `registry.homelab.local/images/<container-name>:latest`

## Multi-Architecture Notes

Docker Buildx automatically includes qemu-user-static for cross-compilation. No manual setup required.

Use build arguments in Dockerfile:
```dockerfile
ARG TARGETOS
ARG TARGETARCH

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o app .
```
