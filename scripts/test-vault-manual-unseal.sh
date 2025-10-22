#!/usr/bin/env bash
# Test script to verify manual unseal workflow with instructions
# This script must be run from HOST machine (requires Docker access)

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
VAULT_ADDR="http://localhost:8200"
COMPOSE_FILE=".devcontainer/docker-compose.dev.yml"
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Manual Unseal Workflow with Instructions"
echo "═══════════════════════════════════════════════════════════"
echo ""
log_warning "⚠️  This test must be run from HOST machine (not inside DevContainer)"
log_warning "⚠️  Requires Docker access and will restart Vault container"
echo ""

# Check if running inside DevContainer
if [[ -f "/.dockerenv" ]] || [[ -n "${REMOTE_CONTAINERS:-}" ]]; then
    log_error "This script must be run from HOST machine, not inside DevContainer"
    log_info "Run this from your host terminal in the project directory"
    exit 1
fi

# Test 1: Check vault-mode.conf exists
log_info "Test 1: Checking Vault configuration..."

if [[ ! -f ".devcontainer/data/vault-mode.conf" ]]; then
    log_error "✗ vault-mode.conf not found"
    log_info "Run vault setup wizard first: .devcontainer/scripts/setup/vault-setup-wizard.sh"
    ((TEST_FAILED++))
    exit 1
fi

source .devcontainer/data/vault-mode.conf

if [[ "${VAULT_MODE:-}" != "persistent" ]]; then
    log_error "✗ Vault mode is not 'persistent' (found: ${VAULT_MODE:-not set})"
    log_info "This test requires persistent mode"
    ((TEST_FAILED++))
    exit 1
fi

log_success "✓ Vault is in persistent mode"
((TEST_PASSED++))

# Test 2: Disable auto-unseal for testing
log_info "Test 2: Ensuring auto-unseal is disabled..."

if [[ "${AUTO_UNSEAL:-false}" == "true" ]]; then
    log_warning "Auto-unseal is enabled. Disabling for this test..."
    
    # Backup original config
    cp .devcontainer/data/vault-mode.conf .devcontainer/data/vault-mode.conf.backup
    
    # Update AUTO_UNSEAL
    sed -i 's/^AUTO_UNSEAL=.*/AUTO_UNSEAL="false"/' .devcontainer/data/vault-mode.conf
    
    log_success "✓ Auto-unseal disabled for testing"
    RESTORE_CONFIG=true
else
    log_success "✓ Auto-unseal already disabled"
    RESTORE_CONFIG=false
fi
((TEST_PASSED++))

# Test 3: Check unseal keys file exists
log_info "Test 3: Checking unseal keys file..."

if [[ ! -f ".devcontainer/data/vault-unseal-keys.json" ]]; then
    log_error "✗ Unseal keys file not found"
    log_info "Initialize Vault first: .devcontainer/scripts/vault-init.sh"
    ((TEST_FAILED++))
    exit 1
fi

# Verify file has proper permissions
FILE_PERMS=$(stat -c "%a" .devcontainer/data/vault-unseal-keys.json 2>/dev/null || stat -f "%A" .devcontainer/data/vault-unseal-keys.json 2>/dev/null)

if [[ "$FILE_PERMS" == "600" ]]; then
    log_success "✓ Unseal keys file has secure permissions (600)"
else
    log_warning "⚠ Unseal keys file permissions: $FILE_PERMS (should be 600)"
fi
((TEST_PASSED++))

# Test 4: Restart Vault container (will start sealed)
log_info "Test 4: Restarting Vault container..."

if ! docker-compose -f "$COMPOSE_FILE" restart vault-dev > /dev/null 2>&1; then
    log_error "✗ Failed to restart Vault container"
    ((TEST_FAILED++))
    exit 1
fi

log_success "✓ Vault container restarted"
((TEST_PASSED++))

# Wait for Vault to start
log_info "Waiting for Vault to start (10 seconds)..."
sleep 10

# Test 5: Verify Vault is sealed
log_info "Test 5: Verifying Vault starts sealed..."

SEAL_STATUS=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed' 2>/dev/null || echo "error")

if [[ "$SEAL_STATUS" == "true" ]]; then
    log_success "✓ Vault is sealed (as expected with AUTO_UNSEAL=false)"
    ((TEST_PASSED++))
elif [[ "$SEAL_STATUS" == "false" ]]; then
    log_error "✗ Vault is unsealed (should be sealed)"
    log_info "Check if AUTO_UNSEAL setting was applied"
    ((TEST_FAILED++))
else
    log_error "✗ Failed to query Vault seal status"
    ((TEST_FAILED++))
fi

# Test 6: Verify secret access is blocked
log_info "Test 6: Verifying secrets are inaccessible while sealed..."

ROOT_TOKEN=$(jq -r '.root_token' .devcontainer/data/vault-unseal-keys.json 2>/dev/null || echo "root")
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Vault-Token: $ROOT_TOKEN" \
    "$VAULT_ADDR/v1/secret/data/test" 2>/dev/null || echo "000")

if [[ "$HTTP_STATUS" == "503" ]] || [[ "$HTTP_STATUS" == "400" ]] || [[ "$HTTP_STATUS" == "500" ]]; then
    log_success "✓ Sealed Vault correctly blocks secret access (HTTP $HTTP_STATUS)"
    ((TEST_PASSED++))
else
    log_error "✗ Unexpected HTTP status: $HTTP_STATUS"
    ((TEST_FAILED++))
fi

# Test 7: Manual unseal using vault CLI (if available)
log_info "Test 7: Testing manual unseal process..."

if ! command -v vault &> /dev/null; then
    log_warning "⚠ Vault CLI not available on host, skipping CLI unseal test"
    log_info "Using HTTP API instead..."
    
    # Manual unseal via HTTP API
    UNSEAL_KEYS=($(jq -r '.keys_base64[]' .devcontainer/data/vault-unseal-keys.json | head -n 3))
    
    for i in "${!UNSEAL_KEYS[@]}"; do
        KEY="${UNSEAL_KEYS[$i]}"
        log_info "Unsealing with key $((i+1))/3..."
        
        RESPONSE=$(curl -s -X PUT -d "{\"key\":\"$KEY\"}" "$VAULT_ADDR/v1/sys/unseal")
        SEALED=$(echo "$RESPONSE" | jq -r '.sealed')
        PROGRESS=$(echo "$RESPONSE" | jq -r '.progress')
        THRESHOLD=$(echo "$RESPONSE" | jq -r '.t')
        
        log_info "Progress: $PROGRESS/$THRESHOLD"
        
        if [[ "$SEALED" == "false" ]]; then
            log_success "✓ Vault unsealed after $((i+1)) keys"
            break
        fi
    done
else
    log_info "Vault CLI available, using CLI for unseal..."
    
    export VAULT_ADDR="$VAULT_ADDR"
    
    # Get unseal keys
    UNSEAL_KEYS=($(jq -r '.keys_base64[]' .devcontainer/data/vault-unseal-keys.json | head -n 3))
    
    # Unseal with CLI
    for i in "${!UNSEAL_KEYS[@]}"; do
        KEY="${UNSEAL_KEYS[$i]}"
        log_info "Unsealing with key $((i+1))/3..."
        
        if vault operator unseal "$KEY" > /dev/null 2>&1; then
            log_info "Key $((i+1)) accepted"
        else
            log_error "✗ Failed to unseal with key $((i+1))"
            ((TEST_FAILED++))
            break
        fi
    done
fi

# Verify unsealed
FINAL_SEAL_STATUS=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed' 2>/dev/null || echo "error")

if [[ "$FINAL_SEAL_STATUS" == "false" ]]; then
    log_success "✓ Vault successfully unsealed manually"
    ((TEST_PASSED++))
else
    log_error "✗ Vault still sealed after unseal attempts"
    ((TEST_FAILED++))
fi

# Test 8: Verify secrets are accessible after unseal
log_info "Test 8: Verifying secrets are accessible after unseal..."

TEST_SECRET="test-manual-unseal-$(date +%s)"
WRITE_RESPONSE=$(curl -s -X POST \
    -H "X-Vault-Token: $ROOT_TOKEN" \
    -d "{\"data\": {\"value\": \"manual-unseal-test\"}}" \
    "$VAULT_ADDR/v1/secret/data/$TEST_SECRET" 2>/dev/null || echo "{}")

if echo "$WRITE_RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    log_success "✓ Successfully wrote secret (Vault is operational)"
    ((TEST_PASSED++))
    
    # Clean up test secret
    curl -s -X DELETE -H "X-Vault-Token: $ROOT_TOKEN" \
        "$VAULT_ADDR/v1/secret/metadata/$TEST_SECRET" > /dev/null 2>&1
else
    log_error "✗ Failed to write secret after unseal"
    log_error "Response: $WRITE_RESPONSE"
    ((TEST_FAILED++))
fi

# Restore original configuration if we changed it
if [[ "$RESTORE_CONFIG" == "true" ]]; then
    log_info "Restoring original vault-mode.conf..."
    mv .devcontainer/data/vault-mode.conf.backup .devcontainer/data/vault-mode.conf
    log_success "✓ Configuration restored"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
log_info "Test Summary:"
echo "═══════════════════════════════════════════════════════════"
log_success "Passed: $TEST_PASSED"
if [[ $TEST_FAILED -gt 0 ]]; then
    log_error "Failed: $TEST_FAILED"
else
    log_info "Failed: $TEST_FAILED"
fi
echo ""

if [[ $TEST_FAILED -eq 0 ]]; then
    log_success "✅ All tests passed! Manual unseal workflow works correctly."
    echo ""
    log_info "Manual unseal workflow verified:"
    echo "  1. ✓ Vault starts sealed when AUTO_UNSEAL=false"
    echo "  2. ✓ Secrets are inaccessible while sealed"
    echo "  3. ✓ Manual unseal process works (3 keys required)"
    echo "  4. ✓ Vault becomes operational after unsealing"
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
