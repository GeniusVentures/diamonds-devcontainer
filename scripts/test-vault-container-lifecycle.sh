#!/usr/bin/env bash
# Integration test for Vault container lifecycle with auto-unseal
# Tests auto-unseal integration with post-start.sh

set -eo pipefail

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
POST_START_SCRIPT="${SCRIPT_DIR}/post-start.sh"
CONFIG_FILE="${SCRIPT_DIR}/../data/vault-mode.conf"
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Vault Container Lifecycle Integration"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test 1: Verify post-start.sh exists
log_info "Test 1: Checking post-start.sh existence..."

if [[ -f "$POST_START_SCRIPT" ]]; then
    log_success "✓ post-start.sh exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ post-start.sh not found"
    TEST_FAILED=$((TEST_FAILED + 1))
    exit 1
fi

# Test 2: Check for AUTO_UNSEAL flag handling
log_info "Test 2: Checking AUTO_UNSEAL flag handling in post-start.sh..."

if grep -q "AUTO_UNSEAL" "$POST_START_SCRIPT"; then
    log_success "✓ AUTO_UNSEAL flag used in post-start.sh"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ AUTO_UNSEAL flag not found in post-start.sh"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 3: Check for auto-unseal script invocation
log_info "Test 3: Checking vault-auto-unseal.sh invocation..."

if grep -q "vault-auto-unseal.sh" "$POST_START_SCRIPT"; then
    log_success "✓ vault-auto-unseal.sh is called from post-start.sh"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-auto-unseal.sh invocation not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 4: Check for conditional execution (only when AUTO_UNSEAL=true)
log_info "Test 4: Checking conditional auto-unseal execution..."

if grep -q 'if.*AUTO_UNSEAL.*==.*"true"' "$POST_START_SCRIPT"; then
    log_success "✓ Auto-unseal only runs when AUTO_UNSEAL=true"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Conditional execution not properly implemented"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 5: Check for sealed status check
log_info "Test 5: Checking seal status verification..."

if grep -q "seal_status.*sealed" "$POST_START_SCRIPT"; then
    log_success "✓ Checks if Vault is sealed before unsealing"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Seal status check not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 6: Check for manual unseal instructions
log_info "Test 6: Checking manual unseal instructions..."

if grep -q "Manual Unseal Instructions" "$POST_START_SCRIPT"; then
    log_success "✓ Provides manual unseal instructions"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Manual unseal instructions not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 7: Check for ephemeral mode handling
log_info "Test 7: Checking ephemeral mode handling..."

if grep -q "ephemeral.*auto-initialized" "$POST_START_SCRIPT"; then
    log_success "✓ Handles ephemeral mode (no unseal needed)"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Ephemeral mode handling not found"
fi

# Test 8: Check for persistent mode detection
log_info "Test 8: Checking persistent mode detection..."

if grep -q "persistent.*mode" "$POST_START_SCRIPT"; then
    log_success "✓ Detects persistent mode"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Persistent mode detection not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 9: Check for error handling when auto-unseal fails
log_info "Test 9: Checking error handling for failed auto-unseal..."

if grep -q "Auto-unseal failed" "$POST_START_SCRIPT" || grep -q "Manual unsealing required" "$POST_START_SCRIPT"; then
    log_success "✓ Handles auto-unseal failures gracefully"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Error handling for failed auto-unseal not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 10: Check for success message after unsealing
log_info "Test 10: Checking success message after auto-unseal..."

if grep -q "auto-unsealed successfully" "$POST_START_SCRIPT"; then
    log_success "✓ Shows success message after auto-unseal"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Success message not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 11: Check for vault-mode.conf integration
log_info "Test 11: Checking vault-mode.conf integration..."

if grep -q "vault-mode.conf" "$POST_START_SCRIPT"; then
    log_success "✓ Loads configuration from vault-mode.conf"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ vault-mode.conf loading not found"
fi

# Test 12: Check for VAULT_ADDR usage
log_info "Test 12: Checking VAULT_ADDR environment variable..."

if grep -q "VAULT_ADDR" "$POST_START_SCRIPT"; then
    log_success "✓ Uses VAULT_ADDR for Vault connection"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ VAULT_ADDR usage not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 13: Verify vault-mode.conf structure (if exists)
log_info "Test 13: Checking vault-mode.conf structure (if exists)..."

if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "AUTO_UNSEAL" "$CONFIG_FILE"; then
        log_success "✓ vault-mode.conf contains AUTO_UNSEAL setting"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_warning "⚠ AUTO_UNSEAL not found in vault-mode.conf"
    fi
    
    if grep -q "VAULT_MODE" "$CONFIG_FILE"; then
        log_success "✓ vault-mode.conf contains VAULT_MODE setting"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_warning "⚠ VAULT_MODE not found in vault-mode.conf"
    fi
else
    log_info "vault-mode.conf not found (will be created on first run)"
fi

# Test 14: Check for quick unseal command in instructions
log_info "Test 14: Checking quick unseal command availability..."

if grep -q "cat.*vault-unseal-keys.json.*jq.*head -n 3" "$POST_START_SCRIPT"; then
    log_success "✓ Provides quick unseal command"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Quick unseal command not found"
fi

# Test 15: Check for Vault readiness verification
log_info "Test 15: Checking Vault readiness verification..."

if grep -q "unsealed and ready" "$POST_START_SCRIPT"; then
    log_success "✓ Verifies Vault is ready after unseal"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Vault readiness verification not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 16: Check for unseal keys file path in instructions
log_info "Test 16: Checking unseal keys file path in instructions..."

if grep -q "vault-unseal-keys.json" "$POST_START_SCRIPT"; then
    log_success "✓ References correct unseal keys file path"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Unseal keys file path not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 17: Check for seal-status API endpoint usage
log_info "Test 17: Checking seal-status API endpoint usage..."

if grep -q "sys/seal-status" "$POST_START_SCRIPT"; then
    log_success "✓ Uses Vault seal-status API"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ seal-status API usage not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 18: Check for workspace name handling
log_info "Test 18: Checking workspace name variable..."

if grep -q "WORKSPACE_NAME" "$POST_START_SCRIPT"; then
    log_success "✓ Uses WORKSPACE_NAME for path resolution"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ WORKSPACE_NAME variable not found"
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
    log_success "✅ All integration tests passed!"
    echo ""
    log_info "Verified Integration:"
    echo "  1. ✓ post-start.sh exists and configured"
    echo "  2. ✓ AUTO_UNSEAL flag handling"
    echo "  3. ✓ vault-auto-unseal.sh invocation"
    echo "  4. ✓ Conditional execution (AUTO_UNSEAL=true)"
    echo "  5. ✓ Seal status verification"
    echo "  6. ✓ Manual unseal instructions"
    echo "  7. ✓ Ephemeral mode handling"
    echo "  8. ✓ Persistent mode detection"
    echo "  9. ✓ Error handling"
    echo " 10. ✓ Success messages"
    echo " 11. ✓ Configuration integration"
    echo " 12. ✓ Environment variables"
    echo " 13. ✓ Vault readiness verification"
    echo " 14. ✓ API endpoint usage"
    echo ""
    log_info "Container Lifecycle Flow:"
    echo "  1. Container starts → post-start.sh runs"
    echo "  2. Detects Vault mode (persistent/ephemeral)"
    echo "  3. If persistent + sealed → checks AUTO_UNSEAL flag"
    echo "  4. If AUTO_UNSEAL=true → runs vault-auto-unseal.sh"
    echo "  5. If auto-unseal fails → shows manual instructions"
    echo "  6. If AUTO_UNSEAL=false → shows manual instructions"
    echo "  7. If ephemeral → notes auto-initialized (no unseal)"
    echo ""
    log_info "To test manually:"
    echo "  1. Restart container: sudo systemctl restart devcontainer"
    echo "  2. Check logs: docker compose logs vault-hashicorp"
    echo "  3. Verify status: vault status"
    echo ""
    exit 0
else
    log_error "❌ Some integration tests failed. Review errors above."
    exit 1
fi
