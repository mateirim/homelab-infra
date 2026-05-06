# ADR-003: Kubernetes Distribution — kubeadm

**Status:** Accepted | **Date:** 2026-05-04

## Decision

Use kubeadm with containerd on all nodes. Puppet handles node preparation (kernel tuning, swap, container runtime).

## Why

- **Educational** — exposes etcd, scheduler, controller-manager configs directly; k3s hides this
- **Unmodified Kubernetes** — all features available; k3s strips some by default
- **Full control** — explicit kernel tuning, CNI choice, component config
- **Industry standard** — skills transfer to enterprise clusters

## Trade-offs

- More setup steps than k3s; more moving parts to debug
- Higher baseline resource usage than k3s (marginal in practice)

## Alternatives Rejected

- **k3s** — opinionated defaults, edge/IoT focus, less educational
- **RKE2** — vendor-specific, enterprise features not needed
- **Kubespray** — Ansible-based complexity we already cover with Puppet
