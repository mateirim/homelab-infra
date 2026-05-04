# Security Policy

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use GitHub's private vulnerability reporting instead:

👉 **[Report a vulnerability](https://github.com/mateirim/homelab-infra/security/advisories/new)**

This keeps the report private until a fix is ready.

## Scope

This is a **homelab reference template**, not a production service. Security reports most relevant to this repo:

- Secrets accidentally committed (unencrypted credentials, tokens, keys)
- Insecure default configurations that could mislead users
- SOPS/GPG setup guidance that could expose secrets

## What to Expect

- Acknowledgement within a few days
- Fix or guidance as fast as reasonably possible for a personal project
- Credit in the commit/release notes if you'd like

## Out of Scope

- Vulnerabilities in upstream projects (ArgoCD, Cilium, Prometheus, etc.) — report those to their respective maintainers
- Theoretical risks with no practical exploit path in a homelab context
