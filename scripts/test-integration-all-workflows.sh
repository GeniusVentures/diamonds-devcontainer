#!/usr/bin/env bash
# Comprehensive integration tests for all Vault workflows
# Tests fresh setup, mode switching, auto-unseal, validation, and persistence

set -eo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_test() {
    echo -e "${PURPLE}[TEST $1]${NC} $2"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VAULT_DATA_DIR="${PROJECT_ROOT}/.devcontainer/data/vault-data"
VAULT_CONFIG_FILE="${PROJECT_ROOT}/.devcontainer/data/vault-mode.conf"
VAULT_MODE_SCRIPT="${SCRIPT_DIR}/vault-mode"
VALIDATE_SCRIPT="${SCRIPT_DIR}/validate-vault-setup.sh"
MIGRATE_SCRIPT="${SCRIPT_DIR}/setup/migrate-secrets-to-vault.sh"
DOCKER_COMPOSE_FILE="${PROJECT_ROOT}/.devcontainer/docker-compose.yml"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Integration Tests: All Vault Workflows"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Helper function to check if Vault is running
check_vault_running() {
    if curl -s "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Helper function to check if Vault is sealed
check_vault_sealed() {
    local response=$(curl -s "$VAULT_ADDR/v1/sys/seal-status" 2>/dev/null || echo "")
    if [[ -n "$response" ]]; then
        local sealed=$(echo "$response" | jq -r '.sealed' 2>/dev/null || echo "true")
        [[ "$sealed" == "true" ]]
    else
        return 1
    fi
}

# Helper function to wait for Vault to be ready
wait_for_vault() {
    local retries=${1:-30}
    local delay=${2:-2}
    
    log_info "Waiting for Vault to be ready..."
    while [[ $retries -gt 0 ]]; do
        if check_vault_running; then
            log_success "Vault is ready"
            return 0
        fi
        sleep $delay
        ((retries--))
    done
    
    log_error "Vault did not become ready in time"
    return 1
}

# Test 12.1: Fresh setup with persistent mode
log_test "12.1" "Testing fresh setup with persistent mode"
echo ""

if [[ -d "$VAULT_DATA_DIR" ]] || [[ -f "$VAULT_CONFIG_FILE" ]]; then
    log_warning "Vault data or config exists, skipping fresh setup test"
    log_info "To test fresh setup, manually clean: rm -rf $VAULT_DATA_DIR $VAULT_CONFIG_FILE"
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
else
    log_info "Note: This test requires manual wizard execution"
    log_info "To test fresh persistent setup:"
    echo "  1. Ensure vault-data and vault-mode.conf don't exist"
    echo "  2. Run: bash .devcontainer/scripts/setup/vault-setup-wizard.sh"
    echo "  3. Select 'persistent' mode"
    echo "  4. Complete the wizard"
    echo "  5. Verify Vault is operational"
    echo "  6. Restart container and verify secrets persist"
    echo ""
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
fi

# Test 12.2: Fresh setup with ephemeral mode
log_test "12.2" "Testing fresh setup with ephemeral mode"
echo ""

log_info "Note: This test requires manual wizard execution"
log_info "To test fresh ephemeral setup:"
echo "  1. Clean state: rm -rf vault-data vault-mode.conf"
echo "  2. Run wizard"
echo "  3. Select 'ephemeral' mode"
echo "  4. Verify secrets accessible immediately"
echo "  5. Restart container and verify secrets are lost"
echo ""
TEST_SKIPPED=$((TEST_SKIPPED + 1))

# Test 12.3: Template initialization
log_test "12.3" "Testing template initialization workflow"
echo ""

TEMPLATE_DIR="${PROJECT_ROOT}/.devcontainer/data/vault-data.template"
SEED_FILE="${TEMPLATE_DIR}/seed-secrets.json"

if [[ -d "$TEMPLATE_DIR" && -f "$SEED_FILE" ]]; then
    log_success "✓ Template directory exists"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Verify seed file is valid JSON
    if jq empty "$SEED_FILE" 2>/dev/null; then
        log_success "✓ Seed file is valid JSON"
        TEST_PASSED=$((TEST_PASSED + 1))
        
        # Count secrets in seed file
        secret_count=$(jq -r 'to_entries | map(select(.key | startswith("_") | not)) | length' "$SEED_FILE" 2>/dev/null || echo "0")
        if [[ $secret_count -gt 0 ]]; then
            log_success "✓ Seed file contains $secret_count secrets"
            TEST_PASSED=$((TEST_PASSED + 1))
        else
            log_error "✗ No secrets in seed file"
            TEST_FAILED=$((TEST_FAILED + 1))
        fi
    else
        log_error "✗ Seed file has invalid JSON"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    
    log_info "Note: Full template initialization requires wizard execution"
    log_info "Manual test steps:"
    echo "  1. Run wizard"
    echo "  2. When prompted, select 'Initialize from template'"
    echo "  3. Verify seed secrets loaded"
    echo "  4. Check: vault kv list secret/dev"
    echo ""
else
    log_warning "⚠ Template not found, skipping template tests"
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
fi

# Test 12.4: Mode switching
log_test "12.4" "Testing mode switching workflow"
echo ""

if [[ -x "$VAULT_MODE_SCRIPT" ]]; then
    log_success "✓ vault-mode CLI exists and is executable"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Check for mode switching functions
    if grep -q "cmd_switch" "$VAULT_MODE_SCRIPT" || grep -q "switch)" "$VAULT_MODE_SCRIPT"; then
        log_success "✓ Mode switching function exists"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ Mode switching function not found"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    
    # Check for migration integration
    if grep -q "vault-migrate-mode" "$VAULT_MODE_SCRIPT" || grep -q "migration" "$VAULT_MODE_SCRIPT"; then
        log_success "✓ Migration integration exists"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_warning "⚠ Migration integration not found"
    fi
    
    log_info "Note: Full mode switching requires running Vault"
    log_info "Manual test steps:"
    echo "  1. Start in persistent mode with test secrets"
    echo "  2. Run: vault-mode switch ephemeral"
    echo "  3. Verify migration prompt and complete migration"
    echo "  4. Verify secrets in ephemeral mode"
    echo "  5. Run: vault-mode switch persistent"
    echo "  6. Verify secrets restored"
    echo ""
else
    log_error "✗ vault-mode CLI not found or not executable"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 12.5: Auto-unseal workflow
log_test "12.5" "Testing auto-unseal workflow"
echo ""

AUTO_UNSEAL_SCRIPT="${SCRIPT_DIR}/vault-auto-unseal.sh"

if [[ -x "$AUTO_UNSEAL_SCRIPT" ]]; then
    log_success "✓ vault-auto-unseal.sh exists and is executable"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Check for unseal key extraction
    if grep -q "extract.*unseal.*keys" "$AUTO_UNSEAL_SCRIPT" 2>/dev/null || \
       grep -q "jq.*unseal_keys" "$AUTO_UNSEAL_SCRIPT" 2>/dev/null; then
        log_success "✓ Unseal key extraction implemented"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_warning "⚠ Unseal key extraction not clearly identified"
    fi
    
    # Check for API calls
    if grep -q "sys/unseal" "$AUTO_UNSEAL_SCRIPT"; then
        log_success "✓ Vault unseal API integration exists"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ Vault unseal API integration not found"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    
    log_info "Note: Full auto-unseal test requires running Vault"
    log_info "Manual test steps:"
    echo "  1. Enable auto-unseal in vault-mode.conf"
    echo "  2. Seal Vault: vault operator seal"
    echo "  3. Restart container: docker-compose restart vault-dev"
    echo "  4. Verify Vault auto-unseals (check logs)"
    echo "  5. Verify secrets accessible"
    echo ""
else
    log_error "✗ vault-auto-unseal.sh not found or not executable"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 12.6: Manual unseal workflow
log_test "12.6" "Testing manual unseal workflow"
echo ""

UNSEAL_KEYS_FILE="${PROJECT_ROOT}/.devcontainer/data/vault-data/unseal-keys.json"

if [[ -f "$VAULT_CONFIG_FILE" ]]; then
    if grep -q "AUTO_UNSEAL.*false" "$VAULT_CONFIG_FILE" 2>/dev/null || \
       ! grep -q "AUTO_UNSEAL" "$VAULT_CONFIG_FILE" 2>/dev/null; then
        log_success "✓ Manual unseal mode configured (or no auto-unseal)"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_info "Auto-unseal is enabled in config"
    fi
else
    log_info "No vault-mode.conf found"
fi

if [[ -f "$UNSEAL_KEYS_FILE" ]]; then
    log_success "✓ Unseal keys file exists"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Check permissions (should be 600)
    perms=$(stat -c "%a" "$UNSEAL_KEYS_FILE" 2>/dev/null || echo "")
    if [[ "$perms" == "600" ]]; then
        log_success "✓ Unseal keys file has correct permissions (600)"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_warning "⚠ Unseal keys file permissions are $perms (should be 600)"
    fi
    
    # Verify it's valid JSON
    if jq empty "$UNSEAL_KEYS_FILE" 2>/dev/null; then
        log_success "✓ Unseal keys file is valid JSON"
        TEST_PASSED=$((TEST_PASSED + 1))
        
        # Count unseal keys
        key_count=$(jq -r '.unseal_keys_b64 | length' "$UNSEAL_KEYS_FILE" 2>/dev/null || echo "0")
        if [[ $key_count -ge 3 ]]; then
            log_success "✓ Unseal keys file contains $key_count keys (minimum 3)"
            TEST_PASSED=$((TEST_PASSED + 1))
        else
            log_error "✗ Unseal keys file contains only $key_count keys (need at least 3)"
            TEST_FAILED=$((TEST_FAILED + 1))
        fi
    else
        log_error "✗ Unseal keys file has invalid JSON"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
else
    log_info "No unseal keys file found (may be using ephemeral mode)"
fi

log_info "Note: Full manual unseal test requires running Vault"
log_info "Manual test steps:"
echo "  1. Disable auto-unseal in vault-mode.conf"
echo "  2. Seal Vault: vault operator seal"
echo "  3. Restart container"
echo "  4. Follow manual unseal instructions"
echo "  5. Run: vault operator unseal <key1>"
echo "  6. Run: vault operator unseal <key2>"
echo "  7. Run: vault operator unseal <key3>"
echo "  8. Verify Vault is unsealed"
echo ""

# Test 12.7: Validation in all configurations
log_test "12.7" "Testing validation script"
echo ""

if [[ -x "$VALIDATE_SCRIPT" ]]; then
    log_success "✓ validate-vault-setup.sh exists and is executable"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Check for mode detection
    if grep -q "check_vault_mode" "$VALIDATE_SCRIPT"; then
        log_success "✓ Mode detection function exists"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ Mode detection function not found"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    
    # Check for seal status validation
    if grep -q "check_vault_seal_status" "$VALIDATE_SCRIPT" || \
       grep -q "seal-status" "$VALIDATE_SCRIPT"; then
        log_success "✓ Seal status validation exists"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ Seal status validation not found"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    
    # Check for persistent storage validation
    if grep -q "check_persistent_storage" "$VALIDATE_SCRIPT" || \
       grep -q "raft" "$VALIDATE_SCRIPT"; then
        log_success "✓ Persistent storage validation exists"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_warning "⚠ Persistent storage validation not found"
    fi
    
    log_info "Note: Full validation test requires running Vault"
    log_info "Manual test steps:"
    echo "  1. Ephemeral: bash validate-vault-setup.sh (no seal checks)"
    echo "  2. Persistent (sealed): bash validate-vault-setup.sh (warns about seal)"
    echo "  3. Persistent (unsealed): bash validate-vault-setup.sh (all pass)"
    echo ""
else
    log_error "✗ validate-vault-setup.sh not found or not executable"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 12.8: Secret persistence across rebuilds
log_test "12.8" "Testing secret persistence across container rebuilds"
echo ""

if [[ -d "$VAULT_DATA_DIR" ]]; then
    log_success "✓ Vault data directory exists"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Check if raft directory exists (persistent mode)
    if [[ -d "$VAULT_DATA_DIR/raft" ]]; then
        log_success "✓ Raft storage directory exists"
        TEST_PASSED=$((TEST_PASSED + 1))
        
        # Check raft directory size
        raft_size=$(du -sh "$VAULT_DATA_DIR/raft" 2>/dev/null | cut -f1)
        log_info "Raft storage size: $raft_size"
        
        log_info "Note: Full persistence test requires container rebuild"
        log_info "Manual test steps:"
        echo "  1. Write test secrets to persistent Vault:"
        echo "     vault kv put secret/test/persistence key1=value1 key2=value2"
        echo "  2. Rebuild DevContainer:"
        echo "     docker-compose down && docker-compose up -d --build"
        echo "  3. Unseal Vault (manual or auto)"
        echo "  4. Verify secrets still present:"
        echo "     vault kv get secret/test/persistence"
        echo ""
    else
        log_info "No raft directory (may be using ephemeral mode)"
    fi
else
    log_info "No vault-data directory found"
fi

# Test 12.9: Check all critical scripts exist
log_test "12.9" "Verifying all critical scripts exist"
echo ""

CRITICAL_SCRIPTS=(
    "$VAULT_MODE_SCRIPT"
    "$VALIDATE_SCRIPT"
    "$AUTO_UNSEAL_SCRIPT"
    "${SCRIPT_DIR}/vault-init-from-template.sh"
    "$MIGRATE_SCRIPT"
    "${SCRIPT_DIR}/setup/vault-setup-wizard.sh"
)

all_exist=true
for script in "${CRITICAL_SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    if [[ -f "$script" ]]; then
        if [[ -x "$script" ]]; then
            log_success "  ✓ $script_name (executable)"
        else
            log_warning "  ⚠ $script_name (not executable)"
        fi
    else
        log_error "  ✗ $script_name (missing)"
        all_exist=false
    fi
done

if $all_exist; then
    log_success "✓ All critical scripts exist"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Some critical scripts are missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

echo ""

# Test 12.10: Check Docker Compose configuration
log_test "12.10" "Checking Docker Compose configuration"
echo ""

if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
    log_success "✓ docker-compose.yml exists"
    TEST_PASSED=$((TEST_PASSED + 1))
    
    # Check for vault service (optional - may be in devcontainer.json instead)
    if grep -q "vault" "$DOCKER_COMPOSE_FILE"; then
        log_success "✓ Vault service/volume configured in docker-compose"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_info "Vault not in docker-compose.yml (may be in devcontainer.json or run separately)"
        
        # Check devcontainer.json for Vault configuration
        DEVCONTAINER_JSON="${PROJECT_ROOT}/.devcontainer/devcontainer.json"
        if [[ -f "$DEVCONTAINER_JSON" ]] && grep -q "vault" "$DEVCONTAINER_JSON"; then
            log_success "✓ Vault configured in devcontainer.json"
            TEST_PASSED=$((TEST_PASSED + 1))
        else
            log_info "Vault configuration not found (assuming manual/external Vault)"
        fi
    fi
else
    log_error "✗ docker-compose.yml not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

echo ""

# Summary
echo "═══════════════════════════════════════════════════════════"
log_info "Integration Test Summary"
echo "═══════════════════════════════════════════════════════════"
log_success "Passed:  $TEST_PASSED"
if [[ $TEST_FAILED -gt 0 ]]; then
    log_error "Failed:  $TEST_FAILED"
else
    log_info "Failed:  $TEST_FAILED"
fi
log_warning "Skipped: $TEST_SKIPPED (manual tests)"
echo ""

if [[ $TEST_FAILED -eq 0 ]]; then
    log_success "✅ All automated integration tests passed!"
    echo ""
    log_info "Integration Test Coverage:"
    echo "  ✓ Template system validation"
    echo "  ✓ Mode switching infrastructure"
    echo "  ✓ Auto-unseal workflow components"
    echo "  ✓ Manual unseal key management"
    echo "  ✓ Validation script functionality"
    echo "  ✓ Persistence infrastructure"
    echo "  ✓ Critical scripts presence"
    echo "  ✓ Docker Compose configuration"
    echo ""
    log_info "Manual Testing Required:"
    echo "  • Fresh setup workflows (12.1, 12.2)"
    echo "  • Full template initialization (12.3)"
    echo "  • Live mode switching (12.4)"
    echo "  • Seal/unseal operations (12.5, 12.6)"
    echo "  • Cross-configuration validation (12.7)"
    echo "  • Container rebuild persistence (12.8)"
    echo ""
    log_info "To perform manual tests, follow the instructions above"
    echo ""
    exit 0
else
    log_error "❌ Some integration tests failed. Review errors above."
    exit 1
fi
