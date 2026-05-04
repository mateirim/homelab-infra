#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
 _                          _       _           _        __
| |__   ___  _ __ ___   ___| | __ _| |__       (_)_ __  / _|_ __ __ _
| '_ \ / _ \| '_ ` _ \ / _ \ |/ _` | '_ \      | | '_ \| |_| '__/ _` |
| | | | (_) | | | | | |  __/ | (_| | |_) |     | | | | |  _| | | (_| |
|_| |_|\___/|_| |_| |_|\___|_|\__,_|_.__/      |_|_| |_|_| |_|  \__,_|

EOF
echo -e "${NC}"
echo -e "${GREEN}homelab-infra setup wizard${NC}"
echo "Personalises this repo for your environment and encrypts all secrets."
echo ""

# ── prereq check ─────────────────────────────────────────────────────────────

for cmd in sops gpg openssl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}ERROR: '$cmd' not found. Install it first.${NC}"
    exit 1
  fi
done

# ── helpers ──────────────────────────────────────────────────────────────────

ask() {
  local prompt="$1" default="$2" var_name="$3"
  printf "${YELLOW}?${NC} %s ${CYAN}[%s]${NC}: " "$prompt" "$default"
  read -r input
  eval "${var_name}=\"\${input:-${default}}\""
}

ask_secret() {
  local prompt="$1" var_name="$2" generated="$3"
  printf "${YELLOW}?${NC} %s" "$prompt"
  if [[ -n "$generated" ]]; then
    printf " (Enter to generate)"
  fi
  printf " ${CYAN}(hidden)${NC}: "
  read -rs input
  echo ""
  if [[ -z "$input" && -n "$generated" ]]; then
    input="$generated"
    echo -e "  ${GREEN}↳ generated${NC}"
  fi
  eval "${var_name}=\"${input}\""
}

replace_in_files() {
  local old="$1" new="$2"
  # Only replace in non-SOPS-encrypted files
  grep -rl "$old" \
       --include="*.yaml" --include="*.yml" --include="*.sh" \
       --include="*.md" --include="*.conf" --include="*.toml" \
       --include="Puppetfile" --include="*.pp" --include="*.groovy" \
       . 2>/dev/null | while read -r f; do
    # Skip already-encrypted files
    grep -q "ENC\[" "$f" && continue
    sed -i "s|${old}|${new}|g" "$f"
  done
}

write_and_encrypt() {
  local file="$1" content="$2"
  echo "$content" > "$file"
  sops --encrypt --in-place --pgp "${GPG_KEY_ID}" "$file"
  echo -e "  ${GREEN}✓${NC} $file"
}

# ── gather info ───────────────────────────────────────────────────────────────

echo -e "${CYAN}=== Cluster identity ===${NC}"
ask "Your name (used in Puppet, labels)" "homelab" OWNER_NAME
ask "Your domain (e.g. example.com)" "homelab.local" DOMAIN
ask "Your GitHub username (for ArgoCD repoURL)" "YOUR_GITHUB_USERNAME" GITHUB_USER
ask "Your repo name on GitHub" "homelab-infra" GITHUB_REPO
ask "K8s control-plane IP" "192.168.1.10" CP_IP
ask "Control-plane node hostname" "control-plane" CP_HOSTNAME
ask "Router / gateway IP (for BGP peering in pool.yaml)" "192.168.1.1" GATEWAY_IP
ask "Load-balancer IP range start" "192.168.1.200" LB_START
ask "Container registry hostname" "registry.${DOMAIN}" REGISTRY_HOST

echo ""
echo -e "${CYAN}=== Worker nodes ===${NC}"
echo "Cluster requires minimum 4 worker nodes (1 control-plane + 4 workers = 5 nodes total)."
echo "Enter worker hostnames, or press Enter to skip pinning and let Kubernetes schedule freely."
echo ""
ask "Worker-1 hostname (or skip)" "" WORKER_1
ask "Worker-2 hostname (or skip)" "" WORKER_2
ask "Worker-3 hostname (or skip)" "" WORKER_3
ask "Worker-4 hostname (or skip)" "" WORKER_4

echo ""
echo -e "${CYAN}=== Node specialization (optional) ===${NC}"
echo "Pin workloads to specific node types (e.g. GPU node for LLM)."
echo "Leave blank to let Kubernetes schedule anywhere."
echo ""
ask "GPU node hostname (LLM, Whisper, Piper)" "" GPU_NODE
ask "Storage node hostname (Puppet, Foreman, PhotoPrism, Home Assistant)" "" STORAGE_NODE
ask "NFS server hostname (if running on-cluster)" "" NFS_NODE

echo ""
echo -e "${CYAN}=== NFS / Storage ===${NC}"
echo "This repository references two NFS server addresses for different PVCs."
echo "Only 1 NFS server is actually required. If you only have one, just enter the same hostname for both!"
ask "Primary NFS server hostname" "nfs.${DOMAIN}" NFS_SERVER
ask "Secondary NFS server hostname (Optional, can be same as Primary)" "nfs2.${DOMAIN}" NFS_SERVER_2
ask "Primary NFS base path (your data share)" "/nfs/data" NFS_BASE
ask "Secondary NFS base path (your kube share)" "/nfs/kube" NFS_KUBE_BASE
ask "Host path for music-assistant data (local node path)" "/opt/data/music-assistant" MUSIC_HOST_PATH

echo ""
echo -e "${CYAN}=== GPG key for SOPS ===${NC}"
echo "Available keys:"
gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep -E "sec|uid" || echo "  (none found)"
ask "GPG key ID" "" GPG_KEY_ID
if [[ -z "$GPG_KEY_ID" ]]; then
  echo -e "${RED}ERROR: GPG key ID is required.${NC}"
  exit 1
fi

echo ""
echo -e "${CYAN}=== Secrets ===${NC}"
echo "Press Enter on any secret to auto-generate a random value."
echo ""

ask_secret "Registry password (for user '${OWNER_NAME}')" REGISTRY_PASS "$(openssl rand -base64 16)"
ask_secret "PostgreSQL password" PG_PASS "$(openssl rand -base64 16)"
ask_secret "Keycloak admin password" KEYCLOAK_PASS "$(openssl rand -base64 16)"
ask_secret "Grafana admin password" GRAFANA_PASS "$(openssl rand -base64 16)"
ask_secret "Jenkins admin password" JENKINS_PASS "$(openssl rand -base64 16)"
ask_secret "ArgoCD admin password" ARGOCD_PASS "$(openssl rand -base64 16)"
ask_secret "Foreman admin password" FOREMAN_ADMIN_PASS "$(openssl rand -base64 16)"
FOREMAN_ENC_KEY=$(openssl rand -hex 16)
FOREMAN_SECRET_TOKEN=$(openssl rand -base64 32)
echo -e "  ${GREEN}↳ Foreman encryption key and secret token auto-generated${NC}"

ask "ACME / Let's Encrypt email (for cert-manager)" "admin@${DOMAIN}" ACME_EMAIL
ask_secret "Cloudflare API token (for cert-manager DNS challenge)" CF_TOKEN ""
ask_secret "Cloudflare account email" CF_EMAIL ""

echo ""
echo -e "${CYAN}=== LLM / AI services (optional, press Enter to skip) ===${NC}"
ask_secret "Discord bot token" DISCORD_TOKEN ""
ask_secret "LiteLLM master key" LITELLM_KEY "$(openssl rand -base64 16)"
ask_secret "Searxng secret key" SEARXNG_SECRET "$(python3 -c 'import secrets; print(secrets.token_hex(32))' 2>/dev/null || openssl rand -hex 32)"

# ── update .sops.yaml ────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}Configuring SOPS...${NC}"
sed -i "s|F81E8088C755BB28|${GPG_KEY_ID}|g" .sops.yaml
echo -e "  ${GREEN}✓${NC} .sops.yaml"

# ── apply domain / IP replacements ───────────────────────────────────────────

echo -e "${GREEN}Applying replacements...${NC}"

replace_in_files "homelab.local" "$DOMAIN"
replace_in_files "example.com" "$DOMAIN"
replace_in_files "REPLACE_WITH_YOUR_DOMAIN" "$DOMAIN"
replace_in_files "OWNER_NAME" "$OWNER_NAME"
replace_in_files "192.168.1.10" "$CP_IP"
replace_in_files "192.168.1.1" "$GATEWAY_IP"
replace_in_files "192.168.1.200" "$LB_START"

# NFS servers and paths
replace_in_files "nfs2.homelab.local" "$NFS_SERVER_2"
replace_in_files "nfs.homelab.local"  "$NFS_SERVER"
replace_in_files "REPLACE_WITH_NFS_SERVER" "$NFS_SERVER"
replace_in_files "REPLACE_WITH_NFS_SERVER_2" "$NFS_SERVER_2"
replace_in_files "/nfs/data"               "$NFS_BASE"
replace_in_files "/nfs/kube"               "$NFS_KUBE_BASE"
replace_in_files "/opt/data/music-assistant" "$MUSIC_HOST_PATH"

# Registry host (after domain replacement)
replace_in_files "registry.${DOMAIN}" "$REGISTRY_HOST"
replace_in_files "registry.REPLACE_WITH_YOUR_DOMAIN" "$REGISTRY_HOST"

# ArgoCD repo URL
replace_in_files "YOUR_GITHUB_USERNAME/homelab-infra" "${GITHUB_USER}/${GITHUB_REPO}"

# Puppet control repo URL
replace_in_files "YOUR_GITHUB_USERNAME/puppet-control-repo" "${GITHUB_USER}/puppet-control-repo"

# Jenkins repo URL
replace_in_files "YOUR_GITHUB_USERNAME/jenkins-repo" "${GITHUB_USER}/jenkins-repo"

# Node hostnames — control plane (always set)
replace_in_files "REPLACE_WITH_CONTROL_PLANE_HOSTNAME" "${CP_HOSTNAME}"

# Passwords and Tokens (replace in non-secrets files if present)
replace_in_files "REPLACE_WITH_POSTGRES_PASSWORD" "$PG_PASS"
replace_in_files "REPLACE_WITH_REDIS_PASSWORD" "$PG_PASS"
replace_in_files "REPLACE_WITH_ADMIN_PASSWORD" "$GRAFANA_PASS"
replace_in_files "REPLACE_WITH_LITELLM_MASTER_KEY" "$LITELLM_KEY"
replace_in_files "REPLACE_WITH_LITELLM_UI_USERNAME" "admin"
replace_in_files "REPLACE_WITH_LITELLM_UI_PASSWORD" "homelab"
replace_in_files "REPLACE_WITH_ENCRYPTION_KEY" "$FOREMAN_ENC_KEY"
replace_in_files "REPLACE_WITH_SECRET_TOKEN" "$FOREMAN_SECRET_TOKEN"

# Helper: remove all nodeAffinity/nodeSelector references to a placeholder hostname.
# Handles both formats:
#   nodeSelector:
#     kubernetes.io/hostname: <name>
#   matchExpressions:
#     - key: kubernetes.io/hostname
#       operator: In
#       values:
#         - <name>
strip_node_pin() {
  local name="$1"
  grep -rl "$name" --include="*.yaml" --include="*.yml" . 2>/dev/null | while read -r f; do
    grep -q "ENC\[" "$f" && continue
    # nodeSelector style: kubernetes.io/hostname: <name>
    sed -i "/kubernetes\.io\/hostname: ${name}/d" "$f" 2>/dev/null || true
    # matchExpression values list: "  - <name>" line directly under an In/NotIn block
    sed -i "/^[[:space:]]*- ${name}[[:space:]]*$/d" "$f" 2>/dev/null || true
  done
}

# GPU node — replace or strip
if [[ -n "$GPU_NODE" ]]; then
  replace_in_files "gpu-node" "${GPU_NODE}"
  replace_in_files "REPLACE_WITH_NODE_HOSTNAME" "${GPU_NODE}"
else
  strip_node_pin "gpu-node"
  strip_node_pin "REPLACE_WITH_NODE_HOSTNAME"
  echo -e "  ${YELLOW}↳ gpu-node pinning removed — workloads will schedule on any node${NC}"
fi

# Storage/GPU node
if [[ -n "$GPU_NODE_2" ]]; then
  replace_in_files "gpu-node-2" "${GPU_NODE_2}"
else
  strip_node_pin "gpu-node-2"
  echo -e "  ${YELLOW}↳ gpu-node-2 pinning removed — workloads will schedule on any node${NC}"
fi

# Worker node
if [[ -n "$WORKER_NODE" ]]; then
  replace_in_files "worker-node" "${WORKER_NODE}"
else
  strip_node_pin "worker-node"
  echo -e "  ${YELLOW}↳ worker-node pinning removed — workloads will schedule on any node${NC}"
fi

# NFS/OMV node
if [[ -n "$NFS_NODE" ]]; then
  replace_in_files "nfs-node" "${NFS_NODE}"
else
  strip_node_pin "nfs-node"
  echo -e "  ${YELLOW}↳ nfs-node pinning removed — NFS provisioner will schedule on any node${NC}"
fi

# ACME email for cert-manager
replace_in_files "YOUR_EMAIL@example.com" "${ACME_EMAIL}"

# inadyn DDNS — domain and Cloudflare token
replace_in_files "REPLACE_WITH_YOUR_DOMAIN" "${DOMAIN}"
replace_in_files "REPLACE_WITH_CLOUDFLARE_TOKEN" "${CF_TOKEN:-REPLACE_WITH_CLOUDFLARE_TOKEN}"

echo -e "  ${GREEN}✓${NC} domain, IPs, NFS servers, paths, owner name, passwords"

# ── write + encrypt all secrets ──────────────────────────────────────────────

echo -e "${GREEN}Encrypting secrets...${NC}"

write_and_encrypt "cluster/infrastructure/registry/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: registry-keys
  namespace: registry
stringData:
  htpasswd: \"${OWNER_NAME}:${REGISTRY_PASS}\"
---
apiVersion: v1
kind: Secret
metadata:
  name: registry
  namespace: registry
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{\"auths\":{\"${REGISTRY_HOST}\":{\"username\":\"${OWNER_NAME}\",\"password\":\"${REGISTRY_PASS}\"}}}'"

write_and_encrypt "cluster/infrastructure/postgresql/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secrets
  namespace: database
stringData:
  postgresPassword: \"${PG_PASS}\"
  replicationPassword: \"${PG_PASS}\""

write_and_encrypt "cluster/infrastructure/keycloak/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: keycloak-secrets
  namespace: keycloak
stringData:
  adminPassword: \"${KEYCLOAK_PASS}\"
  postgresPassword: \"${PG_PASS}\""

write_and_encrypt "cluster/infrastructure/grafana/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: grafana-secrets
  namespace: monitoring
stringData:
  adminPassword: \"${GRAFANA_PASS}\"
  adminUser: admin"

write_and_encrypt "cluster/infrastructure/jenkins/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: jenkins-secrets
  namespace: jenkins
stringData:
  adminPassword: \"${JENKINS_PASS}\""

write_and_encrypt "cluster/infrastructure/argocd/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: argocd
stringData:
  admin.password: \"${ARGOCD_PASS}\"
  admin.passwordMtime: \"$(date +%Y-%m-%dT%H:%M:%SZ)\"
  server.secretkey: \"$(openssl rand -base64 32)\""

write_and_encrypt "cluster/infrastructure/foreman/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: foreman-secrets
  namespace: foreman
stringData:
  FOREMAN_ADMIN_PASSWORD: \"${FOREMAN_ADMIN_PASS}\"
  ENCRYPTION_KEY: \"${FOREMAN_ENC_KEY}\"
  SECRET_TOKEN: \"${FOREMAN_SECRET_TOKEN}\"
  postgresPassword: \"${PG_PASS}\""

write_and_encrypt "cluster/infrastructure/certs/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
stringData:
  apikey: \"${CF_TOKEN:-REPLACE_ME}\"
  email: \"${CF_EMAIL:-admin@${DOMAIN}}\""

write_and_encrypt "cluster/infrastructure/database/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: my-admin-user-password
  namespace: database
stringData:
  password: \"${PG_PASS}\"
---
apiVersion: v1
kind: Secret
metadata:
  name: my-db-user-password
  namespace: database
stringData:
  password: \"${PG_PASS}\""

write_and_encrypt "cluster/infrastructure/llm/secrets.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: openclaw-secret
  namespace: llm
stringData:
  OPENCLAW_GATEWAY_TOKEN: \"${LITELLM_KEY}\"
  DISCORD_TOKEN: \"${DISCORD_TOKEN:-REPLACE_ME}\"
---
apiVersion: v1
kind: Secret
metadata:
  name: litellm-db-secret
  namespace: llm
stringData:
  username: postgres
  password: \"${PG_PASS}\"
  endpoint: postgresql.postgresql.svc.cluster.local
---
apiVersion: v1
kind: Secret
metadata:
  name: litellm-masterkey
  namespace: llm
stringData:
  masterkey: \"${LITELLM_KEY}\""

# Docker pull secrets for namespaces that need registry access
for ns in foreman loki-stack stream puppet direwolf; do
  write_and_encrypt "cluster/infrastructure/${ns}/registry-secret.yaml" \
"apiVersion: v1
kind: Secret
metadata:
  name: registry
  namespace: ${ns}
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{\"auths\":{\"${REGISTRY_HOST}\":{\"username\":\"${OWNER_NAME}\",\"password\":\"${REGISTRY_PASS}\"}}}'"
done

echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review:   git diff --stat"
echo "  2. Commit:   git add . && git commit -m 'feat: initial cluster setup for ${DOMAIN}'"
echo "  3. Push:     git push"
echo "  4. Apply GPG:  gpg --export-secret-keys --armor ${GPG_KEY_ID} | kubectl create secret generic sops-gpg -n argocd --from-file=sops.asc=/dev/stdin"
echo ""
echo "Useful SOPS commands:"
echo "  View a secret:  sops --decrypt cluster/infrastructure/<app>/secrets.yaml"
echo "  Edit a secret:  sops cluster/infrastructure/<app>/secrets.yaml"
