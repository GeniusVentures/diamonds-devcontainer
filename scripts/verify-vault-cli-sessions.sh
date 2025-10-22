#!/usr/bin/env bash
# Verification script for Vault CLI across terminal sessions
# Tests that vault command is available in all terminal environments

set -euo pipefail

echo "========================================"
echo "Vault CLI Cross-Session Verification"
echo "========================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    echo "[TEST $TESTS_TOTAL] $test_name"
    
    if eval "$test_command" &> /dev/null; then
        echo "✓ PASS"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test 1: Current shell
echo "[TEST 1] Current shell - vault command exists"
if command -v vault &> /dev/null; then
    echo "✓ PASS: vault found in current shell"
    echo "  Location: $(which vault)"
    echo "  Version: $(vault --version)"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: vault not found in current shell"
    echo "  NOTE: This test requires Vault CLI to be installed"
    echo "  Please rebuild the DevContainer or run install-vault-cli.sh"
    ((TESTS_FAILED++))
fi
((TESTS_TOTAL++))
echo ""

# Test 2: New bash session
run_test "New bash session - vault --version" \
    "bash -c 'vault --version'"

# Test 3: New bash login shell
run_test "New bash login shell - vault --version" \
    "bash -l -c 'vault --version'"

# Test 4: New sh session
run_test "New sh session - vault --version" \
    "sh -c 'vault --version'"

# Test 5: New bash session with clean environment
run_test "Clean environment bash - vault --version" \
    "env -i bash -c 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/node/.local/bin vault --version'"

# Test 6: Test from /tmp directory (different working directory)
run_test "Different working directory - vault --version" \
    "(cd /tmp && vault --version)"

# Test 7: Test with sudo (if available)
if command -v sudo &> /dev/null && sudo -n true 2>/dev/null; then
    run_test "As root user - vault --version" \
        "sudo vault --version"
else
    echo "[TEST $((TESTS_TOTAL + 1))] As root user - vault --version"
    echo "⊘ SKIP: sudo not available or requires password"
    ((TESTS_TOTAL++))
    echo ""
fi

# Test 8: Multiple rapid calls (test caching/reliability)
echo "[TEST $((TESTS_TOTAL + 1))] Multiple rapid calls"
((TESTS_TOTAL++))
SUCCESS_COUNT=0
for i in {1..5}; do
    if vault --version &> /dev/null; then
        ((SUCCESS_COUNT++))
    fi
done
if [ $SUCCESS_COUNT -eq 5 ]; then
    echo "✓ PASS: 5/5 calls successful"
    ((TESTS_PASSED++))
else
    echo "✗ FAIL: Only $SUCCESS_COUNT/5 calls successful"
    ((TESTS_FAILED++))
fi
echo ""

# Test 9: PATH persistence check
echo "[TEST $((TESTS_TOTAL + 1))] PATH includes vault location"
((TESTS_TOTAL++))
if command -v vault &> /dev/null; then
    VAULT_PATH=$(which vault)
    VAULT_DIR=$(dirname "$VAULT_PATH")
    
    if echo "$PATH" | grep -q "$VAULT_DIR"; then
        echo "✓ PASS: $VAULT_DIR is in PATH"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: $VAULT_DIR not found in PATH"
        echo "  Current PATH: $PATH"
        ((TESTS_FAILED++))
    fi
else
    echo "⊘ SKIP: vault not installed"
fi
echo ""

# Test 10: Verify vault binary permissions
echo "[TEST $((TESTS_TOTAL + 1))] Vault binary is executable"
((TESTS_TOTAL++))
if command -v vault &> /dev/null; then
    VAULT_PATH=$(which vault)
    if [ -x "$VAULT_PATH" ]; then
        echo "✓ PASS: $VAULT_PATH is executable"
        ls -l "$VAULT_PATH"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: $VAULT_PATH is not executable"
        ((TESTS_FAILED++))
    fi
else
    echo "⊘ SKIP: vault not installed"
fi
echo ""

# Test 11: Test vault version command (not --version)
run_test "vault version (without --)" \
    "vault version"

# Test 12: Test vault help
run_test "vault help command" \
    "vault help"

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total Tests: $TESTS_TOTAL"
echo "Passed:      $TESTS_PASSED"
echo "Failed:      $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    echo ""
    echo "Vault CLI is properly installed and accessible across all terminal sessions."
    exit 0
else
    echo "✗ Some tests failed"
    echo ""
    if ! command -v vault &> /dev/null; then
        echo "TROUBLESHOOTING:"
        echo "1. Vault CLI is not installed yet"
        echo "2. Rebuild the DevContainer to trigger Dockerfile installation"
        echo "3. Or run manually: bash .devcontainer/scripts/install-vault-cli.sh"
        echo "4. After installation, restart your terminal or run: source ~/.bashrc"
    else
        echo "TROUBLESHOOTING:"
        echo "1. Check PATH configuration: echo \$PATH"
        echo "2. Verify vault location: which vault"
        echo "3. Check if vault is executable: ls -l \$(which vault)"
        echo "4. Try running in new terminal session"
    fi
    exit 1
fi
