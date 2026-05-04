# role::k8s_worker
#
# Role for Kubernetes worker nodes in the Homelab-K8s-piCluster.
# Assigns all profiles needed to turn a vanilla Debian/Ubuntu VM into
# a fully prepared kubeadm worker node.
#
# To assign this role to a node, add to its Hiera node YAML:
#
#   role:
#     - role::k8s_worker
#
# Joining the cluster is intentionally manual — once Puppet has converged,
# run the kubeadm join command with the token from the control plane.

class role::k8s_worker {
  # Base OS hardening, MOTD, common tools
  include profile::linux_base

  # Kubernetes worker prerequisites + containerd + kubelet
  include profile::k8s_worker
}
