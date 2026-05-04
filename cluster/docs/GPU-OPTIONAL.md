# GPU Support (Optional)

This guide explains how to add NVIDIA GPU support to your homelab cluster.

## Is GPU Right for You?

GPU support is **optional**. Add it only if:

✅ **Yes, add GPU support if:**
- You have NVIDIA GPUs in your cluster (RTX, GTX, A100, Tesla, etc.)
- You plan to run GPU workloads (machine learning, video encoding, LLM inference with Ollama)
- You want to run applications like Home Assistant with GPU acceleration

❌ **Skip GPU support if:**
- Your cluster has no NVIDIA GPUs
- You don't need GPU workloads
- You're running on CPU-only or AMD GPU nodes

---

## Prerequisites

### 1. Hardware Check

```bash
# On any node with GPU(s), verify NVIDIA is present
lspci | grep -i nvidia

# Example output:
# 01:00.0 VGA compatible controller: NVIDIA Corporation TU104 [GeForce RTX 2080]
```

If no output, you have no NVIDIA GPUs.

### 2. NVIDIA Driver Installation

Before enabling GPU in Kubernetes, install NVIDIA drivers on each GPU node:

```bash
# Ubuntu/Debian
sudo apt-get install -y nvidia-driver-550

# Verify driver installed
nvidia-smi

# Example output:
# | NVIDIA-SMI 550.90.07              Driver Version: 550.90.07 |
# |---------|
# | GPU  Name              | Utilization |
# | 0    GeForce RTX 2080  | 0%           |
```

### 3. Container Runtime Support

If using **containerd** (recommended), ensure NVIDIA Container Toolkit is installed:

```bash
# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Restart containerd
sudo systemctl restart containerd

# Verify
nvidia-container-cli info
```

---

## Enabling GPU in Kubernetes

### Step 1: Enable NVIDIA Device Plugin

The `nvidia-device-plugin` Application (in stage-2) enables GPU scheduling in Kubernetes.

**If you have GPU nodes:** Keep the Application enabled (it's already in stage-2).

**If you don't have GPU nodes:** Remove or comment out the nvidia-device-plugin Application.

#### Option A: Remove nvidia-device-plugin (No GPU)

Edit `cluster/stages/stage-2/service.yaml`:

```bash
# Delete or comment out this section:
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nvidia-device-plugin
  namespace: argocd
spec:
  # ... (delete entire section if no GPUs)
```

#### Option B: Keep it enabled (Has GPU)

The Application is already configured. When ArgoCD syncs stage-2, NVIDIA Device Plugin will be installed automatically.

### Step 2: Verify GPU Discovery

```bash
# After stage-2 syncs, wait for the device plugin to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=nvidia-device-plugin \
  -n nvidia-device-plugin --timeout=300s

# Check that nodes advertise GPUs
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, gpus: .status.allocatable["nvidia.com/gpu"]}'

# Example output:
# {
#   "name": "gpu-node-1",
#   "gpus": "1"
# }
# {
#   "name": "gpu-node-2",
#   "gpus": "2"
# }
```

### Step 3: Configure NVIDIA Runtime in containerd (if needed)

If the device plugin shows 0 GPUs despite drivers being installed, configure the NVIDIA runtime in containerd:

```bash
# Edit containerd config
sudo tee /etc/containerd/config.toml > /dev/null << 'EOF'
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
  runtime_engine = ""
  runtime_root = ""
  runtime_type = "io.containerd.runc.v2"
  
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
    BinOverride = "/usr/bin/nvidia-container-runtime"
EOF

# Restart containerd
sudo systemctl restart containerd
```

---

## Using GPUs in Workloads

### Simple: Node Affinity

To schedule a pod on GPU nodes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-app
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: nvidia.com/gpu
                    operator: Exists  # Node has GPUs
      containers:
        - name: app
          image: nvidia/cuda:12.0-runtime
          resources:
            limits:
              nvidia.com/gpu: 1  # Request 1 GPU
```

### Advanced: Label GPU Nodes by Type

If you have mixed GPU types (RTX 2080, RTX 4090, A100, etc.), label them:

```bash
# Label a node as having RTX 4090
kubectl label nodes gpu-node-1 gpu-type=rtx-4090

# Then use in pod spec
nodeSelector:
  gpu-type: rtx-4090
```

### Example Workload: Ollama with GPU

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-gpu
  namespace: llm
spec:
  replicas: 1
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: nvidia.com/gpu
                    operator: Exists
      containers:
        - name: ollama
          image: ollama/ollama:0.3.12  # pin to a specific version; check https://hub.docker.com/r/ollama/ollama/tags
          resources:
            requests:
              nvidia.com/gpu: 1
            limits:
              nvidia.com/gpu: 1
          env:
            - name: CUDA_VISIBLE_DEVICES
              value: "0"
```

---

## Monitoring GPU Usage

### With NVIDIA DCGM Exporter

The `monitors` Application (stage-3) includes DCGM (Data Center GPU Manager) for monitoring:

```bash
# Check DCGM metrics are being scraped
kubectl get servicemonitor -n prometheus | grep dcgm

# View GPU metrics in Prometheus
# In Prometheus UI, search for: DCGM_FI_
# Examples: DCGM_FI_DEV_GPU_UTIL (GPU utilization), DCGM_FI_DEV_FB_USED (memory used)
```

### Manual GPU Monitoring

```bash
# SSH to a GPU node and run
nvidia-smi -l 1  # Update every 1 second

# In Kubernetes pod
kubectl exec <pod-name> -n <namespace> -- nvidia-smi
```

---

## Troubleshooting

### GPUs Not Detected

**Symptom:** `kubectl get nodes` shows `nvidia.com/gpu: 0`

**Causes & Fixes:**
1. **Drivers not installed** → Run `sudo apt-get install -y nvidia-driver-550`
2. **Container runtime not configured** → Install `nvidia-container-toolkit` and restart containerd
3. **NVIDIA Container Runtime not in PATH** → Verify `/usr/bin/nvidia-container-runtime` exists
4. **Device plugin not running** → Check `kubectl logs -n nvidia-device-plugin <pod-name>`

```bash
# Debug device plugin
kubectl describe pod -n nvidia-device-plugin $(kubectl get pod -n nvidia-device-plugin -o name)

# Check for errors
kubectl logs -n nvidia-device-plugin -l app.kubernetes.io/name=nvidia-device-plugin --tail=50
```

### Pods Pending with GPU Request

**Symptom:** Pod stuck in Pending state requesting `nvidia.com/gpu: 1`

**Causes & Fixes:**
1. **No GPU nodes available** → Verify at least one node has GPUs: `kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, gpus: .status.allocatable["nvidia.com/gpu"]}'`
2. **All GPUs in use** → Wait for other pods to release GPUs or add more nodes
3. **GPU memory insufficient** → Reduce memory request or use smaller model

### High GPU Temperature

**Symptom:** `nvidia-smi` shows high temperature (>80°C)

**Fixes:**
- Check GPU cooling (fans spinning)
- Reduce workload intensity
- Spread workload across multiple GPUs
- Add thermal monitoring via Prometheus/Grafana

---

## Disabling GPU Support

If you added GPU support but no longer need it:

### Option 1: Comment Out the Application

Edit `cluster/stages/stage-2/service.yaml` and comment out the `nvidia-device-plugin` Application:

```yaml
# ---
# apiVersion: argoproj.io/v1alpha1
# kind: Application
# metadata:
#   name: nvidia-device-plugin
#   ...
```

Then push to Git. ArgoCD will automatically uninstall it.

### Option 2: Delete the Namespace

```bash
kubectl delete namespace nvidia-device-plugin
```

This removes the device plugin but doesn't prevent it from being reinstalled if the Application remains active.

### Option 3: Uninstall NVIDIA Drivers (Optional)

If you want to remove NVIDIA drivers from nodes:

```bash
# Remove drivers
sudo apt-get remove -y nvidia-driver-550 nvidia-container-toolkit

# Restart containerd
sudo systemctl restart containerd
```

---

## References

- [NVIDIA Kubernetes Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)
- [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit)
- [NVIDIA DCGM Documentation](https://developer.nvidia.com/dcgm)
- [Kubernetes GPU Resources](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)
