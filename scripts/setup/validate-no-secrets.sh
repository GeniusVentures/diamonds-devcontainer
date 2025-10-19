#!/bin/bash
# validate-no-secrets.sh
# Script to validate that no secrets remain in the repository after Vault migration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check .env file specifically
check_env_file() {
    local env_file="${PROJECT_ROOT}/.devcontainer/.env"
    local issues_found=0

    if [[ ! -f "$env_file" ]]; then
        log_info ".env file not found - this is expected after migration"
        return 0
    fi

    log_info "Checking .env file for secrets..."

    # Read .env file and check each line
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        if [[ "$key" =~ ^[[:space:]]*# ]] || [[ -z "$key" ]]; then
            continue
        fi

        # Trim whitespace
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        # Check if this looks like a secret
        if [[ "$value" == sk_* ]] || [[ "$value" == pk_* ]] || [[ "$value" == xoxp_* ]] || \
           [[ "$value" == xoxb_* ]] || [[ "$value" == ghp_* ]] || \
           [[ "$value" =~ ^0x[0-9a-fA-F]{64}$ ]] || \
           [[ "$key" == *PRIVATE_KEY* ]] || [[ "$key" == *SECRET* ]] || \
           [[ "$key" == *TOKEN* ]] || [[ "$key" == *KEY* ]] || [[ "$key" == *PASSWORD* ]]; then
            log_error "Secret found in .env file: ${key}=${value:0:10}..."
            ((issues_found++))
        fi
    done < "$env_file"

    if [[ $issues_found -eq 0 ]]; then
        log_success ".env file contains no secrets"
    fi

    return $issues_found
}

# Main function
main() {
    log_info "Secret Validation"
    log_info "=========================="

    local total_issues=0

    # Check .env file specifically
    if ! check_env_file; then
        ((total_issues++))
    fi

    echo ""

    if [[ $total_issues -eq 0 ]]; then
        log_success "✅ Secret validation passed! No secrets found in repository."
        log_info "Your repository is secure and ready for commit."
        exit 0
    else
        log_error "❌ Secret validation failed! $total_issues issues found."
        log_error "Please migrate secrets to Vault or remove them from the repository."
        log_info "To migrate secrets: .devcontainer/scripts/setup/migrate-secrets-to-vault.sh"
        exit 1
    fi
}

# Run main function
main "$@"