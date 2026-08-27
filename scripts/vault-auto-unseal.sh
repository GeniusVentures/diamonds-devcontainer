#!/usr/bin/env bash
# Vault Auto-Unseal Script
# Automatically unseals Vault using stored unseal keys (3 of 5)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
UNSEAL_KEYS_FILE="${VAULT_UNSEAL_KEYS_FILE:-${PROJECT_ROOT}/.devcontainer/data/vault-unseal-keys.json}"
VAULT_ADDR="${VAULT_ADDR:-http://vault-dev:8200}"

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Main auto-unseal function
main() {
    log_info "Starting Vault auto-unseal process..."
    
    # Check if unseal keys file exists
    if [[ ! -f "$UNSEAL_KEYS_FILE" ]]; then
        log_error "Unseal keys file not found: $UNSEAL_KEYS_FILE"
        log_info "Cannot auto-unseal. Please unseal manually:"
        log_info "  1. Export VAULT_ADDR: export VAULT_ADDR=$VAULT_ADDR"
        log_info "  2. Unseal with: vault operator unseal <key>"
        log_info "  3. Repeat 3 times with different keys"
        exit 1
    fi
    
    # Verify file permissions (should be 600 for security)
    local file_perms=$(stat -c "%a" "$UNSEAL_KEYS_FILE" 2>/dev/null || stat -f "%A" "$UNSEAL_KEYS_FILE" 2>/dev/null)
    if [[ "$file_perms" != "600" ]]; then
        log_warning "⚠️  Unseal keys file has insecure permissions: $file_perms"
        log_warning "⚠️  Recommended: chmod 600 $UNSEAL_KEYS_FILE"
    fi
    
    # Check if Vault is reachable
    if ! curl -s --connect-timeout 5 "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
        log_error "Cannot connect to Vault at $VAULT_ADDR"
        log_info "Ensure Vault container is running: docker ps | grep vault"
        exit 1
    fi
    
    # Check if Vault is already unsealed
    local seal_status=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed' 2>/dev/null || echo "error")
    
    if [[ "$seal_status" == "false" ]]; then
        log_success "✅ Vault is already unsealed"
        exit 0
    elif [[ "$seal_status" == "error" ]]; then
        log_error "Failed to query Vault seal status"
        log_info "Check if jq is installed: which jq"
        exit 1
    fi
    
    log_info "Vault is sealed. Beginning unseal process..."
    
    # Extract unseal keys (use first 3 of 5 keys - Shamir threshold)
    log_info "Reading unseal keys from $UNSEAL_KEYS_FILE..."
    
    local unseal_keys
    mapfile -t unseal_keys < <(jq -r '.keys_base64[]' "$UNSEAL_KEYS_FILE" 2>/dev/null | head -n 3)
    
    if [[ ${#unseal_keys[@]} -lt 3 ]]; then
        log_error "Insufficient unseal keys found (need 3, have ${#unseal_keys[@]})"
        log_info "Unseal keys file may be corrupted or incomplete"
        log_info "Check file contents: cat $UNSEAL_KEYS_FILE | jq '.keys_base64[]'"
        exit 1
    fi
    
    log_info "Found ${#unseal_keys[@]} unseal keys (threshold: 3)"
    
    # Unseal Vault using HTTP API
    for i in "${!unseal_keys[@]}"; do
        local key="${unseal_keys[$i]}"
        log_info "Unsealing with key $((i+1))/3..."
        
        local response=$(curl -s -X PUT -d "{\"key\":\"$key\"}" "$VAULT_ADDR/v1/sys/unseal" 2>/dev/null)
        
        if [[ -z "$response" ]]; then
            log_error "No response from Vault unseal endpoint"
            exit 1
        fi
        
        local sealed=$(echo "$response" | jq -r '.sealed' 2>/dev/null || echo "error")
        local progress=$(echo "$response" | jq -r '.progress' 2>/dev/null || echo "?")
        local threshold=$(echo "$response" | jq -r '.t' 2>/dev/null || echo "?")
        
        if [[ "$sealed" == "error" ]]; then
            log_error "Failed to parse unseal response"
            log_error "Response: $response"
            exit 1
        fi
        
        log_info "Unseal progress: $progress/$threshold"
        
        if [[ "$sealed" == "false" ]]; then
            log_success "✅ Vault unsealed successfully!"
            log_info "Vault is now operational at $VAULT_ADDR"
            exit 0
        fi
    done
    
    log_error "Failed to unseal Vault after using 3 keys"
    log_info "This may indicate:"
    log_info "  - Incorrect unseal keys"
    log_info "  - Vault was re-initialized without updating keys file"
    log_info "  - Network connectivity issues"
    exit 1
}

# Run main function
main "$@"
