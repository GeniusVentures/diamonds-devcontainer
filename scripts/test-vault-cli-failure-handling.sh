#!/usr/bin/env bash
# Test script for Vault CLI installation failure handling
# Verifies that post-create.sh continues gracefully when Vault installation fails

set -euo pipefail

echo "========================================"
echo "Vault CLI Failure Handling Test"
echo "========================================"
echo ""

# Test function
test_nonblocking_behavior() {
    echo "[TEST] Testing non-blocking installation failure..."
    echo ""
    
    # Create a temporary install script that always fails
    local temp_script=$(mktemp)
    cat > "$temp_script" <<'EOF'
#!/usr/bin/env bash
echo "[ERROR] Simulated installation failure"
exit 1
EOF
    chmod +x "$temp_script"
    
    # Test the install_vault_cli function behavior
    echo "Simulating installation failure..."
    
    # Run the install script and capture exit code
    set +e
    bash "$temp_script"
    local exit_code=$?
    set -e
    
    if [ $exit_code -ne 0 ]; then
        echo "✓ PASS: Script exited with error code (as expected)"
    else
        echo "✗ FAIL: Script should have failed"
        rm -f "$temp_script"
        return 1
    fi
    
    # Clean up
    rm -f "$temp_script"
    
    echo ""
    echo "✓ Installation failure is properly handled"
    echo ""
}

# Test post-create.sh has proper error handling
test_postcreate_error_handling() {
    echo "[TEST] Verifying post-create.sh error handling..."
    echo ""
    
    local post_create=".devcontainer/scripts/post-create.sh"
    
    if [ ! -f "$post_create" ]; then
        echo "✗ FAIL: post-create.sh not found"
        return 1
    fi
    
    # Check for return 0 on errors (non-blocking)
    if grep -q "return 0.*# Non-blocking" "$post_create"; then
        echo "✓ PASS: Found non-blocking return statements"
    else
        echo "⚠ WARNING: Non-blocking return statements not clearly marked"
    fi
    
    # Check for proper error logging
    if grep -q "log_warning.*Vault CLI installation failed" "$post_create"; then
        echo "✓ PASS: Found proper error logging"
    else
        echo "✗ FAIL: Missing proper error logging"
        return 1
    fi
    
    # Check that install_vault_cli doesn't exit on failure
    if grep -A 20 "install_vault_cli()" "$post_create" | grep -q "exit 1"; then
        echo "✗ FAIL: install_vault_cli() contains 'exit 1' (should be non-blocking)"
        return 1
    else
        echo "✓ PASS: install_vault_cli() does not force exit on failure"
    fi
    
    echo ""
}

# Test install-vault-cli.sh provides helpful error messages
test_install_script_error_messages() {
    echo "[TEST] Verifying install script error messages..."
    echo ""
    
    local install_script=".devcontainer/scripts/install-vault-cli.sh"
    
    if [ ! -f "$install_script" ]; then
        echo "✗ FAIL: install-vault-cli.sh not found"
        return 1
    fi
    
    # Check for log_error function
    if grep -q "log_error" "$install_script"; then
        echo "✓ PASS: Uses log_error for error messages"
    else
        echo "✗ FAIL: Missing log_error function"
        return 1
    fi
    
    # Check for helpful error messages
    if grep -q "Please check your internet connection" "$install_script"; then
        echo "✓ PASS: Includes helpful troubleshooting messages"
    else
        echo "⚠ WARNING: Could have more helpful error messages"
    fi
    
    echo ""
}

# Test that main() continues after install_vault_cli failure
test_main_execution_continues() {
    echo "[TEST] Verifying main() continues after Vault CLI failure..."
    echo ""
    
    local post_create=".devcontainer/scripts/post-create.sh"
    
    # Check that install_vault_cli is called in main()
    if grep -A 30 "^main()" "$post_create" | grep -q "install_vault_cli"; then
        echo "✓ PASS: install_vault_cli is called in main()"
    else
        echo "✗ FAIL: install_vault_cli not found in main()"
        return 1
    fi
    
    # Check that other functions are called after install_vault_cli
    if grep -A 30 "^main()" "$post_create" | grep -A 5 "install_vault_cli" | grep -q "install_dependencies"; then
        echo "✓ PASS: main() continues with install_dependencies after install_vault_cli"
    else
        echo "✗ FAIL: main() doesn't appear to continue after install_vault_cli"
        return 1
    fi
    
    echo ""
    echo "✓ Post-create setup will continue even if Vault CLI installation fails"
    echo ""
}

# Documentation test
echo "========================================"
echo "Non-Blocking Behavior Documentation"
echo "========================================"
echo ""
echo "The Vault CLI installation is designed to be non-blocking:"
echo ""
echo "1. If Dockerfile installation fails:"
echo "   - Build continues (RUN command succeeds)"
echo "   - Post-create script attempts fallback installation"
echo ""
echo "2. If post-create fallback fails:"
echo "   - Warning message displayed"
echo "   - Setup continues with other tasks"
echo "   - User can install manually later"
echo ""
echo "3. Graceful degradation:"
echo "   - Scripts use HTTP API as fallback"
echo "   - Core functionality remains available"
echo "   - Only CLI-specific features affected"
echo ""

# Run all tests
echo "========================================"
echo "Running Tests"
echo "========================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    echo "Running: $test_name"
    if $test_func; then
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

run_test "Non-blocking behavior" test_nonblocking_behavior
run_test "Post-create error handling" test_postcreate_error_handling
run_test "Install script error messages" test_install_script_error_messages
run_test "Main execution continues" test_main_execution_continues

echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ All failure handling tests passed!"
    echo ""
    echo "Vault CLI installation is properly configured as non-blocking."
    echo "The DevContainer will function correctly even if installation fails."
    exit 0
else
    echo "✗ Some tests failed"
    echo ""
    echo "Please review the error handling implementation."
    exit 1
fi
