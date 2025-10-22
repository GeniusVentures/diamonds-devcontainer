#!/usr/bin/env bash
# Test script for Vault CLI installation verification
# Tests both Dockerfile installation and fallback script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Vault CLI Installation Test"
echo "========================================"
echo ""

# Test 1: Check if Vault CLI is in PATH
echo "[TEST 1] Checking if Vault CLI is in PATH..."
if command -v vault &> /dev/null; then
    echo "✓ PASS: Vault CLI found in PATH"
    VAULT_PATH=$(which vault)
    echo "  Location: $VAULT_PATH"
    VAULT_VERSION=$(vault version | head -n1)
    echo "  Version: $VAULT_VERSION"
else
    echo "✗ FAIL: Vault CLI not found in PATH"
    echo "  This is expected if testing before container rebuild"
fi
echo ""

# Test 2: Test vault --version command
echo "[TEST 2] Testing 'vault --version' command..."
if vault --version &> /dev/null; then
    echo "✓ PASS: vault --version works"
    vault --version
else
    echo "✗ FAIL: vault --version failed"
fi
echo ""

# Test 3: Test vault version command (different from --version)
echo "[TEST 3] Testing 'vault version' command..."
if vault version &> /dev/null; then
    echo "✓ PASS: vault version works"
    vault version
else
    echo "✗ FAIL: vault version failed"
fi
echo ""

# Test 4: Check PATH configuration
echo "[TEST 4] Checking PATH configuration..."
echo "Current PATH:"
echo "$PATH" | tr ':' '\n' | nl
echo ""

# Test 5: Test in a new bash session
echo "[TEST 5] Testing Vault CLI in new bash session..."
if bash -c 'command -v vault' &> /dev/null; then
    echo "✓ PASS: Vault CLI available in new bash session"
else
    echo "✗ FAIL: Vault CLI not available in new bash session"
    echo "  This may indicate PATH is not properly configured"
fi
echo ""

# Test 6: Test Vault CLI authentication (if Vault server is running)
echo "[TEST 6] Testing Vault server connection..."
if [ -n "${VAULT_ADDR:-}" ]; then
    echo "VAULT_ADDR is set: $VAULT_ADDR"
    if vault status &> /dev/null; then
        echo "✓ PASS: Successfully connected to Vault server"
        vault status
    else
        echo "✗ FAIL: Cannot connect to Vault server"
        echo "  This is expected if Vault server is not running"
    fi
else
    echo "⊘ SKIP: VAULT_ADDR not set"
fi
echo ""

# Test 7: Verify installation files exist
echo "[TEST 7] Verifying installation files exist..."
if [ -f "$SCRIPT_DIR/install-vault-cli.sh" ]; then
    echo "✓ PASS: install-vault-cli.sh exists"
    if [ -x "$SCRIPT_DIR/install-vault-cli.sh" ]; then
        echo "✓ PASS: install-vault-cli.sh is executable"
    else
        echo "✗ FAIL: install-vault-cli.sh is not executable"
    fi
else
    echo "✗ FAIL: install-vault-cli.sh not found"
fi
echo ""

# Test 8: Test post-create.sh has install_vault_cli function
echo "[TEST 8] Checking post-create.sh integration..."
POST_CREATE="$SCRIPT_DIR/post-create.sh"
if [ -f "$POST_CREATE" ]; then
    if grep -q "install_vault_cli" "$POST_CREATE"; then
        echo "✓ PASS: post-create.sh includes install_vault_cli function"
        
        if grep -q "install_vault_cli$" "$POST_CREATE"; then
            echo "✓ PASS: install_vault_cli is called in main()"
        else
            echo "✗ FAIL: install_vault_cli not called in main()"
        fi
    else
        echo "✗ FAIL: post-create.sh missing install_vault_cli function"
    fi
else
    echo "✗ FAIL: post-create.sh not found"
fi
echo ""

echo "========================================"
echo "Test Summary"
echo "========================================"
echo ""
echo "To fully test Vault CLI installation:"
echo "1. Rebuild the DevContainer to test Dockerfile installation"
echo "2. Run: docker compose -f .devcontainer/docker-compose.dev.yml build devcontainer"
echo "3. Restart the DevContainer"
echo "4. Open a new terminal and run: vault version"
echo ""
echo "If Vault CLI is not installed after rebuild:"
echo "1. The post-create.sh script should automatically install it"
echo "2. Or run manually: bash .devcontainer/scripts/install-vault-cli.sh"
