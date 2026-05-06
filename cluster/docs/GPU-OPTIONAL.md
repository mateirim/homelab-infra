# GPU Support (Optional)

Only needed if you have NVIDIA GPUs and plan to run Ollama/LLM inference or video workloads.

## Prerequisites (on each GPU node)

```bash
sudo apt-get install -y nvidia-driver-550 nvidia-container-toolkit
sudo systemctl restart containerd
nvidia-smi  # verify driver works
```

## Enable in Kubernetes

The `nvidia-device-plugin` Application is included in stage-2. It deploys automatically if left enabled.

To disable (no GPU nodes), remove or comment out the `nvidia-device-plugin` Application in `cluster/stages/stage-2/service.yaml`.

Verify GPU discovery after stage-2 syncs:

```bash
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, gpus: .status.allocatable["nvidia.com/gpu"]}'
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Node shows `nvidia.com/gpu: 0` | Check driver + container toolkit installed, restart containerd |
| Pod stuck Pending with GPU request | Verify at least one node advertises GPUs; check all GPUs not already in use |
| Device plugin not starting | `kubectl logs -n nvidia-device-plugin -l app.kubernetes.io/name=nvidia-device-plugin` |
