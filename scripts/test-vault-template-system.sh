#!/usr/bin/env bash
# Test script for Vault template system
# Tests template initialization functionality

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
TEMPLATE_DIR="${SCRIPT_DIR}/../data/vault-data.template"
INIT_SCRIPT="${SCRIPT_DIR}/vault-init-from-template.sh"
TEST_PASSED=0
TEST_FAILED=0

echo "═══════════════════════════════════════════════════════════"
log_info "Test: Vault Template System"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test 1: Check template directory exists
log_info "Test 1: Checking template directory..."

if [[ -d "$TEMPLATE_DIR" ]]; then
    log_success "✓ Template directory exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Template directory not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 2: Check README.md exists
log_info "Test 2: Checking template README..."

if [[ -f "$TEMPLATE_DIR/README.md" ]]; then
    log_success "✓ README.md exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ README.md not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 3: Check README content
log_info "Test 3: Validating README content..."

if [[ -f "$TEMPLATE_DIR/README.md" ]]; then
    if grep -q "Quick Start" "$TEMPLATE_DIR/README.md" && \
       grep -q "Customizing Secrets" "$TEMPLATE_DIR/README.md" && \
       grep -q "Security Best Practices" "$TEMPLATE_DIR/README.md"; then
        log_success "✓ README has all required sections"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ README missing required sections"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
fi

# Test 4: Check seed-secrets.json exists
log_info "Test 4: Checking seed-secrets.json..."

if [[ -f "$TEMPLATE_DIR/seed-secrets.json" ]]; then
    log_success "✓ seed-secrets.json exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ seed-secrets.json not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 5: Validate JSON format
log_info "Test 5: Validating JSON format..."

if [[ -f "$TEMPLATE_DIR/seed-secrets.json" ]]; then
    if jq empty "$TEMPLATE_DIR/seed-secrets.json" 2>/dev/null; then
        log_success "✓ seed-secrets.json is valid JSON"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ seed-secrets.json has invalid JSON"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
fi

# Test 6: Check for required secret paths
log_info "Test 6: Checking required secret paths..."

required_secrets=(
    "secret/dev/DEFENDER_API_KEY"
    "secret/dev/ETHERSCAN_API_KEY"
    "secret/test/TEST_PRIVATE_KEY"
)

all_found=true
for secret in "${required_secrets[@]}"; do
    if jq -e ".\"$secret\"" "$TEMPLATE_DIR/seed-secrets.json" >/dev/null 2>&1; then
        log_success "  ✓ $secret"
    else
        log_error "  ✗ $secret not found"
        all_found=false
    fi
done

if $all_found; then
    TEST_PASSED=$((TEST_PASSED + 1))
else
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 7: Check for placeholder values
log_info "Test 7: Checking for placeholder values (not real secrets)..."

if jq -r '.[].value' "$TEMPLATE_DIR/seed-secrets.json" 2>/dev/null | grep -q "REPLACE_WITH"; then
    log_success "✓ Contains placeholder values (safe to commit)"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ No REPLACE_WITH placeholders found"
fi

# Test 8: Check init script exists
log_info "Test 8: Checking vault-init-from-template.sh..."

if [[ -f "$INIT_SCRIPT" ]]; then
    log_success "✓ vault-init-from-template.sh exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-init-from-template.sh not found"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 9: Check script is executable
log_info "Test 9: Checking script permissions..."

if [[ -x "$INIT_SCRIPT" ]]; then
    log_success "✓ vault-init-from-template.sh is executable"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ vault-init-from-template.sh is not executable"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 10: Check for error handling in script
log_info "Test 10: Checking error handling in init script..."

if grep -q "set -euo pipefail" "$INIT_SCRIPT"; then
    log_success "✓ Error handling enabled"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Error handling not enabled"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 11: Check for template directory validation
log_info "Test 11: Checking template directory validation..."

if grep -q "Template directory not found" "$INIT_SCRIPT"; then
    log_success "✓ Validates template directory exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Template directory validation missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 12: Check for seed file validation
log_info "Test 12: Checking seed file validation..."

if grep -q "Seed secrets file not found" "$INIT_SCRIPT"; then
    log_success "✓ Validates seed file exists"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Seed file validation missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 13: Check for JSON validation
log_info "Test 13: Checking JSON validation..."

if grep -q "jq empty" "$INIT_SCRIPT"; then
    log_success "✓ Validates JSON format"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ JSON validation missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 14: Check for Vault connectivity check
log_info "Test 14: Checking Vault connectivity validation..."

if grep -q "Cannot connect to Vault" "$INIT_SCRIPT"; then
    log_success "✓ Checks Vault connectivity"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Vault connectivity check missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 15: Check for seal status check
log_info "Test 15: Checking seal status validation..."

if grep -q "Vault is sealed" "$INIT_SCRIPT"; then
    log_success "✓ Checks if Vault is sealed"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Seal status check missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 16: Check for confirmation prompt
log_info "Test 16: Checking user confirmation prompt..."

if grep -q "read -p.*Continue" "$INIT_SCRIPT"; then
    log_success "✓ Prompts for user confirmation"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Confirmation prompt missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 17: Check for secret count reporting
log_info "Test 17: Checking secret count reporting..."

if grep -q "secret_count" "$INIT_SCRIPT" || grep -q "Found.*secrets" "$INIT_SCRIPT"; then
    log_success "✓ Reports number of secrets"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Secret count reporting missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 18: Check for success/failure tracking
log_info "Test 18: Checking success/failure tracking..."

if grep -q "loaded_count" "$INIT_SCRIPT" && grep -q "failed_count" "$INIT_SCRIPT"; then
    log_success "✓ Tracks success and failure counts"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Success/failure tracking missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 19: Check for instructions after loading
log_info "Test 19: Checking post-load instructions..."

if grep -q "Replace placeholder values" "$INIT_SCRIPT"; then
    log_success "✓ Provides instructions after loading"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Post-load instructions missing"
    TEST_FAILED=$((TEST_FAILED + 1))
fi

# Test 20: Check for metadata field skipping
log_info "Test 20: Checking metadata field handling..."

if grep -q "_\*" "$INIT_SCRIPT" || grep -q "startswith.*_" "$INIT_SCRIPT"; then
    log_success "✓ Skips metadata fields (fields starting with _)"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_warning "⚠ Metadata field skipping not found"
fi

# Test 21: Count secrets in seed file
log_info "Test 21: Counting secrets in seed file..."

if [[ -f "$TEMPLATE_DIR/seed-secrets.json" ]]; then
    secret_count=$(jq -r 'to_entries | map(select(.key | startswith("_") | not)) | length' "$TEMPLATE_DIR/seed-secrets.json" 2>/dev/null || echo "0")
    if [[ $secret_count -gt 0 ]]; then
        log_success "✓ Seed file contains $secret_count secrets"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        log_error "✗ No secrets found in seed file"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
fi

# Test 22: Check for security warnings in README
log_info "Test 22: Checking security documentation..."

if grep -q "Security Best Practices" "$TEMPLATE_DIR/README.md" && \
   grep -q "Never commit actual secrets" "$TEMPLATE_DIR/README.md"; then
    log_success "✓ README includes security best practices"
    TEST_PASSED=$((TEST_PASSED + 1))
else
    log_error "✗ Security documentation missing"
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
    log_success "✅ All tests passed! Template system properly implemented."
    echo ""
    log_info "Template System Features:"
    echo "  1. ✓ Template directory with README"
    echo "  2. ✓ seed-secrets.json with placeholders"
    echo "  3. ✓ vault-init-from-template.sh script"
    echo "  4. ✓ JSON validation"
    echo "  5. ✓ Vault connectivity checks"
    echo "  6. ✓ Seal status validation"
    echo "  7. ✓ User confirmation prompts"
    echo "  8. ✓ Success/failure tracking"
    echo "  9. ✓ Post-load instructions"
    echo " 10. ✓ Security documentation"
    echo ""
    log_info "Template Structure:"
    echo "  .devcontainer/data/vault-data.template/"
    echo "  ├── README.md (comprehensive documentation)"
    echo "  └── seed-secrets.json (placeholder secrets)"
    echo ""
    log_info "Initialization Script:"
    echo "  .devcontainer/scripts/vault-init-from-template.sh"
    echo ""
    log_info "Usage:"
    echo "  bash .devcontainer/scripts/vault-init-from-template.sh"
    echo ""
    exit 0
else
    log_error "❌ Some tests failed. Review errors above."
    exit 1
fi
