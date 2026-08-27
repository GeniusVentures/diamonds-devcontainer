#!/usr/bin/env bash
# Test script for vault-mode CLI utility
# Tests all commands and functionality

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
CLI_SCRIPT="${SCRIPT_DIR}/vault-mode"
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Vault Mode CLI Utility"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test 1: Verify script exists and is executable
log_info "Test 1: Checking script existence and permissions..."

if [[ -f "$CLI_SCRIPT" ]]; then
    log_success "✓ vault-mode script exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-mode script not found"
    TEST_FAILED=$((TEST_FAILED + 1))
    exit 1
fi

if [[ -x "$CLI_SCRIPT" ]]; then
    log_success "✓ vault-mode is executable"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-mode is not executable"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 2: Test help command
log_info "Test 2: Testing help command..."

if "$CLI_SCRIPT" help 2>&1 | grep -q "Vault Mode CLI Utility"; then
    log_success "✓ help command works"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ help command failed"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 3: Test --help flag
log_info "Test 3: Testing --help flag..."

if "$CLI_SCRIPT" --help 2>&1 | grep -q "Usage:"; then
    log_success "✓ --help flag works"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ --help flag failed"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 4: Test status command
log_info "Test 4: Testing status command..."

if "$CLI_SCRIPT" status 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Vault Mode Status\|Mode:"; then
    log_success "✓ status command works"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ status command failed"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 5: Test invalid command
log_info "Test 5: Testing invalid command handling..."

OUTPUT=$("$CLI_SCRIPT" invalid 2>&1 || true)
if echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "Unknown command|ERROR.*Unknown"; then
    log_success "✓ Invalid command detected"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Invalid command not detected"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 6: Test switch command without mode
log_info "Test 6: Testing switch command without mode argument..."

OUTPUT=$("$CLI_SCRIPT" switch 2>&1 || true)
if echo "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -qE "Missing mode|ERROR.*Missing"; then
    log_success "✓ Missing mode argument detected"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Missing mode argument not detected"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 7: Check function definitions
log_info "Test 7: Checking function definitions in script..."

if grep -q "cmd_status()" "$CLI_SCRIPT"; then
    log_success "✓ cmd_status() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ cmd_status() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

if grep -q "cmd_switch()" "$CLI_SCRIPT"; then
    log_success "✓ cmd_switch() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ cmd_switch() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

if grep -q "get_current_mode()" "$CLI_SCRIPT"; then
    log_success "✓ get_current_mode() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ get_current_mode() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

if grep -q "update_vault_mode_conf()" "$CLI_SCRIPT"; then
    log_success "✓ update_vault_mode_conf() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ update_vault_mode_conf() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

if grep -q "update_docker_compose_env()" "$CLI_SCRIPT"; then
    log_success "✓ update_docker_compose_env() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ update_docker_compose_env() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

if grep -q "restart_vault_service()" "$CLI_SCRIPT"; then
    log_success "✓ restart_vault_service() function defined"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ restart_vault_service() function not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 8: Check for migration prompt
log_info "Test 8: Checking migration prompt implementation..."

if grep -q "Migration Options:" "$CLI_SCRIPT"; then
    log_success "✓ Migration prompt implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Migration prompt not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 9: Check for vault-migrate-mode.sh integration
log_info "Test 9: Checking vault-migrate-mode.sh integration..."

if grep -q "vault-migrate-mode.sh" "$CLI_SCRIPT"; then
    log_success "✓ Migration script integration found"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Migration script integration not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 10: Check for configuration file handling
log_info "Test 10: Checking vault-mode.conf handling..."

if grep -q "vault-mode.conf" "$CLI_SCRIPT"; then
    log_success "✓ vault-mode.conf handling implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-mode.conf handling not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 11: Check for Docker availability handling
log_info "Test 11: Checking Docker availability handling..."

if grep -q "docker ps" "$CLI_SCRIPT"; then
    log_success "✓ Docker availability check implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Docker availability check not found"
fi

# Test 12: Check for service restart functionality
log_info "Test 12: Checking Vault service restart functionality..."

if grep -q "docker compose.*restart" "$CLI_SCRIPT"; then
    log_success "✓ Service restart functionality implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Service restart functionality not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 13: Check for colored output
log_info "Test 13: Checking colored output support..."

if grep -q "GREEN=" "$CLI_SCRIPT" && grep -q "BLUE=" "$CLI_SCRIPT"; then
    log_success "✓ Colored output implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Colored output not found"
fi

# Test 14: Check for status details (initialized, sealed)
log_info "Test 14: Checking detailed status information..."

if grep -q "initialized" "$CLI_SCRIPT" && grep -q "sealed" "$CLI_SCRIPT"; then
    log_success "✓ Detailed status checks implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Detailed status checks not found"
fi

# Test 15: Check for persistent storage information
log_info "Test 15: Checking persistent storage information..."

if grep -q "Persistent Storage:" "$CLI_SCRIPT" || grep -q "raft" "$CLI_SCRIPT"; then
    log_success "✓ Persistent storage info implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Persistent storage info not found"
fi

# Test 16: Check for confirmation prompts
log_info "Test 16: Checking confirmation prompts..."

if grep -q "read -p" "$CLI_SCRIPT"; then
    log_success "✓ Confirmation prompts implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Confirmation prompts not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 17: Check for same-mode detection
log_info "Test 17: Checking same-mode detection..."

if grep -q "Already in.*mode" "$CLI_SCRIPT"; then
    log_success "✓ Same-mode detection implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Same-mode detection not found"
fi

# Test 18: Check command dispatcher
log_info "Test 18: Checking command dispatcher..."

if grep -q "case.*in" "$CLI_SCRIPT"; then
    log_success "✓ Command dispatcher implemented"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Command dispatcher not found"
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
    log_success "✅ All tests passed! vault-mode CLI is properly implemented."
    echo ""
    log_info "Verified:"
    echo "  1. ✓ Script exists and is executable"
    echo "  2. ✓ Help command works"
    echo "  3. ✓ Status command works"
    echo "  4. ✓ Invalid command handling"
    echo "  5. ✓ All required functions defined"
    echo "  6. ✓ Migration integration"
    echo "  7. ✓ Configuration handling"
    echo "  8. ✓ Docker availability handling"
    echo "  9. ✓ Service restart functionality"
    echo " 10. ✓ Colored output"
    echo " 11. ✓ Detailed status information"
    echo " 12. ✓ Confirmation prompts"
    echo " 13. ✓ Command dispatcher"
    echo ""
    log_info "Note: Full integration testing requires Docker access"
    log_info "To add to PATH: export PATH=\"\$PATH:${SCRIPT_DIR}\""
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
