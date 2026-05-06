#!/usr/bin/env python3
"""homelab-infra setup wizard — personalises the repo and encrypts all secrets."""

import argparse
import getpass
import json
import os
import re
import secrets
import subprocess
import sys
from pathlib import Path

# ── colours ──────────────────────────────────────────────────────────────────

GREEN  = "\033[0;32m"
CYAN   = "\033[0;36m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"
NC     = "\033[0m"

BANNER = r"""
 _                          _       _           _        __
| |__   ___  _ __ ___   ___| | __ _| |__       (_)_ __  / _|_ __ __ _
| '_ \ / _ \| '_ ` _ \ / _ \ |/ _` | '_ \      | | '_ \| |_| '__/ _` |
| | | | (_) | | | | | |  __/ | (_| | |_) |     | | | | |  _| | | (_| |
|_| |_|\___/|_| |_| |_|\___|_|\__,_|_.__/      |_|_| |_|_| |_|  \__,_|
"""

# ── config file loading ───────────────────────────────────────────────────────

def load_config(path: Path) -> dict:
    """Parse a secrets.env KEY=VALUE file, ignoring blank lines and comments."""
    cfg = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, val = line.partition("=")
        cfg[key.strip()] = val.strip()
    return cfg


def cfg_ask(cfg: dict, key: str, prompt: str, default: str = "") -> str:
    if key in cfg and cfg[key]:
        return cfg[key]
    return ask(prompt, default)


def cfg_ask_secret(cfg: dict, key: str, prompt: str, generated: str = "") -> str:
    if key in cfg and cfg[key]:
        return cfg[key]
    return ask_secret(prompt, generated)


# ── prereqs ───────────────────────────────────────────────────────────────────

def check_prereqs():
    missing = [cmd for cmd in ("sops", "gpg", "openssl")
               if subprocess.run(["which", cmd], capture_output=True).returncode != 0]
    if missing:
        print(f"{RED}ERROR: missing tools: {', '.join(missing)}.  Install them first.{NC}")
        sys.exit(1)

# ── prompt helpers ────────────────────────────────────────────────────────────

def ask(prompt: str, default: str = "") -> str:
    display = f" {CYAN}[{default}]{NC}" if default else ""
    val = input(f"{YELLOW}?{NC} {prompt}{display}: ").strip()
    return val or default

def ask_secret(prompt: str, generated: str = "") -> str:
    hint = " (Enter to generate)" if generated else ""
    val = getpass.getpass(f"{YELLOW}?{NC} {prompt}{hint} {CYAN}(hidden){NC}: ")
    if not val:
        if generated:
            val = generated
            print(f"  {GREEN}↳ generated{NC}")
        # empty and no generated = user left it blank intentionally
    return val

def ask_section(title: str):
    print(f"\n{CYAN}=== {title} ==={NC}")

# ── file operations ───────────────────────────────────────────────────────────

REPLACE_EXTENSIONS = {
    ".yaml", ".yml", ".sh", ".md", ".conf", ".toml", ".groovy", ".pp",
}

SCRIPT_NAME = Path(__file__).name

def _is_encrypted(path: Path) -> bool:
    try:
        return "ENC[" in path.read_text(errors="replace")
    except OSError:
        return False

def replace_in_files(old: str, new: str, root: Path = Path(".")):
    if not old or old == new:
        return
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in REPLACE_EXTENSIONS and path.name not in ("Puppetfile",):
            continue
        if path.name in (SCRIPT_NAME, "setup-validation.sh", "setup.sh"):
            continue
        if _is_encrypted(path):
            continue
        try:
            text = path.read_text()
            if old in text:
                path.write_text(text.replace(old, new))
        except OSError:
            pass

def strip_node_pin(name: str, root: Path = Path(".")):
    """Remove nodeSelector / matchExpression lines referencing a placeholder hostname."""
    for path in root.rglob("*.yaml"):
        if not path.is_file() or _is_encrypted(path):
            continue
        try:
            lines = path.read_text().splitlines(keepends=True)
            filtered = [
                l for l in lines
                if not (f"kubernetes.io/hostname: {name}" in l or
                        re.match(rf"^\s*- {re.escape(name)}\s*$", l))
            ]
            if len(filtered) != len(lines):
                path.write_text("".join(filtered))
        except OSError:
            pass

def write_and_encrypt(rel_path: str, content: str, gpg_key: str):
    path = Path(rel_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    result = subprocess.run(
        ["sops", "--encrypt", "--in-place", "--pgp", gpg_key, str(path)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"{RED}  ✗ {rel_path}{NC}")
        print(f"    {result.stderr.strip()}")
    else:
        print(f"  {GREEN}✓{NC} {rel_path}")

# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="homelab-infra setup wizard")
    parser.add_argument("--config", metavar="FILE",
                        help="Path to a secrets.env config file (see secrets.example)")
    args = parser.parse_args()

    cfg: dict = {}
    if args.config:
        cfg_path = Path(args.config)
        if not cfg_path.exists():
            print(f"{RED}ERROR: config file not found: {cfg_path}{NC}")
            sys.exit(1)
        cfg = load_config(cfg_path)
        print(f"{GREEN}Loaded config from {cfg_path}{NC}")

    root = Path(__file__).parent.resolve()
    os.chdir(root)

    print(f"{CYAN}{BANNER}{NC}")
    print(f"{GREEN}homelab-infra setup wizard{NC}")
    print("Personalises this repo for your environment and encrypts all secrets.")

    check_prereqs()

    # ── cluster identity ──────────────────────────────────────────────────────
    ask_section("Cluster identity")
    owner       = cfg_ask(cfg, "OWNER_NAME",    "Your name (used in Puppet, labels)", "homelab")
    domain      = cfg_ask(cfg, "DOMAIN",        "Your domain (e.g. example.com)", "homelab.local")
    github_user = cfg_ask(cfg, "GITHUB_USER",   "Your GitHub username (for ArgoCD repoURL)", "YOUR_GITHUB_USERNAME")
    github_repo = cfg_ask(cfg, "GITHUB_REPO",   "Your repo name on GitHub", "homelab-infra")
    cp_ip       = cfg_ask(cfg, "CP_IP",         "K8s control-plane IP", "10.0.0.10")
    cp_host     = cfg_ask(cfg, "CP_HOST",       "Control-plane node hostname", "control-plane")
    gateway_ip  = cfg_ask(cfg, "GATEWAY_IP",    "Router / gateway IP (for BGP peering in pool.yaml)", "10.0.0.1")
    lb_start    = cfg_ask(cfg, "LB_START",      "Load-balancer IP range start", "10.0.0.200")
    registry    = cfg_ask(cfg, "REGISTRY_HOST", "Container registry hostname", "registry.example.com")

    # ── worker nodes ──────────────────────────────────────────────────────────
    ask_section("Worker nodes")
    print("Cluster requires minimum 4 worker nodes (1 control-plane + 4 workers = 5 total).")
    print("Enter worker hostnames, or press Enter to skip pinning and let Kubernetes schedule freely.\n")
    worker1 = cfg_ask(cfg, "WORKER_1", "Worker-1 hostname (or skip)")
    worker2 = cfg_ask(cfg, "WORKER_2", "Worker-2 hostname (or skip)")
    worker3 = cfg_ask(cfg, "WORKER_3", "Worker-3 hostname (or skip)")
    worker4 = cfg_ask(cfg, "WORKER_4", "Worker-4 hostname (or skip)")

    # ── node specialisation ───────────────────────────────────────────────────
    ask_section("Node specialization (optional)")
    print("Pin workloads to specific node types.  Leave blank to let Kubernetes schedule anywhere.\n")
    gpu_node     = cfg_ask(cfg, "GPU_NODE",     "GPU node hostname (LLM, Whisper, Piper)")
    storage_node = cfg_ask(cfg, "STORAGE_NODE", "Storage node hostname (Puppet, Foreman, PhotoPrism, Home Assistant)")
    nfs_node     = cfg_ask(cfg, "NFS_NODE",     "NFS server hostname (if running on-cluster)")

    # ── NFS / storage ─────────────────────────────────────────────────────────
    ask_section("NFS / Storage")
    print("This repo references two NFS server addresses for different PVCs.")
    print("Only 1 NFS server is required — enter the same hostname for both if needed!\n")
    nfs1       = cfg_ask(cfg, "NFS_SERVER",   "Primary NFS server hostname",                           "nfs.example.com")
    nfs2       = cfg_ask(cfg, "NFS_SERVER_2", "Secondary NFS server hostname (can be same as Primary)", "nfs2.example.com")
    nfs_base   = cfg_ask(cfg, "NFS_BASE",     "Primary NFS base path (your data share)",               "/nfs/data")
    nfs_kube   = cfg_ask(cfg, "NFS_KUBE",     "Secondary NFS base path (your kube share)",             "/nfs/kube")
    music_path = cfg_ask(cfg, "MUSIC_HOST_PATH", "Host path for music-assistant data (local node path)", "/opt/data/music-assistant")

    # ── GPG key ───────────────────────────────────────────────────────────────
    ask_section("GPG key for SOPS")
    if "GPG_KEY_ID" not in cfg or not cfg["GPG_KEY_ID"]:
        print("Available keys:")
        subprocess.run(["gpg", "--list-secret-keys", "--keyid-format", "LONG"],
                       capture_output=False)
    gpg_key = cfg_ask(cfg, "GPG_KEY_ID", "GPG key ID").strip()
    if not gpg_key:
        print(f"{RED}ERROR: GPG key ID is required.{NC}")
        sys.exit(1)

    # ── secrets ───────────────────────────────────────────────────────────────
    ask_section("Secrets")
    print("Press Enter on any secret to auto-generate a random value.\n")
    registry_pass   = cfg_ask_secret(cfg, "REGISTRY_PASS",  f"Registry password (for user '{owner}')", secrets.token_urlsafe(12))
    pg_pass         = cfg_ask_secret(cfg, "PG_PASS",        "PostgreSQL password",                      secrets.token_urlsafe(12))
    keycloak_pass   = cfg_ask_secret(cfg, "KEYCLOAK_PASS",  "Keycloak admin password",                  secrets.token_urlsafe(12))
    grafana_pass    = cfg_ask_secret(cfg, "GRAFANA_PASS",   "Grafana admin password",                   secrets.token_urlsafe(12))
    jenkins_pass    = cfg_ask_secret(cfg, "JENKINS_PASS",   "Jenkins admin password",                   secrets.token_urlsafe(12))
    argocd_pass     = cfg_ask_secret(cfg, "ARGOCD_PASS",    "ArgoCD admin password",                    secrets.token_urlsafe(12))
    foreman_pass    = cfg_ask_secret(cfg, "FOREMAN_PASS",   "Foreman admin password",                   secrets.token_urlsafe(12))
    foreman_enc_key = secrets.token_hex(16)
    foreman_secret  = secrets.token_urlsafe(24)
    print(f"  {GREEN}↳ Foreman encryption key and secret token auto-generated{NC}")
    nextcloud_pass  = cfg_ask_secret(cfg, "NEXTCLOUD_PASS", "Nextcloud admin password",                 secrets.token_urlsafe(12))

    acme_email = cfg_ask(cfg,        "ACME_EMAIL", "ACME / Let's Encrypt email (for cert-manager)", "admin@example.com")
    cf_token   = cfg_ask_secret(cfg, "CF_TOKEN",   "Cloudflare API token (for cert-manager DNS challenge)")
    cf_email   = cfg_ask_secret(cfg, "CF_EMAIL",   "Cloudflare account email")
    smtp_pass  = cfg_ask_secret(cfg, "SMTP_PASS",  "Nextcloud SMTP password (or skip)")

    # ── networking ────────────────────────────────────────────────────────────
    ask_section("Networking")
    pihole_ip    = cfg_ask(cfg, "PIHOLE_LB_IP",  "Pi-hole load-balancer IP (a free IP from your LB pool)",    "10.0.0.201")
    nginx_lb_ip  = cfg_ask(cfg, "NGINX_LB_IP",   "Nginx/ingress load-balancer IP (trusted proxy for OpenClaw)", "10.0.0.202")
    dns1         = cfg_ask(cfg, "DNS_SERVER_1",   "DNS server 1 (for kubeadm CoreDNS config)",                "8.8.8.8")
    dns2         = cfg_ask(cfg, "DNS_SERVER_2",   "DNS server 2 (for kubeadm CoreDNS config)",                "8.8.4.4")
    windows_node = cfg_ask(cfg, "WINDOWS_NODE_IP", "Windows node IP (Prometheus windows-exporter target, or skip)")

    # ── additional credentials ────────────────────────────────────────────────
    ask_section("Additional credentials")
    github_pat          = cfg_ask_secret(cfg, "GITHUB_PAT",           "GitHub PAT (for Puppet r10k private modules, or skip)")
    tailscale_client_id = cfg_ask_secret(cfg, "TAILSCALE_CLIENT_ID",  "Tailscale OAuth client ID (or skip)")
    tailscale_secret    = cfg_ask_secret(cfg, "TAILSCALE_CLIENT_SECRET", "Tailscale OAuth client secret (or skip)")

    # ── Jenkins keystore ──────────────────────────────────────────────────────
    ask_section("Jenkins keystore (optional)")
    print("Required only if you use JNLP agent TLS.  Press Enter to leave as placeholder.")
    jenkins_keystore_b64  = cfg_ask(cfg,        "JENKINS_KEYSTORE_B64",  "Jenkins keystore base64 (or skip)", "REPLACE_WITH_KEYSTORE_BASE64")
    jenkins_keystore_pass = cfg_ask_secret(cfg, "JENKINS_KEYSTORE_PASS", "Jenkins keystore password (or skip)")

    # ── OpenClaw / WhatsApp ───────────────────────────────────────────────────
    ask_section("OpenClaw / WhatsApp (optional, press Enter to skip)")
    your_phone     = cfg_ask(cfg, "YOUR_PHONE",      "Your phone number with country code, no + (e.g. 447700900123)")
    whatsapp_group = cfg_ask(cfg, "WHATSAPP_GROUP_ID", "WhatsApp group ID (or skip)")

    # ── LLM / AI ─────────────────────────────────────────────────────────────
    ask_section("LLM / AI services (optional, press Enter to skip)")
    discord_token  = cfg_ask_secret(cfg, "DISCORD_TOKEN",  "Discord bot token")
    litellm_key    = cfg_ask_secret(cfg, "LITELLM_KEY",    "LiteLLM master key",  secrets.token_urlsafe(12))
    searxng_secret = cfg_ask_secret(cfg, "SEARXNG_SECRET", "Searxng secret key",  secrets.token_hex(32))

    # ── configure .sops.yaml ─────────────────────────────────────────────────
    print(f"\n{GREEN}Configuring SOPS...{NC}")
    sops_path = root / ".sops.yaml"
    if sops_path.exists():
        text = sops_path.read_text()
        sops_path.write_text(text.replace("REPLACE_WITH_GPG_KEY", gpg_key))
    print(f"  {GREEN}✓{NC} .sops.yaml")

    # ── apply text replacements ───────────────────────────────────────────────
    print(f"{GREEN}Applying replacements...{NC}")

    replace_in_files("homelab.local",    domain)
    replace_in_files("example.com",      domain)
    replace_in_files("REPLACE_WITH_YOUR_DOMAIN", domain)
    replace_in_files("OWNER_NAME",       owner)
    replace_in_files("192.168.1.10",     cp_ip)
    replace_in_files("192.168.1.1",      gateway_ip)
    replace_in_files("192.168.1.200",    lb_start)

    # NFS — replace named defaults first, then explicit placeholders
    replace_in_files("nfs2.homelab.local", nfs2)
    replace_in_files("nfs.homelab.local",  nfs1)
    replace_in_files("REPLACE_WITH_NFS_SERVER_2", nfs2)
    replace_in_files("REPLACE_WITH_NFS_SERVER",   nfs1)
    replace_in_files("/nfs/data", nfs_base)
    replace_in_files("/nfs/kube", nfs_kube)
    replace_in_files("/opt/data/music-assistant", music_path)

    # Registry
    replace_in_files(f"registry.{domain}",              registry)
    replace_in_files("registry.REPLACE_WITH_YOUR_DOMAIN", registry)

    # GitHub repo URLs
    replace_in_files("YOUR_GITHUB_USERNAME/homelab-infra",          f"{github_user}/{github_repo}")
    replace_in_files("YOUR_GITHUB_USERNAME/puppet-control-repo",    f"{github_user}/puppet-control-repo")
    replace_in_files("YOUR_GITHUB_USERNAME/jenkins-repo",           f"{github_user}/jenkins-repo")

    # Control plane
    replace_in_files("REPLACE_WITH_CONTROL_PLANE_IP",       cp_ip)
    replace_in_files("REPLACE_WITH_CONTROL_PLANE_HOSTNAME", cp_host)

    # DNS / networking
    replace_in_files("REPLACE_WITH_DNS_SERVER_1", dns1)
    replace_in_files("REPLACE_WITH_DNS_SERVER_2", dns2)
    replace_in_files("REPLACE_WITH_PIHOLE_LB_IP", pihole_ip)
    replace_in_files("REPLACE_WITH_NGINX_LB_IP",  nginx_lb_ip)
    if windows_node:
        replace_in_files("REPLACE_WITH_WINDOWS_NODE_IP", windows_node)

    # Passwords / tokens in plain config files
    replace_in_files("REPLACE_WITH_POSTGRES_PASSWORD",   pg_pass)
    replace_in_files("REPLACE_WITH_POSTGRES_USERNAME",   "postgres")
    replace_in_files("REPLACE_WITH_REDIS_PASSWORD",      pg_pass)
    replace_in_files("REPLACE_WITH_ADMIN_PASSWORD",      grafana_pass)
    replace_in_files("REPLACE_WITH_ENCRYPTION_KEY",      foreman_enc_key)
    replace_in_files("REPLACE_WITH_SECRET_TOKEN",        foreman_secret)
    replace_in_files("REPLACE_WITH_NEXTCLOUD_PASSWORD",  nextcloud_pass)
    replace_in_files("REPLACE_WITH_SMTP_PASSWORD",       smtp_pass or "REPLACE_WITH_SMTP_PASSWORD")
    replace_in_files("REPLACE_WITH_LITELLM_MASTER_KEY",  litellm_key)
    replace_in_files("REPLACE_WITH_LITELLM_UI_USERNAME", "admin")
    replace_in_files("REPLACE_WITH_LITELLM_UI_PASSWORD", litellm_key)
    replace_in_files("REPLACE_WITH_SEARXNG_SECRET_KEY",  searxng_secret)
    replace_in_files("REPLACE_WITH_GITHUB_PAT",          github_pat or "REPLACE_WITH_GITHUB_PAT")
    replace_in_files("REPLACE_WITH_TAILSCALE_CLIENT_ID",     tailscale_client_id or "REPLACE_WITH_TAILSCALE_CLIENT_ID")
    replace_in_files("REPLACE_WITH_TAILSCALE_CLIENT_SECRET", tailscale_secret    or "REPLACE_WITH_TAILSCALE_CLIENT_SECRET")
    replace_in_files("REPLACE_WITH_TEST_PASSWORD",        pg_pass)

    # Jenkins keystore
    if jenkins_keystore_b64 != "REPLACE_WITH_KEYSTORE_BASE64":
        replace_in_files("REPLACE_WITH_KEYSTORE_BASE64", jenkins_keystore_b64)
    replace_in_files("REPLACE_WITH_KEYSTORE_PASSWORD", jenkins_keystore_pass or "REPLACE_WITH_KEYSTORE_PASSWORD")

    # OpenClaw / WhatsApp
    replace_in_files("REPLACE_WITH_YOUR_PHONE",     your_phone    or "REPLACE_WITH_YOUR_PHONE")
    replace_in_files("REPLACE_WITH_WHATSAPP_GROUP_ID", whatsapp_group or "REPLACE_WITH_WHATSAPP_GROUP_ID")

    # ACME email
    replace_in_files("YOUR_EMAIL@example.com", acme_email)

    # Cloudflare (inadyn DDNS)
    replace_in_files("REPLACE_WITH_CLOUDFLARE_TOKEN", cf_token or "REPLACE_WITH_CLOUDFLARE_TOKEN")

    # Node pinning
    for placeholder, actual, label in [
        ("gpu-node",              gpu_node,     "gpu-node"),
        ("REPLACE_WITH_NODE_HOSTNAME", gpu_node, "REPLACE_WITH_NODE_HOSTNAME"),
        ("gpu-node-2",            storage_node, "gpu-node-2"),
        ("worker-node",           worker1,      "worker-node"),
        ("nfs-node",              nfs_node,     "nfs-node"),
    ]:
        if actual:
            replace_in_files(placeholder, actual)
        else:
            strip_node_pin(placeholder)
            print(f"  {YELLOW}↳ {label} pinning removed — workloads will schedule on any node{NC}")

    print(f"  {GREEN}✓{NC} domain, IPs, NFS, paths, owner, passwords")

    print(f"\n{YELLOW}↳ REPLACE_WITH_YOUR_CA_CERT left as-is — paste your CA cert PEM manually into:{NC}")
    print("    cluster/config/containerd.yaml")
    print("    cluster/infrastructure/certs/node-cert.yaml")
    if not cf_token:
        print(f"  {YELLOW}↳ REPLACE_WITH_CLOUDFLARE_TOKEN left as-is — fill in cert-manager issuer manually{NC}")
    if not github_pat:
        print(f"  {YELLOW}↳ REPLACE_WITH_GITHUB_PAT left as-is — fill in puppet-values.yaml manually{NC}")

    # ── write + encrypt secrets ───────────────────────────────────────────────
    print(f"\n{GREEN}Encrypting secrets...{NC}")

    write_and_encrypt("cluster/infrastructure/registry/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: registry-keys
  namespace: registry
stringData:
  htpasswd: "{owner}:{registry_pass}"
---
apiVersion: v1
kind: Secret
metadata:
  name: registry
  namespace: registry
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{json.dumps({"auths": {registry: {"username": owner, "password": registry_pass}}})}'
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/postgresql/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secrets
  namespace: database
stringData:
  postgresPassword: "{pg_pass}"
  replicationPassword: "{pg_pass}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/keycloak/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-secrets
  namespace: keycloak
stringData:
  adminPassword: "{keycloak_pass}"
  postgresPassword: "{pg_pass}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/grafana/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: grafana-secrets
  namespace: monitoring
stringData:
  adminPassword: "{grafana_pass}"
  adminUser: admin
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/jenkins/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-secrets
  namespace: jenkins
stringData:
  adminPassword: "{jenkins_pass}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/argocd/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: argocd
stringData:
  admin.password: "{argocd_pass}"
  server.secretkey: "{secrets.token_urlsafe(32)}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/foreman/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: foreman-secrets
  namespace: foreman
stringData:
  FOREMAN_ADMIN_PASSWORD: "{foreman_pass}"
  ENCRYPTION_KEY: "{foreman_enc_key}"
  SECRET_TOKEN: "{foreman_secret}"
  postgresPassword: "{pg_pass}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/certs/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
stringData:
  apikey: "{cf_token or 'REPLACE_ME'}"
  email: "{cf_email or f'admin@{domain}'}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/database/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: my-admin-user-password
  namespace: database
stringData:
  password: "{pg_pass}"
---
apiVersion: v1
kind: Secret
metadata:
  name: my-db-user-password
  namespace: database
stringData:
  password: "{pg_pass}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/nextcloud/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-secrets
  namespace: nextcloud
stringData:
  adminPassword: "{nextcloud_pass}"
  smtpPassword: "{smtp_pass or 'REPLACE_ME'}"
  postgresPassword: "{pg_pass}"
""", gpg_key)

    write_and_encrypt("cluster/infrastructure/llm/secrets.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: openclaw-secret
  namespace: llm
stringData:
  OPENCLAW_GATEWAY_TOKEN: "{litellm_key}"
  DISCORD_TOKEN: "{discord_token or 'REPLACE_ME'}"
---
apiVersion: v1
kind: Secret
metadata:
  name: litellm-db-secret
  namespace: llm
stringData:
  username: postgres
  password: "{pg_pass}"
  endpoint: postgresql.postgresql.svc.cluster.local
---
apiVersion: v1
kind: Secret
metadata:
  name: litellm-masterkey
  namespace: llm
stringData:
  masterkey: "{litellm_key}"
""", gpg_key)

    for ns in ("foreman", "loki-stack", "puppet"):
        write_and_encrypt(f"cluster/infrastructure/{ns}/registry-secret.yaml", f"""\
apiVersion: v1
kind: Secret
metadata:
  name: registry
  namespace: {ns}
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{json.dumps({"auths": {registry: {"username": owner, "password": registry_pass}}})}'
""", gpg_key)

    # ── done ──────────────────────────────────────────────────────────────────
    print(f"\n{GREEN}✓ Setup complete!{NC}\n")
    print("Next steps:")
    print(f"  1. Review:    git diff --stat")
    print(f"  2. Commit:    git add . && git commit -m 'feat: initial cluster setup for {domain}'")
    print(f"  3. Push:      git push")
    print(f"  4. Apply GPG: gpg --export-secret-keys --armor {gpg_key} | kubectl create secret generic sops-gpg -n argocd --from-file=sops.asc=/dev/stdin")
    print()
    print("Useful SOPS commands:")
    print("  View a secret:  sops --decrypt cluster/infrastructure/<app>/secrets.yaml")
    print("  Edit a secret:  sops cluster/infrastructure/<app>/secrets.yaml")


if __name__ == "__main__":
    main()
