# ADR-002: Secrets Management — SOPS + GPG

**Status:** Accepted | **Date:** 2026-05-04

## Decision

Encrypt secrets with SOPS + GPG. Secrets live in Git, encrypted at rest. `setup.sh` configures SOPS with the user's GPG fingerprint. ArgoCD AVP decrypts at deploy time.

## Why

- **Portable** — not bound to a specific cluster; rebuild without losing secrets
- **Forkable** — contributors run `setup.sh` with their own GPG key, no shared secrets needed
- **Git-native** — all config in one place, no external systems
- Secrets never hit etcd unencrypted (decryption happens in ArgoCD)

## Trade-offs

- GPG key loss = encrypted secrets lost; requires key backup discipline
- No in-place secret rotation; re-encryption + git commit required

## Alternatives Rejected

- **Sealed Secrets** — cluster-bound, unrecoverable if cluster key lost
- **External Secrets / Vault** — operational overhead, overkill for homelab
- **Plain K8s Secrets** — unencrypted, not acceptable
