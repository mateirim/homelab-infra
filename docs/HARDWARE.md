# Hardware Requirements & Degradation Scenarios

This guide documents hardware requirements for the homelab-infra cluster and what happens when you run with less-than-ideal configurations.

---

## Real-World Resource Baseline (Author's Cluster)

> **Measured:** 2026-05-05, full stack running (all 3 stages deployed).
> Includes: ArgoCD, Cilium, Prometheus+Mimir+Loki, Puppet+PuppetDB+Foreman,
> Home Assistant, LLM stack (Ollama+Open-WebUI+LiteLLM+Whisper+SearXNG),
> Nextcloud+PhotoPrism, Jenkins+Runners, Keycloak, Postgres+MongoDB+Redis HA,
> Pihole, WireGuard, Tailscale, Akeyless, KEDA, cert-manager.

### Example Node Layout

| Node (example) | Role | Arch | CPU (cores) | RAM (GB) |
|---|---|---|---|---|
| worker-x86-large | Worker (high-mem) | amd64 | 24 | 80 |
| worker-x86 | Worker | amd64 | 4 | 16 |
| control-plane | **Control Plane** | arm64 | 4 | 8 |
| worker-arm-1 | Worker | arm64 | 4 | 8 |
| worker-arm-2 | Worker | arm64 | 4 | 8 |
| worker-arm-3 | Worker | arm64 | 4 | 8 |
| **Total** | | mixed | **44** | **128** |

### Idle/Baseline Usage (Full Stack Running, No Active Jobs)

| Node Type | CPU Used | CPU % | RAM Used | RAM % |
|---|---|---|---|---|
| Worker (high-mem, amd64) | 519m | 2% | 17.4 GiB | 22% |
| Worker (amd64) | 1,676m | 42% | 11.8 GiB | 76% |
| Worker (arm64) × 3 | 2,594m–3,638m | 19–91% | 1.4–5.7 GiB | 18–73% |
| **Cluster Total** | **~11.3 cores** | **~26%** | **~44 GiB** | **~34%** |

> ⚠️ ARM worker nodes running Redis HA sentinel sit at 84–91% CPU at idle —
> Redis sentinel replication is CPU-chatty even with zero traffic.

### Top Memory Consumers at Idle

| Workload | Namespace | Memory |
|---|---|---|
| Puppet Server (compiler) | puppet | 1,636 Mi |
| Puppet Server (master) | puppet | 1,336 Mi |
| Home Assistant | homeassistant | 1,309 Mi |
| Whisper (speech-to-text) | llm | 1,295 Mi |
| Prometheus | prometheus | 1,286 Mi |
| kube-apiserver | kube-system | 1,277 Mi |
| PuppetDB | puppet | 1,135 Mi |
| Mimir Ingesters (×3) | mimir | ~1.9 GiB |
| ArgoCD Application Controller | argocd | 630 Mi |
| Cilium agents (×6) | kube-system | ~2.0 GiB |

### Top CPU Consumers at Idle

| Workload | Namespace | CPU |
|---|---|---|
| Redis HA sentinels (×2) | database | ~1,900m |
| kube-apiserver | kube-system | 123m |
| Prometheus | prometheus | 109m |
| Mimir Distributor | mimir | 97m |
| ArgoCD Repo Server | argocd | 93m |

### What This Means for You

| Your Cluster Size | Expected Idle RAM Usage | Headroom |
|---|---|---|
| 4 nodes / 16 GB RAM | ~80–90% | Very tight; skip LLM + Puppet |
| 5 nodes / 20 GB RAM | ~70% | Workable; monitor carefully |
| 6 nodes / 24 GB RAM | ~55–65% | Comfortable for all apps |
| 6+ nodes / 40+ GB RAM | ~40% | Recommended; room to grow |

The heaviest components to **skip or defer** on smaller clusters:
1. **Puppet + PuppetDB + Foreman** — ~4 GiB RAM combined
2. **Mimir** (long-term metrics) — ~2 GiB; Prometheus alone suffices for short-term
3. **LLM stack (Whisper, Ollama, etc.)** — 1–4+ GiB depending on models loaded
4. **Redis HA (3-node sentinel)** — CPU-intensive at idle; single Redis is fine for most use cases

---

## Recommended Configuration

**Total cluster resources:** 6 nodes, 24GB+ RAM, 120GB+ storage

```
Control Plane:  1 node × 8GB RAM + 40GB SSD (OS + etcd)
Workers:        5 nodes × 4GB RAM + 20GB storage each (Kubernetes workloads)
                                           OR
                4 nodes × 6GB RAM + 40GB storage each (denser, fewer nodes)
GPU Node:       1 node × 16GB RAM + 2× NVIDIA GPU (optional, for LLM inference)
```

**Network:** 1Gbps+ interconnect between nodes, stable DNS

---

## Minimum Viable Configuration

**Absolute bare minimum:** 4 nodes, 16GB total RAM

```
Control Plane:  1 node × 4GB RAM + 30GB SSD
Workers:        3 nodes × 4GB RAM + 20GB storage each
```

**What works:** All core infrastructure (networking, storage, monitoring, ArgoCD, databases)

**What is disabled/scaled down:**
- Jenkins CI/CD (workload scaling disabled, limited pipeline parallelism)
- LLM inference (Ollama disabled or very limited model serving)
- Redundancy for databases (PostgreSQL HA requires 3+ nodes minimum)
- Home Assistant optional automations
- PhotoPrism image processing disabled
- NVIDIA GPU support not available

---

## Degradation Scenarios

### Scenario 1: 3 Nodes (Not Recommended)

**Configuration:**
- 1 control plane + 2 workers
- 12GB total RAM (4GB each)
- Single point of failure on control plane

**What happens:**

✅ **Works:**
- Cilium networking (single-node BGP works)
- NFS storage provisioning
- ArgoCD GitOps sync
- Prometheus + Grafana monitoring
- Keycloak SSO (single instance)
- DNS (Pi-hole single instance)

❌ **Fails or degraded:**
- Kubernetes API downtime if control plane dies (no HA)
- PostgreSQL high-availability (needs 3+ nodes minimum)
  - Workaround: Single PostgreSQL instance (no replication)
- Jenkins runs jobs sequentially (resource contention on workers)
- Home Assistant may restart frequently (memory pressure)
- LLM inference disabled (insufficient resources)

**Verdict:** Possible for **development/testing only**. Not suitable for production or long-running workloads.

---

### Scenario 2: 4 Nodes (Minimum Viable)

**Configuration:**
- 1 control plane + 3 workers
- 16GB total RAM (4GB control, 4GB each worker)
- No GPU

**What happens:**

✅ **Works well:**
- All Stage 1 services (CNI, namespaces, ArgoCD, NFS)
- All Stage 2 infrastructure (databases, TLS, proxy, DNS)
- PostgreSQL HA with 3 replicas (minimal but functional)
- Most Stage 3 applications (Nextcloud, Keycloak, Jenkins)
- Prometheus + Grafana monitoring
- Puppet + Foreman configuration management

⚠️ **Works with limitations:**
- Jenkins builds may queue (limited worker resources)
- LLM inference very slow (Ollama on CPU-only)
- Home Assistant automation delays possible
- PhotoPrism image indexing takes hours (CPU-bound)
- Monitor memory: cluster runs at 70-80% utilization
- No buffer for node maintenance without service degradation

❌ **Disabled:**
- GPU-accelerated LLM inference
- Simultaneous Jenkins pipelines (serialized)
- Heavy ETL workloads

**Verdict:** **Suitable for small production homelabs** with moderate usage. Works fine if you're not running 20 Jenkins jobs in parallel or serving LLM requests continuously.

---

### Scenario 3: 5-6 Nodes (Recommended)

**Configuration:**
- 1 control plane + 4-5 workers
- 20-24GB total RAM (8GB control, 4GB each worker)
- Optional GPU node

**What happens:**

✅ **All services run comfortably:**
- Full PostgreSQL HA with replication + failover
- Jenkins parallel builds (up to 4 concurrent)
- Ollama inference with reasonable latency
- Home Assistant full automation stack
- PhotoPrism background indexing doesn't block UI
- Cluster runs at 50-60% utilization (healthy margin)

✅ **Optional GPU support:**
- Add GPU node for LLM inference acceleration
- Ollama uses NVIDIA CUDA (10-50× faster)
- Real-time chat completions + embeddings

**Verdict:** **Recommended for all use cases**. Comfortable resource headroom, no performance anxiety.

---

## Resource Requests & Limits by Workload

### Stage 1: Foundation

| Component | CPU Req | CPU Limit | Memory Req | Memory Limit |
|-----------|---------|-----------|-----------|-------------|
| Cilium | 100m | 500m | 128Mi | 512Mi |
| ArgoCD | 200m | 1000m | 256Mi | 1Gi |
| NFS Provisioner | 100m | 500m | 128Mi | 256Mi |
| Prometheus | 100m | 1000m | 512Mi | 2Gi |

**Total Stage 1:** ~500m CPU, ~1Gi RAM

### Stage 2: Infrastructure

| Component | CPU Req | Memory Req | Notes |
|-----------|---------|-----------|-------|
| PostgreSQL | 500m | 1Gi | Per replica if HA |
| MongoDB | 500m | 1Gi | - |
| Redis HA | 100m | 256Mi | Per replica |
| nginx ingress | 200m | 256Mi | - |
| cert-manager | 100m | 128Mi | - |

**Total Stage 2:** ~1.5 CPU, ~4Gi RAM (includes DB replicas)

### Stage 3: Applications

| Component | CPU Req | Memory Req | Notes |
|-----------|---------|-----------|-------|
| Jenkins | 500m | 1Gi | Scales with pipeline parallelism |
| Nextcloud | 200m | 512Mi | - |
| Home Assistant | 100m | 512Mi | - |
| Grafana | 100m | 256Mi | - |
| Keycloak | 200m | 512Mi | - |
| Ollama (CPU) | 500m | 4Gi | CPU-only; needs GPU for acceleration |
| Open-WebUI | 100m | 512Mi | - |

**Total Stage 3:** ~2-2.5 CPU, ~8-10Gi RAM

---

## Scaling Guidelines

### For < 4 Nodes (Unsupported):
- Disable advanced applications (LLM, Jenkins, HA databases)
- Run Stage 1 + core Stage 2 only (CNI, storage, ArgoCD, single-instance databases)
- Expect performance issues and service restarts

### For 4 Nodes:
- All applications fit, but running at 70%+ utilization
- Not recommended for simultaneous heavy workloads
- Good for: dev/test + light production usage
- Skip: GPU, LLM inference, Jenkins parallelism

### For 5+ Nodes:
- All applications run comfortably
- ~50-60% utilization (healthy headroom)
- Supports node maintenance without downtime
- Can safely run 2-4 Jenkins jobs in parallel
- Optional: GPU node for LLM acceleration

---

## Memory Pressure Scenarios

### What happens if memory runs out?

1. **Kubernetes memory pressure** → kubelet evicts pods by priority
2. **Eviction order** (worst first):
   - Pods without resource requests (rarely happens with this setup)
   - Jenkins builds (highest memory consumer)
   - Home Assistant
   - Application workloads
   - System pods (less likely)

3. **Database corruption risk:**
   - PostgreSQL/MongoDB killed mid-transaction
   - Data inconsistency if not using persistent volumes
   - Recovery time: 10-30 minutes

**Mitigation:** Monitor memory usage in Grafana; plan node upgrades or scaling before hitting 80% utilization.

---

## CPU Pressure Scenarios

### What happens if CPU is overloaded?

1. **Workloads queue** → Jobs wait for available CPU time
2. **Impact:**
   - Jenkins builds take 2-3× longer
   - Ollama inference latency increases 5-10×
   - Nginx ingress response times increase
   - API requests to Keycloak/Nextcloud slow down

3. **No corruption** → Unlike memory, CPU pressure doesn't cause data loss

**Mitigation:** Jenkins supports auto-scaling; configure KEDA to scale runners when queue depth increases.

---

## Network Considerations

### Required:
- **Cluster-internal network:** 1Gbps+ (10Gbps recommended for HA databases)
- **Latency:** < 50ms between nodes (same LAN/datacenter)
- **Bandwidth per node:** 
  - Control plane: 10-50 Mbps (API requests)
  - Workers: 50-500 Mbps (depends on workload)
- **Egress:** Required for:
  - GitHub (ArgoCD pulls)
  - Let's Encrypt (cert renewal)
  - Model downloads (Ollama)
  - External monitoring feeds

### Optional:
- **VPN/WireGuard** → Adds 5-10% latency, not recommended for same-LAN clusters
- **LoadBalancer external IPs** → Cilium IPAM pool (configured in Stage 1)

---

## Storage Requirements

### Minimum:
- **Control plane:** 30GB SSD (etcd + OS)
- **Workers:** 20GB per node (container images + ephemeral storage)
- **NFS:** 50-100GB shared (databases, Nextcloud, backups)

### Recommended:
- **Control plane:** 50GB SSD
- **Workers:** 40GB each
- **NFS:** 500GB+ (allows growth + backup retention)

### High-performance setup:
- **Control plane:** 100GB NVMe SSD
- **Workers:** 60GB NVMe each
- **NFS:** 1TB+ on ZFS/btrfs with RAID1

---

## Monitoring Your Hardware

### Check CPU/Memory in Grafana:

1. Open Grafana (`https://grafana.yourdomain.com`)
2. Dashboard: **Kubernetes Cluster Monitoring** → Node metrics
3. Watch for:
   - Sustained memory > 80% → Plan scaling
   - Sustained CPU > 75% → Check for runaway workloads (Jenkins, Ollama)
   - Disk > 85% → Cleanup container images or grow NFS

### Command-line checks:

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage (by namespace)
kubectl top pods -n kube-system
kubectl top pods -n default

# Watch for memory pressure
kubectl describe nodes | grep -A 5 "MemoryPressure"

# Check PVC usage
kubectl get pvc -A -o wide
```

---

## Recommendations by Use Case

### Use Case: Home Automation Only
**Minimum:** 3 nodes, 12GB RAM
- Home Assistant (single instance)
- Nextcloud (optional)
- Skip: Jenkins, LLM, advanced monitoring
- **Risk:** Single point of failure on control plane

### Use Case: Development/Testing
**Minimum:** 4 nodes, 16GB RAM
- All applications at reduced scale
- Good for learning Kubernetes
- Jenkins jobs serialized
- **Risk:** Not suitable for production

### Use Case: Small Production Homelab
**Recommended:** 5 nodes, 20GB RAM
- All applications running
- PostgreSQL HA for critical data
- Jenkins parallelism enabled
- Comfortable resource headroom
- **Risk:** Low; suitable for real workloads

### Use Case: Large Production Homelab
**Recommended:** 6+ nodes, 24GB+ RAM + GPU
- Full application stack
- GPU acceleration for LLM
- Jenkins parallel builds (4-8 concurrent)
- Room for growth
- **Risk:** None; production-ready

---

## Troubleshooting

### Cluster feels slow
```bash
# Check node status
kubectl get nodes
kubectl top nodes

# Check for evicted pods
kubectl get pods -A | grep Evicted
kubectl delete pods -A --field-selector status.phase=Failed
```

### Services keep restarting
```bash
# Check for memory/CPU pressure
kubectl describe nodes | grep -E "MemoryPressure|DiskPressure|CPUPressure"

# Check pod events
kubectl describe pod <pod-name> -n <namespace>
```

### Database performance degraded
```bash
# Check PostgreSQL pod resources
kubectl top pod -n database -l app=postgresql

# Check persistent volume I/O
kubectl exec -it -n database <postgres-pod> -- iostat -x 1
```

---

See [GETTING_STARTED.md](GETTING_STARTED.md) for deployment instructions and [../cluster/docs/](../cluster/docs/) for deeper architecture details.
