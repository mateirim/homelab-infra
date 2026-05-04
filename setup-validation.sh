#!/usr/bin/env bash
set -euo pipefail

# setup-validation.sh — Post-setup validation for homelab-infra
# Run this after ./setup.sh to verify configuration is correct

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

# ── helpers ──────────────────────────────────────────────────────────────────

pass() {
  echo -e "${GREEN}✓${NC} $1"
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARNINGS++))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  ((ERRORS++))
}

# ── checks ───────────────────────────────────────────────────────────────────

echo -e "${YELLOW}=== homelab-infra Setup Validation ===${NC}\n"

# 1. Check for unfilled placeholders (both REPLACE_WITH_ and REPLACE_ME variants)
echo -e "${YELLOW}Checking for unfilled placeholders...${NC}"
UNFILLED=$(grep -rE "REPLACE_WITH_|REPLACE_ME\b" --include="*.yaml" --include="*.yml" \
  --include="*.sh" --include="*.groovy" cluster/ jenkins-repo/ puppet-control-repo/ \
  helm-charts/ 2>/dev/null | grep -v "node.kubernetes.io/hostname" | wc -l)

if [[ $UNFILLED -gt 0 ]]; then
  fail "Found $UNFILLED unfilled placeholders (REPLACE_WITH_* or REPLACE_ME)"
  grep -rE "REPLACE_WITH_|REPLACE_ME\b" --include="*.yaml" --include="*.yml" \
    --include="*.sh" --include="*.groovy" cluster/ jenkins-repo/ puppet-control-repo/ \
    helm-charts/ 2>/dev/null | grep -v "node.kubernetes.io/hostname" | head -5
  echo "  (showing first 5)"
else
  pass "All placeholders filled (no REPLACE_WITH_* or REPLACE_ME found)"
fi

# 2. Check GPG key is configured
echo -e "\n${YELLOW}Checking SOPS GPG configuration...${NC}"
GPG_KEY=$(grep "pgp:" .sops.yaml | head -1 | awk '{print $NF}')

if [[ "$GPG_KEY" == "F81E8088C755BB28" ]]; then
  warn "SOPS still using template GPG key ID (F81E8088C755BB28)"
  warn "  Run: gpg --list-secret-keys --keyid-format LONG"
  warn "  Then update .sops.yaml with your actual key ID"
else
  pass "SOPS configured with GPG key: $GPG_KEY"

  if gpg --list-keys "$GPG_KEY" &>/dev/null; then
    pass "GPG key is installed and accessible"
  else
    warn "GPG key $GPG_KEY not found in local keyring"
    warn "  Run: gpg --import <key-backup> or ask team to export their public key"
  fi
fi

# 3. Check SOPS can encrypt/decrypt
echo -e "\n${YELLOW}Testing SOPS encryption...${NC}"
TEST_FILE="/tmp/sops-test-$RANDOM.yaml"
echo "test: value" > "$TEST_FILE"

if sops --encrypt --in-place --pgp "$GPG_KEY" "$TEST_FILE" 2>/dev/null; then
  pass "SOPS encryption works"

  if sops --decrypt "$TEST_FILE" &>/dev/null; then
    pass "SOPS decryption works"
    rm -f "$TEST_FILE"
  else
    fail "SOPS decryption failed"
    rm -f "$TEST_FILE"
  fi
else
  fail "SOPS encryption failed (GPG key not accessible?)"
  rm -f "$TEST_FILE"
fi

# 4. Check ArgoCD Applications are wired
echo -e "\n${YELLOW}Checking ArgoCD Applications...${NC}"
APPS_COUNT=$(grep -c "kind: Application" cluster/stages/*/service.yaml 2>/dev/null || echo "0")

if [[ $APPS_COUNT -gt 0 ]]; then
  pass "Found $APPS_COUNT ArgoCD Applications"
else
  fail "No ArgoCD Applications found in cluster/stages/"
fi

# Check for orphaned infrastructure directories
echo -e "\n${YELLOW}Checking infrastructure namespace coverage...${NC}"
INFRA_DIRS=$(find cluster/infrastructure -maxdepth 1 -type d ! -name "infrastructure" | sort)
MISSING_APPS=0

for dir in $INFRA_DIRS; do
  ns=$(basename "$dir")
  if ! grep -q "path: infrastructure/$ns" cluster/stages/*/service.yaml 2>/dev/null; then
    warn "Namespace '$ns' not wired to any ArgoCD Application"
    ((MISSING_APPS++))
  fi
done

if [[ $MISSING_APPS -eq 0 ]]; then
  pass "All infrastructure namespaces have ArgoCD Applications"
fi

# 5. Check for hardcoded infrastructure details
echo -e "\n${YELLOW}Checking for hardcoded infrastructure details...${NC}"
HARDCODED=$(grep -r "gpu-node\|control-plane\|worker-\|nfs\." \
  --include="*.yaml" --include="*.yml" \
  cluster/infrastructure prometheus-stack puppet-control-repo 2>/dev/null | \
  grep -v "\.comments\|affinity\|nodeAffinity" | wc -l)

if [[ $HARDCODED -gt 0 ]]; then
  warn "Found $HARDCODED hardcoded node references (may be intentional affinity rules)"
  grep -r "gpu-node\|control-plane\|worker-\|nfs\." \
    --include="*.yaml" --include="*.yml" \
    cluster/infrastructure 2>/dev/null | \
    grep -v "\.comments\|affinity\|nodeAffinity" | head -3
else
  pass "No hardcoded infrastructure details found"
fi

# 6. Check for plaintext secrets
echo -e "\n${YELLOW}Checking for plaintext secrets...${NC}"
PLAINTEXT_SECRETS=$(grep -r "password:\|token:\|key:" \
  --include="*secret*.yaml" --include="*secrets*.yaml" \
  cluster/ jenkins-repo/ puppet-control-repo/ helm-charts/ 2>/dev/null | \
  grep -v "ENC\[" | grep -v "REPLACE_WITH_" | grep -v "#" | wc -l)

if [[ $PLAINTEXT_SECRETS -gt 0 ]]; then
  fail "Found $PLAINTEXT_SECRETS plaintext secrets (not SOPS-encrypted)"
  grep -r "password:\|token:\|key:" \
    --include="*secret*.yaml" --include="*secrets*.yaml" \
    cluster/ jenkins-repo/ puppet-control-repo/ helm-charts/ 2>/dev/null | \
    grep -v "ENC\[" | grep -v "REPLACE_WITH_\|REPLACE_ME" | grep -v "#" | head -3
else
  pass "All secrets are SOPS-encrypted"
fi

# 7. Check Git prerequisites
echo -e "\n${YELLOW}Checking git setup...${NC}"
if git rev-parse --git-dir &>/dev/null; then
  pass "Git repository initialized"

  UNCOMMITTED=$(git status --porcelain | wc -l)
  if [[ $UNCOMMITTED -gt 0 ]]; then
    warn "Found $UNCOMMITTED uncommitted changes (run: git add . && git commit)"
  else
    pass "Working tree clean"
  fi
else
  fail "Not a git repository (run: git init)"
fi

# ── summary ──────────────────────────────────────────────────────────────────

echo -e "\n${YELLOW}=== Summary ===${NC}"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review cluster/stages/stage-1/service.yaml for CNI config"
  echo "  2. Run kubeadm init on control plane with config from cluster/config/"
  echo "  3. Install Cilium, NFS provisioner, ArgoCD"
  echo "  4. Push to GitHub: git push"
  echo "  5. Watch ArgoCD sync: https://argo.yourdomain.com"
  exit 0
elif [[ $ERRORS -eq 0 ]]; then
  echo -e "${YELLOW}⚠ $WARNINGS warnings (review above)${NC}"
  exit 0
else
  echo -e "${RED}✗ $ERRORS errors, $WARNINGS warnings${NC}"
  echo "Please fix the errors above before deploying."
  exit 1
fi
