# ADR-001: CNI — Cilium

**Status:** Accepted | **Date:** 2026-05-04

## Decision

Use Cilium with eBPF dataplane, native routing, BGP control plane, Hubble, and kube-proxy replacement.

## Why

- BGP peering with home router — per-node ASN, more flexible than Calico
- eBPF in-kernel dataplane — lower overhead on RPi nodes vs iptables
- Native routing — zero encapsulation overhead
- Hubble — built-in pod-to-pod observability, no extra tools needed
- kube-proxy replacement — fewer system processes

## Trade-offs

- More complex than Calico/Flannel; eBPF debugging is harder than iptables
- Fewer tutorials than Calico for standard setups

## Alternatives Rejected

- **Calico** — rigid BGP (single cluster ASN), requires kube-proxy
- **Flannel** — no BGP, no NetworkPolicies
- **Weave** — unnecessary complexity for this networking model
