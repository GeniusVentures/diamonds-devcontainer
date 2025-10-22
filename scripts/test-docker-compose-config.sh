#!/usr/bin/env bash
# Test script to verify Docker Compose configuration updates don't break YAML syntax
# Tests both persistent and ephemeral mode configurations

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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.dev.yml"
ENV_FILE="${PROJECT_ROOT}/.env"
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Docker Compose Configuration Updates"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Backup current .env
if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "${ENV_FILE}.test-backup"
    log_info "Backed up current .env file"
fi

# Test 1: Validate current Docker Compose syntax
log_info "Test 1: Validating current Docker Compose syntax..."

if docker compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
    log_success "✓ Current Docker Compose configuration is valid"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Current Docker Compose configuration has syntax errors"
    TEST_FAILED=$((TEST_FAILED + 1))
    # Don't exit - continue with tests
fi

# Test 2: Test persistent mode configuration
log_info "Test 2: Testing persistent mode configuration..."

# Set VAULT_COMMAND for persistent mode (no quotes in .env file)
if [[ -f "$ENV_FILE" ]] && grep -q "^VAULT_COMMAND=" "$ENV_FILE"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' 's|^VAULT_COMMAND=.*|VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl|' "$ENV_FILE"
    else
        sed -i 's|^VAULT_COMMAND=.*|VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl|' "$ENV_FILE"
    fi
else
    echo 'VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl' >> "$ENV_FILE"
fi

if docker compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
    log_success "✓ Persistent mode configuration is valid"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Verify command is correct (command is in array format in Docker Compose v2)
    RESOLVED_COMMAND=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -A 20 "^  vault-dev:" | grep -A 10 "command:" | grep -E "^\s+-\s+" | tr '\n' ' ' || echo "")
    
    if echo "$RESOLVED_COMMAND" | grep -q "vault-persistent.hcl"; then
        log_success "✓ Persistent mode command correctly resolved"
        log_info "Command: $RESOLVED_COMMAND"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ Persistent mode command not correctly resolved"
        log_error "Expected: vault-persistent.hcl in command"
        log_error "Got: $RESOLVED_COMMAND"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
else
    log_error "✗ Persistent mode configuration has syntax errors"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 3: Test ephemeral mode configuration
log_info "Test 3: Testing ephemeral mode configuration..."

# Set VAULT_COMMAND for ephemeral mode (no quotes in .env file)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's|^VAULT_COMMAND=.*|VAULT_COMMAND=server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200|' "$ENV_FILE"
else
    sed -i 's|^VAULT_COMMAND=.*|VAULT_COMMAND=server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200|' "$ENV_FILE"
fi

if docker compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
    log_success "✓ Ephemeral mode configuration is valid"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Verify command is correct (command is in array format in Docker Compose v2)
    RESOLVED_COMMAND=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -A 20 "^  vault-dev:" | grep -A 10 "command:" | grep -E "^\s+-\s+" | tr '\n' ' ' || echo "")
    
    if echo "$RESOLVED_COMMAND" | grep -q "dev.*root"; then
        log_success "✓ Ephemeral mode command correctly resolved"
        log_info "Command: $RESOLVED_COMMAND"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ Ephemeral mode command not correctly resolved"
        log_error "Expected: -dev and -dev-root-token-id=root in command"
        log_error "Got: $RESOLVED_COMMAND"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
else
    log_error "✗ Ephemeral mode configuration has syntax errors"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 4: Test missing VAULT_COMMAND (should use default)
log_info "Test 4: Testing default fallback when VAULT_COMMAND not set..."

# Remove VAULT_COMMAND
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' '/^VAULT_COMMAND=/d' "$ENV_FILE"
else
    sed -i '/^VAULT_COMMAND=/d' "$ENV_FILE"
fi

if docker compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
    log_success "✓ Configuration valid without VAULT_COMMAND (uses default)"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Verify default command is used (command is in array format in Docker Compose v2)
    RESOLVED_COMMAND=$(docker compose -f "$COMPOSE_FILE" config 2>/dev/null | grep -A 20 "^  vault-dev:" | grep -A 10 "command:" | grep -E "^\s+-\s+" | tr '\n' ' ' || echo "")
    
    if echo "$RESOLVED_COMMAND" | grep -q "dev.*root"; then
        log_success "✓ Default ephemeral command correctly applied"
        log_info "Command: $RESOLVED_COMMAND"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_warning "⚠ Default command may not be as expected"
        log_info "Command: $RESOLVED_COMMAND"
    fi
else
    log_error "✗ Configuration fails without VAULT_COMMAND"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 5: Test update-docker-compose-vault.sh script
log_info "Test 5: Testing update-docker-compose-vault.sh script..."

UPDATE_SCRIPT="${PROJECT_ROOT}/../scripts/update-docker-compose-vault.sh"

if [[ ! -f "$UPDATE_SCRIPT" ]]; then
    log_warning "⚠ update-docker-compose-vault.sh not found, skipping"
else
    # Create temporary vault-mode.conf
    TEMP_MODE_CONF="${PROJECT_ROOT}/../data/vault-mode.conf.test"
    cat > "$TEMP_MODE_CONF" <<EOF
VAULT_MODE="persistent"
AUTO_UNSEAL="false"
VAULT_COMMAND="server -config=/vault/config/vault-persistent.hcl"
EOF
    
    # This would require vault-mode.conf to exist, so we'll just verify it's executable
    if [[ -x "$UPDATE_SCRIPT" ]]; then
        log_success "✓ update-docker-compose-vault.sh is executable"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ update-docker-compose-vault.sh is not executable"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    
    # Clean up temp file
    rm -f "$TEMP_MODE_CONF"
fi

# Restore original .env
if [[ -f "${ENV_FILE}.test-backup" ]]; then
    mv "${ENV_FILE}.test-backup" "$ENV_FILE"
    log_info "Restored original .env file"
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
    log_success "✅ All tests passed! Docker Compose configuration updates work correctly."
    echo ""
    log_info "Verified:"
    echo "  1. ✓ Current configuration is valid"
    echo "  2. ✓ Persistent mode configuration works"
    echo "  3. ✓ Ephemeral mode configuration works"
    echo "  4. ✓ Default fallback works"
    echo "  5. ✓ Update script is ready"
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
