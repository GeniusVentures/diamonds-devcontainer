#!/usr/bin/env bash
# Test script to verify auto-unseal works on container restart
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
log_info "Test: Auto-Unseal on Container Restart"
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

# Test 1: Check vault-mode.conf exists and is set to persistent
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

# Test 2: Enable auto-unseal if not already enabled
log_info "Test 2: Ensuring auto-unseal is enabled..."

if [[ "${AUTO_UNSEAL:-false}" != "true" ]]; then
    log_warning "Auto-unseal is disabled. Enabling for this test..."
    
    # Backup original config
    cp .devcontainer/data/vault-mode.conf .devcontainer/data/vault-mode.conf.backup
    
    # Update AUTO_UNSEAL
    if grep -q "^AUTO_UNSEAL=" .devcontainer/data/vault-mode.conf; then
        sed -i 's/^AUTO_UNSEAL=.*/AUTO_UNSEAL="true"/' .devcontainer/data/vault-mode.conf
    else
        echo 'AUTO_UNSEAL="true"' >> .devcontainer/data/vault-mode.conf
    fi
    
    log_success "✓ Auto-unseal enabled for testing"
    RESTORE_CONFIG=true
else
    log_success "✓ Auto-unseal already enabled"
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

log_success "✓ Unseal keys file exists"
((TEST_PASSED++))

# Test 4: Restart Vault container
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

# Test 5: Check Vault is accessible
log_info "Test 5: Checking Vault accessibility..."

MAX_ATTEMPTS=10
ATTEMPT=1
VAULT_READY=false

while [[ $ATTEMPT -le $MAX_ATTEMPTS ]]; do
    if curl -s --max-time 2 "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
        VAULT_READY=true
        break
    fi
    log_info "Attempt $ATTEMPT/$MAX_ATTEMPTS: Waiting for Vault..."
    sleep 2
    ((ATTEMPT++))
done

if [[ "$VAULT_READY" == "true" ]]; then
    log_success "✓ Vault is accessible"
    ((TEST_PASSED++))
else
    log_error "✗ Vault not accessible after $MAX_ATTEMPTS attempts"
    ((TEST_FAILED++))
    exit 1
fi

# Test 6: Verify Vault is unsealed
log_info "Test 6: Checking Vault seal status..."

SEAL_STATUS=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" | jq -r '.sealed' 2>/dev/null || echo "error")

if [[ "$SEAL_STATUS" == "false" ]]; then
    log_success "✓ Vault is unsealed (auto-unseal worked!)"
    ((TEST_PASSED++))
elif [[ "$SEAL_STATUS" == "true" ]]; then
    log_error "✗ Vault is still sealed (auto-unseal failed)"
    log_info "Check post-start.sh logs for errors"
    ((TEST_FAILED++))
else
    log_error "✗ Failed to query Vault seal status"
    ((TEST_FAILED++))
fi

# Test 7: Verify secrets are accessible
log_info "Test 7: Testing secret access..."

# Try to write a test secret
ROOT_TOKEN=$(jq -r '.root_token' .devcontainer/data/vault-unseal-keys.json 2>/dev/null || echo "root")
TEST_SECRET="test-auto-unseal-$(date +%s)"

WRITE_RESPONSE=$(curl -s -X POST \
    -H "X-Vault-Token: $ROOT_TOKEN" \
    -d "{\"data\": {\"value\": \"auto-unseal-test\"}}" \
    "$VAULT_ADDR/v1/secret/data/$TEST_SECRET" 2>/dev/null || echo "{}")

if echo "$WRITE_RESPONSE" | jq -e '.data' > /dev/null 2>&1; then
    log_success "✓ Successfully wrote secret (Vault is operational)"
    ((TEST_PASSED++))
    
    # Clean up test secret
    curl -s -X DELETE -H "X-Vault-Token: $ROOT_TOKEN" \
        "$VAULT_ADDR/v1/secret/metadata/$TEST_SECRET" > /dev/null 2>&1
else
    log_error "✗ Failed to write secret"
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
    log_success "✅ All tests passed! Auto-unseal works correctly on container restart."
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
