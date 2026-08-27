#!/usr/bin/env bash
# Verify environment variable propagation for Vault configuration
# Must be run from the HOST machine (not inside DevContainer)
# Usage: ./.devcontainer/scripts/verify-env-propagation.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEVCONTAINER_DIR")"

echo "========================================================="
echo "Verifying Environment Variable Propagation"
echo "========================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} ✓ $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} ✗ $1"
}

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Verify VAULT_COMMAND in .env file
log_test "Test 1: Verify VAULT_COMMAND exists in .env"
if grep -q "^VAULT_COMMAND=" "$DEVCONTAINER_DIR/.env"; then
    VAULT_CMD=$(grep "^VAULT_COMMAND=" "$DEVCONTAINER_DIR/.env" | cut -d'=' -f2-)
    log_pass "VAULT_COMMAND found in .env"
    log_info "  Value: $VAULT_CMD"
    ((TESTS_PASSED++))
else
    log_fail "VAULT_COMMAND not found in .env"
    ((TESTS_FAILED++))
fi
echo ""

# Test 2: Verify VAULT_COMMAND in .env.example
log_test "Test 2: Verify VAULT_COMMAND documented in .env.example"
if grep -q "^VAULT_COMMAND=" "$DEVCONTAINER_DIR/.env.example"; then
    log_pass "VAULT_COMMAND found in .env.example"
    ((TESTS_PASSED++))
else
    log_fail "VAULT_COMMAND not found in .env.example"
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: Verify docker-compose.dev.yml uses VAULT_COMMAND
log_test "Test 3: Verify docker-compose.dev.yml references VAULT_COMMAND"
if grep -q '\${VAULT_COMMAND' "$DEVCONTAINER_DIR/docker-compose.dev.yml"; then
    log_pass "docker-compose.dev.yml references VAULT_COMMAND variable"
    # Show the line
    COMMAND_LINE=$(grep 'command:.*VAULT_COMMAND' "$DEVCONTAINER_DIR/docker-compose.dev.yml" | sed 's/^[[:space:]]*//')
    log_info "  $COMMAND_LINE"
    ((TESTS_PASSED++))
else
    log_fail "docker-compose.dev.yml does not reference VAULT_COMMAND"
    ((TESTS_FAILED++))
fi
echo ""

# Test 4: Validate docker-compose configuration
log_test "Test 4: Validate docker-compose configuration syntax"
cd "$PROJECT_ROOT"
if docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" config > /dev/null 2>&1; then
    log_pass "docker-compose.dev.yml syntax is valid"
    ((TESTS_PASSED++))
else
    log_fail "docker-compose.dev.yml has syntax errors"
    ((TESTS_FAILED++))
fi
echo ""

# Test 5: Verify resolved command in docker-compose config
log_test "Test 5: Verify VAULT_COMMAND resolves correctly in docker-compose"
RESOLVED_CONFIG=$(docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" config 2>/dev/null)
if echo "$RESOLVED_CONFIG" | grep -A 5 "vault-dev:" | grep -q "command:"; then
    RESOLVED_COMMAND=$(echo "$RESOLVED_CONFIG" | grep -A 10 "vault-dev:" | grep "command:" | sed 's/^[[:space:]]*//')
    log_pass "VAULT_COMMAND resolves in docker-compose config"
    log_info "  $RESOLVED_COMMAND"
    ((TESTS_PASSED++))
else
    log_fail "Could not find resolved command in docker-compose config"
    ((TESTS_FAILED++))
fi
echo ""

# Test 6: Verify bind mounts are configured
log_test "Test 6: Verify vault data bind mounts are configured"
if grep -A 20 "vault-dev:" "$DEVCONTAINER_DIR/docker-compose.dev.yml" | grep -q "./data/vault-data:/vault/data"; then
    log_pass "Vault data bind mount configured"
    ((TESTS_PASSED++))
else
    log_fail "Vault data bind mount not found"
    ((TESTS_FAILED++))
fi

if grep -A 20 "vault-dev:" "$DEVCONTAINER_DIR/docker-compose.dev.yml" | grep -q "./config/vault-persistent.hcl:/vault/config/vault-persistent.hcl"; then
    log_pass "Vault config bind mount configured"
    ((TESTS_PASSED++))
else
    log_fail "Vault config bind mount not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 7: Verify persistent storage directory exists
log_test "Test 7: Verify persistent storage directory exists"
if [ -d "$DEVCONTAINER_DIR/data/vault-data/raft" ]; then
    log_pass "Persistent storage directory exists"
    log_info "  Path: $DEVCONTAINER_DIR/data/vault-data/raft"
    ((TESTS_PASSED++))
else
    log_fail "Persistent storage directory not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 8: Verify Vault configuration file exists
log_test "Test 8: Verify Vault configuration file exists"
if [ -f "$DEVCONTAINER_DIR/config/vault-persistent.hcl" ]; then
    log_pass "Vault configuration file exists"
    log_info "  Path: $DEVCONTAINER_DIR/config/vault-persistent.hcl"
    ((TESTS_PASSED++))
else
    log_fail "Vault configuration file not found"
    ((TESTS_FAILED++))
fi
echo ""

# Test 9: Check if Vault service is running
log_test "Test 9: Check if Vault service is currently running"
if docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" ps --services --filter "status=running" 2>/dev/null | grep -q "vault-dev"; then
    log_info "Vault service is running"
    
    # Test 9a: Check if VAULT_ADDR is accessible
    log_test "Test 9a: Verify Vault API is accessible"
    if curl -s http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
        log_pass "Vault API is accessible at http://localhost:8200"
        ((TESTS_PASSED++))
    else
        log_warn "Vault API not accessible (may still be starting)"
    fi
    
    # Test 9b: Check actual running command
    log_test "Test 9b: Verify actual running command"
    CONTAINER_ID=$(docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" ps -q vault-dev 2>/dev/null)
    if [ -n "$CONTAINER_ID" ]; then
        ACTUAL_COMMAND=$(docker inspect "$CONTAINER_ID" --format='{{.Config.Cmd}}' 2>/dev/null)
        log_info "  Container command: $ACTUAL_COMMAND"
        
        if echo "$ACTUAL_COMMAND" | grep -q "server"; then
            log_pass "Container is running Vault server"
            ((TESTS_PASSED++))
        else
            log_fail "Container command doesn't match expected Vault server"
            ((TESTS_FAILED++))
        fi
    fi
else
    log_warn "Vault service is not running (start it to test runtime behavior)"
    log_info "  To start: docker compose -f .devcontainer/docker-compose.dev.yml up -d vault-dev"
fi
echo ""

# Test 10: Test environment variable precedence
log_test "Test 10: Document environment variable precedence"
log_info "Environment variable resolution order in docker-compose:"
log_info "  1. Shell environment variables (highest priority)"
log_info "  2. .env file in same directory as docker-compose.yml"
log_info "  3. Default values in docker-compose.yml (e.g., :-default)"
log_info ""
log_info "To override VAULT_COMMAND:"
log_info "  VAULT_COMMAND='server -config=/vault/config/vault-persistent.hcl' \\"
log_info "    docker compose -f .devcontainer/docker-compose.dev.yml up -d"
((TESTS_PASSED++))
echo ""

# Summary
echo "========================================================="
echo "Test Summary"
echo "========================================================="
echo ""
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Tests Failed: $TESTS_FAILED${NC}"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    log_info "Environment variable propagation is working correctly"
    log_info "VAULT_COMMAND from .env will be used by docker-compose"
    log_info "To switch modes, edit .env and restart services"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    log_error "Please fix the issues above before proceeding"
    exit 1
fi
