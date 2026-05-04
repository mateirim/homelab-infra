# ADR-001: CNI Selection — Cilium

**Status:** Accepted (Active)

**Date:** 2026-05-04

**Authors:** Matei Rimboaca

---

## Context

A Kubernetes cluster requires a Container Network Interface (CNI) plugin to:
- Assign IP addresses to pods
- Route packets between pods and nodes
- Enforce network policies
- Enable service discovery

Multiple CNI options exist:
- **Cilium** — eBPF-based, advanced features, steep learning curve
- **Calico** — Mature, widely used, scalable, simpler to understand
- **Flannel** — Lightweight, simple, minimal features
- **Weave** — Decentralized mesh networking

This homelab environment has specific needs:
- Multi-node setup on a home network (not cloud provider)
- BGP peering with home network equipment (router)
- Advanced observability (Hubble)
- Native routing without overlays
- Mix of architectures (amd64 + ARM64)

---

## Decision

**Use Cilium as the CNI plugin** with the following configuration:
- **eBPF dataplane** for high performance
- **Native routing** (no tunnel overlay)
- **BGP control plane** for dynamic routing
- **Hubble** for network observability
- **kube-proxy replacement** to reduce system overhead

---

## Rationale

### Why Cilium over Calico

1. **BGP support with more flexibility**
   - Cilium's BGP control plane supports per-node ASN configuration
   - Allows different node types (RPi, x86 servers) to peer with different routes
   - Calico BGP is more rigid (single cluster ASN)

2. **eBPF efficiency**
   - Cilium uses Linux eBPF for data plane (in-kernel)
   - Calico uses iptables (kernel rules, but less efficient)
   - For a resource-constrained homelab (limited CPU on RPi nodes), eBPF is better

3. **Native routing**
   - Cilium's native routing mode has zero packet encapsulation overhead
   - Calico's native routing requires BGP; Cilium's is more straightforward

4. **Hubble observability**
   - Built-in network observability without additional tools
   - Visualize pod-to-pod traffic in real time
   - Useful for debugging multi-node networking issues

5. **kube-proxy replacement**
   - Cilium can replace kube-proxy entirely (reduces system load)
   - Better performance for service load balancing
   - Calico still requires kube-proxy

### Why not Flannel or Weave

- **Flannel:** No BGP support, no network policies, overlay-only
- **Weave:** Mesh networking adds complexity without our use case need

### Trade-offs

**Complexity:** Cilium is more complex than Calico/Flannel
- Learning curve: eBPF concepts, BGP configuration
- Debugging: More knobs to tune
- **Mitigation:** Good documentation, active community, Hubble helps debug

**Documentation:** Calico has more tutorials for standard setups
- **Mitigation:** We provide concrete configs in this repo

---

## Implementation

### Cilium Configuration (cluster/infrastructure/cni/cilium-values.yaml)

```yaml
kubeProxyReplacement: true        # Replace kube-proxy
routingMode: native               # No tunnel overlay
ipv4NativeRoutingCIDR: 10.200.0.0/16
autoDirectNodeRoutes: true        # Automatic route distribution
bgpControlPlane:
  enabled: true                   # Enable BGP
hubble:
  enabled: true                   # Network observability
endpointRoutes:
  enabled: true                   # Efficient endpoint routing
```

### BGP Peering (cluster/infrastructure/cni/pool.yaml)

Define per-node-type BGP peers:
- RPi nodes: ASN 60512 → Router peer 192.168.1.1/24
- x86 nodes: ASN 60513 → Router peer 192.168.1.1/24
- ...

Each node announces its pod CIDR to the network, enabling external traffic to reach pods.

---

## Consequences

### Positive

✅ **Performance:** eBPF + native routing = minimal overhead
✅ **Observability:** Hubble provides pod-to-pod traffic visibility
✅ **Scalability:** Cilium scales to large clusters
✅ **Multi-arch:** Works seamlessly on amd64 + ARM64
✅ **Home network integration:** BGP peering allows external access to pods

### Negative

❌ **Complexity:** More to learn and configure
❌ **Debugging:** eBPF issues are harder to troubleshoot than iptables
❌ **Documentation:** Fewer blog posts/tutorials than Calico

### Mitigations

- Provide concrete, tested configurations (in this repo)
- Include troubleshooting guide (cluster/docs/)
- Use Hubble UI for observability
- Version pin Cilium (avoid bleeding-edge versions)

---

## Alternatives Considered

### Calico
- Mature, widely used
- Better for cloud-native (AWS, GCP, Azure have native Calico support)
- Less flexible for home network BGP

### Flannel
- Lightweight, good for resource-constrained environments
- No BGP, no network policies — not suitable for this homelab's needs

### Weave
- Decentralized, no control plane
- Overly complex for our networking model

---

## Related Decisions

- [ADR-002: Secrets Management (SOPS + GPG)](ADR-002-Secrets.md)
- [ADR-003: Kubernetes Distribution (kubeadm)](ADR-003-kubeadm-vs-k3s.md)

---

## References

- [Cilium Documentation](https://docs.cilium.io/)
- [Cilium BGP Control Plane](https://docs.cilium.io/en/latest/gettingstarted/bgp/)
- [Hubble: Network Observability](https://docs.cilium.io/en/latest/gettingstarted/hubble/)
- [Cilium vs Calico Comparison](https://cilium.io/blog/2023/11/08/cilium-calico-network-policies/)
