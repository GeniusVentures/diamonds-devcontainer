#!/usr/bin/env bash
# Test script for vault-setup-wizard.sh in non-interactive mode
# Tests various command-line argument combinations

# Don't exit on error for tests
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZARD_SCRIPT="$SCRIPT_DIR/setup/vault-setup-wizard.sh"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================================="
echo "Testing Vault Setup Wizard - Non-Interactive Mode"
echo "========================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

TESTS_PASSED=0
TESTS_FAILED=0

# Backup current configuration
backup_config() {
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        cp "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.test-backup"
        log_info "Backed up .env to .env.test-backup"
    fi
    
    if [[ -f "$PROJECT_ROOT/data/vault-mode.conf" ]]; then
        cp "$PROJECT_ROOT/data/vault-mode.conf" "$PROJECT_ROOT/data/vault-mode.conf.test-backup"
        log_info "Backed up vault-mode.conf"
    fi
}

# Restore configuration
restore_config() {
    if [[ -f "$PROJECT_ROOT/.env.test-backup" ]]; then
        cp "$PROJECT_ROOT/.env.test-backup" "$PROJECT_ROOT/.env"
        rm "$PROJECT_ROOT/.env.test-backup"
        log_info "Restored .env from backup"
    fi
    
    if [[ -f "$PROJECT_ROOT/data/vault-mode.conf.test-backup" ]]; then
        cp "$PROJECT_ROOT/data/vault-mode.conf.test-backup" "$PROJECT_ROOT/data/vault-mode.conf"
        rm "$PROJECT_ROOT/data/vault-mode.conf.test-backup"
        log_info "Restored vault-mode.conf from backup"
    fi
}

# Check if wizard script exists
if [[ ! -f "$WIZARD_SCRIPT" ]]; then
    log_error "Wizard script not found: $WIZARD_SCRIPT"
    exit 1
fi

log_info "Wizard script found: $WIZARD_SCRIPT"
echo ""

# Test 1: Check --help flag
log_test "Test 1: Checking --help flag"
if bash "$WIZARD_SCRIPT" --help 2>&1 | grep -q "vault-mode"; then
    log_success "✓ --help shows vault-mode option"
    ((TESTS_PASSED++))
else
    log_error "✗ --help does not show vault-mode option"
    ((TESTS_FAILED++))
fi
echo ""

# Test 2: Check argument parsing for --vault-mode
log_test "Test 2: Verifying argument parsing in wizard script"

if grep -q "while \[\[ \$# -gt 0 \]\]" "$WIZARD_SCRIPT"; then
    log_success "✓ While loop for argument parsing found"
    ((TESTS_PASSED++))
else
    log_error "✗ While loop for argument parsing not found"
    ((TESTS_FAILED++))
fi

if grep -A 20 "while \[\[ \$# -gt 0 \]\]" "$WIZARD_SCRIPT" | grep -q -- "--vault-mode)"; then
    log_success "✓ --vault-mode option handler found"
    ((TESTS_PASSED++))
elif grep -q -- "--vault-mode)" "$WIZARD_SCRIPT"; then
    log_success "✓ --vault-mode option handler found (outside while loop search)"
    ((TESTS_PASSED++))
else
    log_error "✗ --vault-mode option handler not found"
    ((TESTS_FAILED++))
fi

if grep -A 20 "while \[\[ \$# -gt 0 \]\]" "$WIZARD_SCRIPT" | grep -q -- "--vault-mode="; then
    log_success "✓ --vault-mode=* option handler found"
    ((TESTS_PASSED++))
else
    log_error "✗ --vault-mode=* option handler not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: Check validation logic
log_test "Test 3: Checking validation for vault mode argument"

if grep -A 30 "NON_INTERACTIVE.*true" "$WIZARD_SCRIPT" | grep -q "persistent|ephemeral"; then
    log_success "✓ Validation logic found for persistent/ephemeral"
    ((TESTS_PASSED++))
else
    log_error "✗ Validation logic not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 4: Check NON_INTERACTIVE variable initialization
log_test "Test 4: Checking NON_INTERACTIVE variable"

if grep -q "NON_INTERACTIVE=false" "$WIZARD_SCRIPT"; then
    log_success "✓ NON_INTERACTIVE initialized to false"
    ((TESTS_PASSED++))
else
    log_error "✗ NON_INTERACTIVE not properly initialized"
    ((TESTS_FAILED++))
fi
echo ""

# Test 5: Check VAULT_MODE_ARG variable
log_test "Test 5: Checking VAULT_MODE_ARG variable"

if grep -q 'VAULT_MODE_ARG=""' "$WIZARD_SCRIPT"; then
    log_success "✓ VAULT_MODE_ARG initialized"
    ((TESTS_PASSED++))
else
    log_error "✗ VAULT_MODE_ARG not initialized"
    ((TESTS_FAILED++))
fi
echo ""

# Test 6: Verify mode selection uses VAULT_MODE_ARG in non-interactive
log_test "Test 6: Checking non-interactive mode usage in step_vault_mode_selection"

if grep -A 30 "step_vault_mode_selection()" "$WIZARD_SCRIPT" | grep -q 'VAULT_MODE="\${VAULT_MODE_ARG:-persistent}"'; then
    log_success "✓ Non-interactive mode uses VAULT_MODE_ARG with persistent default"
    ((TESTS_PASSED++))
else
    log_error "✗ VAULT_MODE_ARG not used properly in non-interactive mode"
    ((TESTS_FAILED++))
fi
echo ""

# Note: Cannot actually run the wizard in non-interactive mode from inside DevContainer
# as it requires Vault service and full environment setup
echo "========================================================="
echo "Note: Actual Execution Tests"
echo "========================================================="
echo ""
log_info "The following tests require running on HOST machine with full environment:"
echo ""
echo "Test A: Non-interactive with persistent mode"
echo "  Command: bash $WIZARD_SCRIPT --non-interactive --vault-mode=persistent"
echo "  Expected: Creates vault-mode.conf with VAULT_MODE=persistent"
echo ""
echo "Test B: Non-interactive with ephemeral mode"
echo "  Command: bash $WIZARD_SCRIPT --non-interactive --vault-mode=ephemeral"
echo "  Expected: Creates vault-mode.conf with VAULT_MODE=ephemeral"
echo ""
echo "Test C: Non-interactive with invalid mode"
echo "  Command: bash $WIZARD_SCRIPT --non-interactive --vault-mode=invalid"
echo "  Expected: Exits with error message"
echo ""
echo "Test D: Alternative syntax"
echo "  Command: bash $WIZARD_SCRIPT --non-interactive --vault-mode persistent"
echo "  Expected: Works same as Test A"
echo ""

echo "========================================================="
echo "Syntax Validation Test"
echo "========================================================="
echo ""
log_test "Test 7: Bash syntax validation"

if bash -n "$WIZARD_SCRIPT" 2>&1; then
    log_success "✓ Wizard script has valid bash syntax"
    ((TESTS_PASSED++))
else
    log_error "✗ Wizard script has syntax errors"
    ((TESTS_FAILED++))
fi
echo ""

echo "========================================================="
echo "Non-Interactive Mode Test Summary"
echo "========================================================="
echo ""
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Tests Failed: $TESTS_FAILED${NC}"
fi
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    log_success "✓ All automated tests passed!"
    echo ""
    log_info "The wizard is ready for non-interactive testing on the host machine"
    exit 0
else
    log_error "✗ Some tests failed - please fix before proceeding"
    exit 1
fi
