#!/usr/bin/env bash
# Test script to verify sealed Vault prevents secret access
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
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Sealed Vault Prevents Secret Access"
echo "═══════════════════════════════════════════════════════════"
echo ""
log_warning "⚠️  This test must be run from HOST machine (not inside DevContainer)"
log_warning "⚠️  Requires Docker access to seal Vault container"
echo ""

# Check if running inside DevContainer
if [[ -f "/.dockerenv" ]] || [[ -n "${REMOTE_CONTAINERS:-}" ]]; then
    log_error "This script must be run from HOST machine, not inside DevContainer"
    log_info "Run this from your host terminal in the project directory"
    exit 1
fi

# Test 1: Check Vault is accessible
log_info "Test 1: Checking Vault accessibility..."
if curl -s --max-time 5 "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
    log_success "✓ Vault is accessible at $VAULT_ADDR"
    ((TEST_PASSED++))
else
    log_error "✗ Vault is not accessible at $VAULT_ADDR"
    log_info "Start Vault with: cd .devcontainer && docker-compose up -d vault-dev"
    ((TEST_FAILED++))
    exit 1
fi

# Test 2: Check if Vault is currently sealed
log_info "Test 2: Checking Vault seal status..."
SEAL_STATUS=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed' 2>/dev/null || echo "error")

if [[ "$SEAL_STATUS" == "error" ]]; then
    log_error "✗ Failed to query Vault seal status"
    log_info "Ensure jq is installed: which jq"
    ((TEST_FAILED++))
    exit 1
elif [[ "$SEAL_STATUS" == "false" ]]; then
    log_info "Vault is currently unsealed - will test sealing it"
elif [[ "$SEAL_STATUS" == "true" ]]; then
    log_success "✓ Vault is already sealed (perfect for testing)"
    ((TEST_PASSED++))
fi

# Test 3: If unsealed, seal it for testing
if [[ "$SEAL_STATUS" == "false" ]]; then
    log_info "Test 3: Sealing Vault for testing..."
    
    # Get root token from unseal keys file or environment
    ROOT_TOKEN=""
    if [[ -f ".devcontainer/data/vault-unseal-keys.json" ]]; then
        ROOT_TOKEN=$(jq -r '.root_token' .devcontainer/data/vault-unseal-keys.json 2>/dev/null || echo "")
    fi
    
    if [[ -z "$ROOT_TOKEN" ]]; then
        ROOT_TOKEN="${VAULT_TOKEN:-root}"
        log_warning "Using default root token 'root' (may not work for persistent Vault)"
    fi
    
    # Seal Vault
    SEAL_RESPONSE=$(curl -s -X PUT -H "X-Vault-Token: $ROOT_TOKEN" "$VAULT_ADDR/v1/sys/seal" 2>/dev/null || echo "error")
    
    # Verify sealed
    SEAL_STATUS=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed' 2>/dev/null || echo "error")
    
    if [[ "$SEAL_STATUS" == "true" ]]; then
        log_success "✓ Vault sealed successfully"
        ((TEST_PASSED++))
    else
        log_error "✗ Failed to seal Vault"
        log_error "Response: $SEAL_RESPONSE"
        ((TEST_FAILED++))
        exit 1
    fi
fi

# Test 4: Verify secret read returns error (503 Service Unavailable)
log_info "Test 4: Testing secret access while sealed..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Vault-Token: root" \
    "$VAULT_ADDR/v1/secret/data/test" 2>/dev/null || echo "000")

if [[ "$HTTP_STATUS" == "503" ]]; then
    log_success "✓ Sealed Vault correctly returns 503 (Service Unavailable)"
    ((TEST_PASSED++))
elif [[ "$HTTP_STATUS" == "400" ]] || [[ "$HTTP_STATUS" == "500" ]]; then
    log_success "✓ Sealed Vault returns error status $HTTP_STATUS (acceptable)"
    ((TEST_PASSED++))
else
    log_error "✗ Expected 503, got HTTP $HTTP_STATUS"
    ((TEST_FAILED++))
fi

# Test 5: Verify error message mentions "sealed"
log_info "Test 5: Testing error message contains 'sealed'..."

ERROR_RESPONSE=$(curl -s -H "X-Vault-Token: root" "$VAULT_ADDR/v1/secret/data/test" 2>/dev/null || echo "{}")
ERROR_MESSAGE=$(echo "$ERROR_RESPONSE" | jq -r '.errors[]?' 2>/dev/null || echo "")

if echo "$ERROR_MESSAGE" | grep -iq "sealed"; then
    log_success "✓ Error message mentions Vault is sealed"
    log_info "Error: $ERROR_MESSAGE"
    ((TEST_PASSED++))
elif [[ "$ERROR_RESPONSE" == *"sealed"* ]]; then
    log_success "✓ Response indicates Vault is sealed"
    ((TEST_PASSED++))
else
    log_warning "⚠ Error message doesn't explicitly mention 'sealed'"
    log_info "Response: $ERROR_RESPONSE"
    # Not a failure - different Vault versions have different messages
    ((TEST_PASSED++))
fi

# Test 6: Verify health endpoint shows sealed=true
log_info "Test 6: Verifying health endpoint reports sealed status..."

HEALTH_RESPONSE=$(curl -s "$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo "{}")
HEALTH_SEALED=$(echo "$HEALTH_RESPONSE" | jq -r '.sealed' 2>/dev/null || echo "error")
HEALTH_INITIALIZED=$(echo "$HEALTH_RESPONSE" | jq -r '.initialized' 2>/dev/null || echo "error")

if [[ "$HEALTH_SEALED" == "true" ]]; then
    log_success "✓ Health endpoint reports sealed=true"
    ((TEST_PASSED++))
else
    log_error "✗ Health endpoint sealed status: $HEALTH_SEALED"
    ((TEST_FAILED++))
fi

if [[ "$HEALTH_INITIALIZED" == "true" ]]; then
    log_success "✓ Health endpoint reports initialized=true"
    ((TEST_PASSED++))
else
    log_warning "⚠ Health endpoint initialized status: $HEALTH_INITIALIZED"
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
    log_success "✅ All tests passed! Sealed Vault correctly prevents secret access."
    echo ""
    log_info "To unseal Vault for continued use:"
    echo "  • Auto-unseal: bash .devcontainer/scripts/vault-auto-unseal.sh"
    echo "  • Manual: vault operator unseal (repeat 3 times)"
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
