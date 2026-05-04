# Puppet Control Repository

Configuration management with r10k and Hiera.

## Structure

- **manifests/** — Site manifests and entry points
- **site-modules/** — Custom roles and profiles
  - **role/** — High-level roles (k8s_worker, database_server, etc.)
  - **profile/** — Low-level profiles (linux_base, k8s_worker, etc.)
- **data/** — Hiera node data and configuration
- **Puppetfile** — r10k module dependencies
- **hiera.yaml** — Hiera configuration

## Deploy

```bash
r10k deploy environment --config /etc/puppetlabs/puppet/r10k_code.yaml
r10k deploy module --config /etc/puppetlabs/puppet/r10k_code.yaml
```

## Update modules

Edit `Puppetfile` and run:
```bash
r10k puppetfile install --config /etc/puppetlabs/puppet/r10k_code.yaml
```

## Kubernetes

Puppet server runs in the `puppet` namespace. Nodes pull configuration from the Puppet server endpoint.

Node classification and roles are defined in `data/roles/` via Hiera.
