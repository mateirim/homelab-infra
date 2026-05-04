# Add persistent routes on Windows to reach the K8s pod/service network via your WireGuard gateway
#
# Before running: edit cluster/infrastructure/cni/pool.yaml to set:
#   - LB CIDR (LoadBalancer IP pool): typically 192.168.1.200/24
#   - Service CIDR: typically 10.172.0.0/16 (from kubeadm-init-2026.yaml)
#   - Pod CIDR: typically 10.200.0.0/16 (from kubeadm-init-2026.yaml)
#   - GATEWAY_IP: your router IP (set in setup.sh)
#
# For a Windows machine to reach the cluster (e.g., via WireGuard VPN):

# Example — run as Administrator in PowerShell:
# $GATEWAY_IP = "192.168.1.X"      # your WireGuard gateway / VPN entry point
# $LB_CIDR = "192.168.1.200/24"    # from pool.yaml
# $SERVICE_CIDR = "10.172.0.0/16"  # from kubeadm-init-2026.yaml
# $POD_CIDR = "10.200.0.0/16"      # from kubeadm-init-2026.yaml
#
# route add $LB_CIDR mask 255.255.255.0 $GATEWAY_IP -p
# route add $SERVICE_CIDR mask 255.255.0.0 $GATEWAY_IP -p
# route add $POD_CIDR mask 255.255.0.0 $GATEWAY_IP -p
