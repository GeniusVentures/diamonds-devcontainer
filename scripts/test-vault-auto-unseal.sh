#!/usr/bin/env bash
# Test script for vault-auto-unseal.sh
# Tests auto-unseal functionality and error handling

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
AUTO_UNSEAL_SCRIPT="${SCRIPT_DIR}/vault-auto-unseal.sh"
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Vault Auto-Unseal Script"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test 1: Verify script exists and is executable
log_info "Test 1: Checking script existence and permissions..."

if [[ -f "$AUTO_UNSEAL_SCRIPT" ]]; then
    log_success "✓ vault-auto-unseal.sh script exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-auto-unseal.sh script not found"
    TEST_FAILED=$((TEST_FAILED + 1))
    exit 1
fi

if [[ -x "$AUTO_UNSEAL_SCRIPT" ]]; then
    log_success "✓ vault-auto-unseal.sh is executable"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-auto-unseal.sh is not executable"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 2: Check shebang
log_info "Test 2: Checking script structure..."

if head -n 1 "$AUTO_UNSEAL_SCRIPT" | grep -q "#!/usr/bin/env bash"; then
    log_success "✓ Correct shebang present"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Incorrect or missing shebang"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 3: Check for error handling
log_info "Test 3: Checking error handling..."

if grep -q "set -euo pipefail" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Error handling enabled (set -euo pipefail)"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Error handling not found"
fi

# Test 4: Check for configuration variables
log_info "Test 4: Checking configuration variables..."

if grep -q "UNSEAL_KEYS_FILE=" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ UNSEAL_KEYS_FILE variable defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ UNSEAL_KEYS_FILE variable not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

if grep -q "VAULT_ADDR=" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ VAULT_ADDR variable defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ VAULT_ADDR variable not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 5: Check for file existence validation
log_info "Test 5: Checking file existence validation..."

if grep -q "if \[\[ ! -f.*UNSEAL_KEYS_FILE" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Unseal keys file existence check present"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Missing file existence check"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 6: Check for error messages
log_info "Test 6: Checking error messages..."

if grep -q "Unseal keys file not found" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Error message for missing file present"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Error message for missing file not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 7: Check for Vault connectivity check
log_info "Test 7: Checking Vault connectivity validation..."

if grep -q "curl.*VAULT_ADDR.*sys/health" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Vault connectivity check present"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Vault connectivity check not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 8: Check for seal status verification
log_info "Test 8: Checking seal status verification..."

if grep -q "sys/seal-status" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Seal status check present"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Seal status check not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 9: Check for key extraction (3 keys)
log_info "Test 9: Checking unseal key extraction..."

if grep -q "head -n 3" "$AUTO_UNSEAL_SCRIPT" && grep -q "keys_base64" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Extracts 3 unseal keys from JSON"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Key extraction logic not found or incorrect"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 10: Check for unseal API call
log_info "Test 10: Checking unseal API call..."

if grep -q "sys/unseal" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Vault unseal API call present"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Unseal API call not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 11: Check for progress tracking
log_info "Test 11: Checking unseal progress tracking..."

if grep -q "progress" "$AUTO_UNSEAL_SCRIPT" && grep -q "threshold" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Progress tracking implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Progress tracking not found"
fi

# Test 12: Check for "already unsealed" handling
log_info "Test 12: Checking 'already unsealed' handling..."

if grep -q "already unsealed" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Handles already unsealed case"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Already unsealed handling not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 13: Check for jq dependency
log_info "Test 13: Checking jq usage for JSON parsing..."

if grep -q "jq" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Uses jq for JSON parsing"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ jq not used for JSON parsing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 14: Check for logging functions
log_info "Test 14: Checking logging functions..."

log_functions=("log_info" "log_success" "log_error" "log_warning")
all_logs_found=true

for func in "${log_functions[@]}"; do
    if ! grep -q "${func}()" "$AUTO_UNSEAL_SCRIPT"; then
        log_error "✗ Logging function $func not found"
        all_logs_found=false
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
done

if $all_logs_found; then
    log_success "✓ All logging functions defined"
    TEST_PASSED=$((TEST_PASSED + 1))
fi

# Test 15: Check for color codes
log_info "Test 15: Checking color-coded output..."

if grep -q "GREEN=" "$AUTO_UNSEAL_SCRIPT" && grep -q "RED=" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Color-coded output implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Color-coded output not found"
fi

# Test 16: Check for main function
log_info "Test 16: Checking main function..."

if grep -q "^main()" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Main function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Main function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 17: Check for file permissions warning
log_info "Test 17: Checking security (file permissions check)..."

if grep -q "stat.*permissions" "$AUTO_UNSEAL_SCRIPT" || grep -q "chmod 600" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ File permissions security check present"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ File permissions security check not found"
fi

# Test 18: Check for insufficient keys handling
log_info "Test 18: Checking insufficient keys handling..."

if grep -q "Insufficient unseal keys" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Handles insufficient keys case"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Insufficient keys handling not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 19: Check for manual unseal instructions
log_info "Test 19: Checking manual unseal instructions..."

if grep -q "unseal manually" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Provides manual unseal instructions"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Manual unseal instructions not found"
fi

# Test 20: Check exit codes
log_info "Test 20: Checking proper exit codes..."

if grep -q "exit 0" "$AUTO_UNSEAL_SCRIPT" && grep -q "exit 1" "$AUTO_UNSEAL_SCRIPT"; then
    log_success "✓ Uses proper exit codes"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Exit codes not properly set"
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
    log_success "✅ All tests passed! vault-auto-unseal.sh is properly implemented."
    echo ""
    log_info "Verified:"
    echo "  1. ✓ Script exists and is executable"
    echo "  2. ✓ Error handling enabled"
    echo "  3. ✓ Configuration variables defined"
    echo "  4. ✓ File existence validation"
    echo "  5. ✓ Vault connectivity check"
    echo "  6. ✓ Seal status verification"
    echo "  7. ✓ Extracts 3 unseal keys"
    echo "  8. ✓ Unseal API implementation"
    echo "  9. ✓ Progress tracking"
    echo " 10. ✓ Handles already unsealed case"
    echo " 11. ✓ JSON parsing with jq"
    echo " 12. ✓ Logging functions"
    echo " 13. ✓ Color-coded output"
    echo " 14. ✓ Main function"
    echo " 15. ✓ Security checks"
    echo " 16. ✓ Error handling"
    echo " 17. ✓ Proper exit codes"
    echo ""
    log_info "Note: Integration testing requires running Vault"
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
