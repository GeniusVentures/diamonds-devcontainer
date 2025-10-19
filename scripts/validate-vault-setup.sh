#!/bin/bash
# validate-vault-setup.sh
# Comprehensive script to validate HashiCorp Vault setup and configuration
# This script performs detailed checks of Vault connectivity, authentication, policies, and secrets

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
CHECKS_TOTAL=0
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((CHECKS_PASSED++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((CHECKS_WARNING++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((CHECKS_FAILED++))
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to increment total checks
check_start() {
    ((CHECKS_TOTAL++))
}

# Function to check Vault CLI installation
check_vault_cli() {
    log_info "Checking Vault CLI installation..."
    check_start

    if command_exists vault; then
        local version
        version=$(vault version 2>/dev/null || echo "unknown")
        log_success "Vault CLI installed: $version"
        return 0
    else
        log_error "Vault CLI not found. Install from: https://www.vaultproject.io/downloads"
        return 1
    fi
}

# Function to check Vault server connectivity
check_vault_connectivity() {
    log_info "Checking Vault server connectivity..."
    check_start

    if [[ -z "${VAULT_ADDR:-}" ]]; then
        log_error "VAULT_ADDR environment variable not set"
        return 1
    fi

    log_info "Vault address: $VAULT_ADDR"

    if ! curl -s --max-time 5 "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
        log_error "Cannot connect to Vault at $VAULT_ADDR"
        log_info "Make sure Vault is running: docker-compose up vault-dev"
        return 1
    fi

    log_success "Vault server is accessible"
    return 0
}

# Function to check Vault initialization status
check_vault_status() {
    log_info "Checking Vault initialization status..."
    check_start

    local status_output
    if ! status_output=$(vault status 2>/dev/null); then
        log_error "Cannot get Vault status"
        return 1
    fi

    if echo "$status_output" | grep -q "Initialized.*true"; then
        log_success "Vault is initialized"
    else
        log_error "Vault is not initialized"
        log_info "Initialize Vault with: vault operator init"
        return 1
    fi

    if echo "$status_output" | grep -q "Sealed.*false"; then
        log_success "Vault is unsealed"
    else
        log_error "Vault is sealed"
        log_info "Unseal Vault with: vault operator unseal"
        return 1
    fi

    return 0
}

# Function to check Vault authentication
check_vault_auth() {
    log_info "Checking Vault authentication..."
    check_start

    # Check for authentication token
    local token_found=false

    if [[ -n "${VAULT_TOKEN:-}" ]]; then
        token_found=true
        log_info "VAULT_TOKEN environment variable is set"
    fi

    if [[ -f ~/.vault-token ]]; then
        token_found=true
        log_info "Vault token file found: ~/.vault-token"
    fi

    if [[ -f .vault-token ]]; then
        token_found=true
        log_info "Vault token file found: .vault-token"
    fi

    if [[ -f .devcontainer/.vault-token ]]; then
        token_found=true
        log_info "Vault token file found: .devcontainer/.vault-token"
    fi

    if [[ "$token_found" == "false" ]]; then
        log_error "No Vault authentication token found"
        log_info "Authenticate with: vault login -method=github token=\$(gh auth token)"
        return 1
    fi

    # Test authentication by trying to get token info
    if vault token lookup >/dev/null 2>&1; then
        log_success "Vault authentication is valid"
        return 0
    else
        log_error "Vault authentication failed"
        log_info "Re-authenticate with: vault login -method=github token=\$(gh auth token)"
        return 1
    fi
}

# Function to check Vault policies
check_vault_policies() {
    log_info "Checking Vault policies..."
    check_start

    local policies
    policies=$(vault policy list 2>/dev/null | tail -n +3 || echo "")

    if [[ -z "$policies" ]]; then
        log_warning "No policies found in Vault"
        log_info "Policies may need to be created by vault-init.sh"
        return 0
    fi

    local dev_policy_found=false
    local test_policy_found=false
    local ci_policy_found=false

    while read -r policy; do
        [[ -z "$policy" ]] && continue
        case "$policy" in
            *dev*) dev_policy_found=true ;;
            *test*) test_policy_found=true ;;
            *ci*) ci_policy_found=true ;;
        esac
    done <<< "$policies"

    if [[ "$dev_policy_found" == "true" ]]; then
        log_success "Development policy found"
    else
        log_warning "Development policy not found"
    fi

    if [[ "$test_policy_found" == "true" ]]; then
        log_success "Test policy found"
    else
        log_warning "Test policy not found"
    fi

    if [[ "$ci_policy_found" == "true" ]]; then
        log_success "CI policy found"
    else
        log_warning "CI policy not found"
    fi

    return 0
}

# Function to check Vault secrets
check_vault_secrets() {
    log_info "Checking Vault secrets..."
    check_start

    local secret_paths=("secret/dev" "secret/test" "secret/ci")
    local secrets_found=false

    for path in "${secret_paths[@]}"; do
        log_info "Checking path: $path"
        if vault kv list "$path" >/dev/null 2>&1; then
            local secret_count
            secret_count=$(vault kv list "$path" 2>/dev/null | tail -n +3 | wc -l)
            if [[ $secret_count -gt 0 ]]; then
                log_success "Found $secret_count secrets in $path"
                secrets_found=true
            else
                log_info "Path $path exists but is empty"
            fi
        else
            log_info "Path $path not accessible or does not exist"
        fi
    done

    if [[ "$secrets_found" == "true" ]]; then
        log_success "Vault secrets are configured"
        return 0
    else
        log_warning "No secrets found in Vault"
        log_info "Run: ./scripts/setup/migrate-secrets-to-vault.sh to migrate secrets"
        return 0
    fi
}

# Function to check GitHub authentication method
check_github_auth() {
    log_info "Checking GitHub authentication method..."
    check_start

    if vault auth list 2>/dev/null | grep -q "github"; then
        log_success "GitHub authentication method is enabled"
        return 0
    else
        log_warning "GitHub authentication method not found"
        log_info "GitHub auth may need to be configured by vault-init.sh"
        return 0
    fi
}

# Function to check environment variable priority
check_env_priority() {
    log_info "Checking environment variable priority system..."
    check_start

    # This is more of an informational check
    log_info "Environment variable priority: Vault > .env > defaults"
    log_info "This is implemented in vault-fetch-secrets.sh"

    # Check if vault-fetch-secrets.sh exists and is executable
    local fetch_script="./scripts/vault-fetch-secrets.sh"
    if [[ -f "$fetch_script" ]] && [[ -x "$fetch_script" ]]; then
        log_success "Secret fetching script is available"
        return 0
    else
        log_warning "Secret fetching script not found or not executable"
        return 0
    fi
}

# Function to provide recommendations
provide_recommendations() {
    log_info "Vault setup validation completed"

    if [[ $CHECKS_FAILED -gt 0 ]]; then
        echo ""
        log_error "❌ Critical issues found that need immediate attention:"
        echo ""
        log_info "Quick fixes:"
        echo "  1. Install Vault CLI: https://www.vaultproject.io/downloads"
        echo "  2. Start Vault: docker-compose up vault-dev"
        echo "  3. Initialize Vault: ./scripts/vault-init.sh"
        echo "  4. Authenticate: vault login -method=github token=\$(gh auth token)"
        echo "  5. Migrate secrets: ./scripts/setup/migrate-secrets-to-vault.sh"
    fi

    if [[ $CHECKS_WARNING -gt 0 ]]; then
        echo ""
        log_warning "⚠️  Recommendations for optimal setup:"
        echo ""
        log_info "Optional improvements:"
        echo "  - Run full Vault initialization: ./scripts/vault-init.sh"
        echo "  - Verify all policies are created"
        echo "  - Test secret access in your application"
    fi

    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo ""
        log_success "✅ Vault setup validation passed!"
        echo ""
        log_info "Your Vault configuration appears to be working correctly."
        log_info "You can now use secrets securely in your development environment."
    fi
}

# Main function
main() {
    log_info "Vault Setup Validation"
    log_info "==============================="

    # Run all validation checks
    check_vault_cli
    check_vault_connectivity && check_vault_status
    check_vault_auth
    check_github_auth
    check_vault_policies
    check_vault_secrets
    check_env_priority

    # Summary
    echo ""
    log_info "Validation Summary:"
    echo "  Total checks: $CHECKS_TOTAL"
    echo -e "  Passed: ${GREEN}$CHECKS_PASSED${NC}"
    echo -e "  Warnings: ${YELLOW}$CHECKS_WARNING${NC}"
    echo -e "  Failed: ${RED}$CHECKS_FAILED${NC}"

    provide_recommendations

    # Exit with appropriate code
    if [[ $CHECKS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"