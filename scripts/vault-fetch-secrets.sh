#!/bin/bash
# Vault Secret Fetcher for GNUS-DAO DevContainer
# Retrieves secrets from HashiCorp Vault and exports them as environment variables

set -e

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://vault-dev:8200}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
ENV_FILE="${ENV_FILE:-../.env}"
FALLBACK_TO_ENV="${FALLBACK_TO_ENV:-true}"

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

# Check if Vault is available
check_vault_availability() {
    if curl -s "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Authenticate with Vault using GitHub token
authenticate_with_github() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GITHUB_TOKEN not set. Cannot authenticate with Vault."
        return 1
    fi

    log_info "Authenticating with Vault using GitHub token..."

    # Attempt GitHub authentication
    local auth_response
    auth_response=$(vault login -method=github token="$GITHUB_TOKEN" -format=json 2>/dev/null) || {
        log_error "GitHub authentication failed"
        return 1
    }

    # Extract token from response
    VAULT_TOKEN=$(echo "$auth_response" | jq -r '.auth.client_token // empty')

    if [ -z "$VAULT_TOKEN" ]; then
        log_error "Failed to extract Vault token from authentication response"
        return 1
    fi

    export VAULT_TOKEN
    log_success "Successfully authenticated with Vault"
}

# Fetch secret from Vault
fetch_secret() {
    local secret_path="$1"
    local secret_key="$2"

    local secret_value
    secret_value=$(vault kv get -field="$secret_key" "$secret_path" 2>/dev/null) || {
        log_warning "Failed to fetch secret: $secret_path:$secret_key"
        return 1
    }

    echo "$secret_value"
}

# Load secrets from Vault
load_vault_secrets() {
    log_info "Loading secrets from Vault..."

    # Define secrets to fetch (path:key)
    local secrets=(
        "secret/dev/PRIVATE_KEY:PRIVATE_KEY"
        "secret/dev/TEST_PRIVATE_KEY:TEST_PRIVATE_KEY"
        "secret/dev/RPC_URL:MAINNET_RPC"
        "secret/dev/INFURA_API_KEY:INFURA_API_KEY"
        "secret/dev/ALCHEMY_API_KEY:ALCHEMY_API_KEY"
        "secret/dev/ETHERSCAN_API_KEY:ETHERSCAN_API_KEY"
        "secret/dev/GITHUB_TOKEN:GITHUB_TOKEN"
        "secret/dev/SNYK_TOKEN:SNYK_TOKEN"
        "secret/dev/SOCKET_CLI_API_TOKEN:SOCKET_CLI_API_TOKEN"
    )

    local loaded_count=0
    local failed_count=0

    for secret_spec in "${secrets[@]}"; do
        IFS=':' read -r secret_path secret_key <<< "$secret_spec"
        local env_var_name="$secret_key"

        local secret_value
        if secret_value=$(fetch_secret "$secret_path" "$secret_key"); then
            export "$env_var_name"="$secret_value"
            log_info "Loaded $env_var_name from Vault"
            ((loaded_count++))
        else
            log_warning "Failed to load $env_var_name from Vault"
            ((failed_count++))
        fi
    done

    log_success "Loaded $loaded_count secrets from Vault ($failed_count failed)"
}

# Fallback to .env file
fallback_to_env() {
    if [ "$FALLBACK_TO_ENV" != "true" ]; then
        log_info "Fallback to .env disabled"
        return 0
    fi

    if [ ! -f "$ENV_FILE" ]; then
        log_warning "Fallback .env file not found: $ENV_FILE"
        return 1
    fi

    log_warning "Falling back to .env file for missing secrets..."

    # Source the .env file
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a

    log_success "Loaded secrets from .env file"
}

# Validate critical secrets
validate_critical_secrets() {
    local critical_secrets=("PRIVATE_KEY" "TEST_PRIVATE_KEY")
    local missing_critical=()

    for secret in "${critical_secrets[@]}"; do
        if [ -z "${!secret:-}" ]; then
            missing_critical+=("$secret")
        fi
    done

    if [ ${#missing_critical[@]} -gt 0 ]; then
        log_error "Critical secrets missing: ${missing_critical[*]}"
        log_error "Cannot continue without critical secrets"
        return 1
    fi

    log_success "All critical secrets are available"
}

# Export secrets to environment file for persistence
export_to_env_file() {
    local env_output_file="${ENV_OUTPUT_FILE:-/etc/environment.d/vault-secrets}"

    log_info "Exporting secrets to $env_output_file..."

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$env_output_file")"

    # Export secrets (excluding sensitive ones from logging)
    {
        echo "# Vault secrets exported on $(date)"
        echo "export PRIVATE_KEY=\"$PRIVATE_KEY\""
        echo "export TEST_PRIVATE_KEY=\"$TEST_PRIVATE_KEY\""
        echo "export MAINNET_RPC=\"$MAINNET_RPC\""
        echo "export INFURA_API_KEY=\"$INFURA_API_KEY\""
        echo "export ALCHEMY_API_KEY=\"$ALCHEMY_API_KEY\""
        echo "export ETHERSCAN_API_KEY=\"$ETHERSCAN_API_KEY\""
        echo "export GITHUB_TOKEN=\"$GITHUB_TOKEN\""
        echo "export SNYK_TOKEN=\"$SNYK_TOKEN\""
        echo "export SOCKET_CLI_API_TOKEN=\"$SOCKET_CLI_API_TOKEN\""
    } > "$env_output_file"

    log_success "Secrets exported to $env_output_file"
}

# Main function
main() {
    log_info "Starting Vault secret retrieval..."

    # Check if Vault is available
    if ! check_vault_availability; then
        log_warning "Vault is not available at $VAULT_ADDR"
        fallback_to_env
        validate_critical_secrets
        return $?
    fi

    # Authenticate with Vault
    if ! authenticate_with_github; then
        log_warning "Vault authentication failed, falling back to .env"
        fallback_to_env
        validate_critical_secrets
        return $?
    fi

    # Load secrets from Vault
    load_vault_secrets

    # Fallback to .env for any missing secrets
    fallback_to_env

    # Validate that we have critical secrets
    if ! validate_critical_secrets; then
        return 1
    fi

    # Export secrets for persistence
    export_to_env_file

    log_success "Vault secret retrieval completed successfully!"
    log_info "Secrets are now available as environment variables"
}

# Run main function
main "$@"