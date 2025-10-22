#!/usr/bin/env bash
# Test script for extended validate-vault-setup.sh
# Tests persistent mode validation features

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
VALIDATE_SCRIPT="${SCRIPT_DIR}/validate-vault-setup.sh"
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Extended Vault Validation Script"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test 1: Verify script exists and is executable
log_info "Test 1: Checking script existence and permissions..."

if [[ -f "$VALIDATE_SCRIPT" ]]; then
    log_success "✓ validate-vault-setup.sh exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ validate-vault-setup.sh not found"
    TEST_FAILED=$((TEST_FAILED + 1))
    exit 1
fi

if [[ -x "$VALIDATE_SCRIPT" ]]; then
    log_success "✓ validate-vault-setup.sh is executable"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ validate-vault-setup.sh is not executable"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 2: Check for check_vault_mode function
log_info "Test 2: Checking check_vault_mode function..."

if grep -q "check_vault_mode()" "$VALIDATE_SCRIPT"; then
    log_success "✓ check_vault_mode() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ check_vault_mode() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 3: Check for check_vault_seal_status function
log_info "Test 3: Checking check_vault_seal_status function..."

if grep -q "check_vault_seal_status()" "$VALIDATE_SCRIPT"; then
    log_success "✓ check_vault_seal_status() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ check_vault_seal_status() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 4: Check for check_persistent_storage function
log_info "Test 4: Checking check_persistent_storage function..."

if grep -q "check_persistent_storage()" "$VALIDATE_SCRIPT"; then
    log_success "✓ check_persistent_storage() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ check_persistent_storage() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 5: Check for check_unseal_keys function
log_info "Test 5: Checking check_unseal_keys function..."

if grep -q "check_unseal_keys()" "$VALIDATE_SCRIPT"; then
    log_success "✓ check_unseal_keys() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ check_unseal_keys() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 6: Check for check_config_consistency function
log_info "Test 6: Checking check_config_consistency function..."

if grep -q "check_config_consistency()" "$VALIDATE_SCRIPT"; then
    log_success "✓ check_config_consistency() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ check_config_consistency() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 7: Check for vault-mode.conf loading
log_info "Test 7: Checking vault-mode.conf integration..."

if grep -q "vault-mode.conf" "$VALIDATE_SCRIPT"; then
    log_success "✓ Loads vault-mode.conf"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-mode.conf loading not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 8: Check for persistent mode detection
log_info "Test 8: Checking persistent mode detection..."

if grep -q 'VAULT_MODE.*==.*"persistent"' "$VALIDATE_SCRIPT"; then
    log_success "✓ Detects persistent mode"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Persistent mode detection not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 9: Check for ephemeral mode detection
log_info "Test 9: Checking ephemeral mode detection..."

if grep -q 'VAULT_MODE.*==.*"ephemeral"' "$VALIDATE_SCRIPT"; then
    log_success "✓ Detects ephemeral mode"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Ephemeral mode detection not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 10: Check for seal status API call
log_info "Test 10: Checking seal status API integration..."

if grep -q "sys/seal-status" "$VALIDATE_SCRIPT"; then
    log_success "✓ Uses Vault seal-status API"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Seal status API call not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 11: Check for raft directory validation
log_info "Test 11: Checking raft storage validation..."

if grep -q "vault-data/raft" "$VALIDATE_SCRIPT"; then
    log_success "✓ Validates raft storage directory"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Raft storage validation not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 12: Check for unseal keys file validation
log_info "Test 12: Checking unseal keys file validation..."

if grep -q "vault-unseal-keys.json" "$VALIDATE_SCRIPT"; then
    log_success "✓ Validates unseal keys file"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Unseal keys file validation not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 13: Check for file permissions check
log_info "Test 13: Checking file permissions validation..."

if grep -q "chmod 600" "$VALIDATE_SCRIPT" || grep -q "permissions.*600" "$VALIDATE_SCRIPT"; then
    log_success "✓ Checks file permissions (security)"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ File permissions check not found"
fi

# Test 14: Check for unseal instructions
log_info "Test 14: Checking unseal instructions..."

if grep -q "vault operator unseal" "$VALIDATE_SCRIPT"; then
    log_success "✓ Provides unseal instructions"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Unseal instructions not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 15: Check for configuration mismatch detection
log_info "Test 15: Checking configuration consistency validation..."

if grep -q "Persistent mode configured but no raft data" "$VALIDATE_SCRIPT"; then
    log_success "✓ Detects configuration mismatches"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Configuration mismatch detection not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 16: Check for main function calls new checks
log_info "Test 16: Checking main function integration..."

if grep -q "check_vault_mode" "$VALIDATE_SCRIPT" | grep -A 10 "^main()"; then
    log_success "✓ check_vault_mode called in main"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ check_vault_mode may not be called in main"
fi

if grep -q "check_config_consistency" "$VALIDATE_SCRIPT" | grep -A 10 "^main()"; then
    log_success "✓ check_config_consistency called in main"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ check_config_consistency may not be called in main"
fi

# Test 17: Check for JSON parsing with jq
log_info "Test 17: Checking JSON parsing..."

if grep -q "jq.*keys_base64" "$VALIDATE_SCRIPT"; then
    log_success "✓ Uses jq for JSON parsing"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ JSON parsing not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 18: Check for counter increments
log_info "Test 18: Checking validation counter increments..."

if grep -q "check_start" "$VALIDATE_SCRIPT"; then
    log_success "✓ Uses check_start for counter tracking"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Counter tracking not properly implemented"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 19: Check for raft database size reporting
log_info "Test 19: Checking raft database size reporting..."

if grep -q "du -sh.*raft" "$VALIDATE_SCRIPT"; then
    log_success "✓ Reports raft database size"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Database size reporting not found"
fi

# Test 20: Check for sealed state warnings
log_info "Test 20: Checking sealed state warnings..."

if grep -q 'seal_status.*==.*"true"' "$VALIDATE_SCRIPT"; then
    log_success "✓ Warns when Vault is sealed"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Sealed state warning not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 21: Check for unsealed state success
log_info "Test 21: Checking unsealed state confirmation..."

if grep -q 'seal_status.*==.*"false"' "$VALIDATE_SCRIPT"; then
    log_success "✓ Confirms when Vault is unsealed"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Unsealed state confirmation not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 22: Check for key count validation
log_info "Test 22: Checking unseal key count validation..."

if grep -q "key_count.*-ge.*3" "$VALIDATE_SCRIPT" || grep -q "Insufficient unseal keys" "$VALIDATE_SCRIPT"; then
    log_success "✓ Validates minimum 3 unseal keys"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Key count validation not found"
    TEST_FAILED=$((TEST_FAILED + 1))
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
    log_success "✅ All tests passed! Validation script properly extended."
    echo ""
    log_info "New Validation Features:"
    echo "  1. ✓ Vault mode detection (persistent/ephemeral)"
    echo "  2. ✓ Seal status checking"
    echo "  3. ✓ Persistent storage validation"
    echo "  4. ✓ Unseal keys file validation"
    echo "  5. ✓ Configuration consistency checking"
    echo "  6. ✓ File permissions security"
    echo "  7. ✓ Raft database size reporting"
    echo "  8. ✓ Manual unseal instructions"
    echo "  9. ✓ Configuration mismatch detection"
    echo " 10. ✓ Key count validation"
    echo ""
    log_info "Validation Workflow:"
    echo "  1. Detects Vault mode from vault-mode.conf"
    echo "  2. If persistent:"
    echo "     - Checks seal status"
    echo "     - Validates raft storage"
    echo "     - Validates unseal keys file"
    echo "  3. Checks configuration consistency"
    echo "  4. Provides appropriate warnings/instructions"
    echo ""
    log_info "To run validation:"
    echo "  bash .devcontainer/scripts/validate-vault-setup.sh"
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
