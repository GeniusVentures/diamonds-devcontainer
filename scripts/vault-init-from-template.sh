#!/usr/bin/env bash
# vault-init-from-template.sh
# Initialize Vault from team template with seed secrets

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEMPLATE_DIR="${PROJECT_ROOT}/.devcontainer/data/vault-data.template"
SEED_FILE="${TEMPLATE_DIR}/seed-secrets.json"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

echo "═══════════════════════════════════════════════════════════"
log_info "Vault Template Initialization"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if template directory exists
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    log_error "Template directory not found: $TEMPLATE_DIR"
    log_info "The template system may not be set up yet."
    exit 1
fi

log_info "Template directory: $TEMPLATE_DIR"

# Check if seed file exists
if [[ ! -f "$SEED_FILE" ]]; then
    log_error "Seed secrets file not found: $SEED_FILE"
    log_info "Expected file: seed-secrets.json"
    exit 1
fi

log_success "Found seed-secrets.json"

# Validate JSON format
if ! jq empty "$SEED_FILE" 2>/dev/null; then
    log_error "Invalid JSON format in seed-secrets.json"
    log_info "Please check the file for syntax errors"
    exit 1
fi

log_success "Seed secrets JSON is valid"

# Check if Vault is accessible
if ! curl -s --max-time 5 "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
    log_error "Cannot connect to Vault at $VAULT_ADDR"
    log_info "Make sure Vault is running: docker compose ps vault-hashicorp"
    log_info "Start Vault if needed: docker compose up -d vault-hashicorp"
    exit 1
fi

log_success "Vault is accessible at $VAULT_ADDR"

# Check if Vault is unsealed
seal_status=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "error")

if [[ "$seal_status" == "true" ]]; then
    log_error "Vault is sealed. Please unseal it first."
    log_info "Unseal with: bash .devcontainer/scripts/vault-auto-unseal.sh"
    log_info "Or manually: vault operator unseal"
    exit 1
elif [[ "$seal_status" == "error" ]]; then
    log_warning "Cannot determine Vault seal status. Proceeding anyway..."
fi

# Check authentication
if [[ -z "${VAULT_TOKEN:-}" ]]; then
    log_warning "VAULT_TOKEN not set. Attempting to use default token..."
    
    # Try to use root token for dev mode
    if [[ -f "${PROJECT_ROOT}/.devcontainer/data/.vault-token" ]]; then
        export VAULT_TOKEN=$(cat "${PROJECT_ROOT}/.devcontainer/data/.vault-token")
        log_info "Using token from .vault-token file"
    elif vault status >/dev/null 2>&1; then
        log_info "Vault CLI is authenticated"
    else
        log_error "No authentication found. Please set VAULT_TOKEN or login with: vault login"
        exit 1
    fi
fi

# Count secrets in seed file
secret_count=$(jq -r 'to_entries | map(select(.key | startswith("_") | not)) | length' "$SEED_FILE" 2>/dev/null || echo "0")
log_info "Found $secret_count secrets to load"

if [[ $secret_count -eq 0 ]]; then
    log_warning "No secrets found in seed file (or only metadata fields)"
    exit 0
fi

# Ask for confirmation
echo ""
log_warning "This will write $secret_count placeholder secrets to Vault"
log_info "These are template placeholders - you'll need to replace them with actual values"
echo ""
read -p "Continue with template initialization? (y/N): " confirm
confirm=${confirm:-N}

if [[ "${confirm^^}" != "Y" ]]; then
    log_info "Template initialization cancelled"
    exit 0
fi

echo ""
log_info "Loading seed secrets from template..."
echo ""

# Load secrets from JSON
loaded_count=0
failed_count=0

while IFS= read -r entry; do
    path=$(echo "$entry" | jq -r '.path')
    data=$(echo "$entry" | jq -r '.data')
    
    # Skip metadata fields (starting with _)
    if [[ "$path" == _* ]]; then
        continue
    fi
    
    log_info "Writing: $path"
    
    # Extract just the value field for vault kv put
    value=$(echo "$data" | jq -r '.value')
    
    # Write to Vault using HTTP API
    response=$(curl -s -X POST \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -d "{\"data\":{\"value\":\"$value\"}}" \
        "$VAULT_ADDR/v1/secret/data/${path#secret/}" 2>/dev/null || echo "")
    
    if echo "$response" | grep -q '"errors"'; then
        log_error "  Failed to write $path"
        log_error "  Response: $response"
        failed_count=$((failed_count + 1))
    else
        log_success "  ✓ $path"
        loaded_count=$((loaded_count + 1))
    fi
done < <(jq -r 'to_entries | .[] | select(.key | startswith("_") | not) | {path: .key, data: .value}' "$SEED_FILE")

echo ""
echo "═══════════════════════════════════════════════════════════"
log_info "Template Initialization Summary"
echo "═══════════════════════════════════════════════════════════"
log_success "Secrets loaded: $loaded_count"
if [[ $failed_count -gt 0 ]]; then
    log_error "Secrets failed: $failed_count"
else
    log_info "Secrets failed: $failed_count"
fi
echo ""

if [[ $loaded_count -gt 0 ]]; then
    log_success "✅ Template secrets loaded successfully!"
    echo ""
    log_warning "⚠️  IMPORTANT: Replace placeholder values with actual secrets!"
    echo ""
    log_info "Update secrets with:"
    echo "  vault kv put secret/dev/DEFENDER_API_KEY value='YOUR_ACTUAL_KEY'"
    echo "  vault kv put secret/dev/ETHERSCAN_API_KEY value='YOUR_ACTUAL_KEY'"
    echo ""
    log_info "Or use the migration script:"
    echo "  bash .devcontainer/scripts/setup/migrate-secrets-to-vault.sh"
    echo ""
    log_info "Verify secrets:"
    echo "  vault kv list secret/dev"
    echo "  vault kv get secret/dev/DEFENDER_API_KEY"
    echo ""
else
    log_error "❌ No secrets were loaded"
    exit 1
fi

exit 0
