#!/bin/bash
# Vault Initialization Script for Diamonds DevContainer
# Initializes HashiCorp Vault dev server with GitHub authentication and policies

set -e

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://vault-dev:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

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

# Wait for Vault to be ready
wait_for_vault() {
    local max_attempts=30
    local attempt=1

    log_info "Waiting for Vault to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
            log_success "Vault is ready!"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts: Vault not ready yet..."
        sleep 2
        ((attempt++))
    done

    log_error "Vault failed to start after $max_attempts attempts"
    return 1
}

# Initialize Vault with GitHub authentication
setup_github_auth() {
    log_info "Setting up GitHub authentication method..."

    # Enable GitHub auth method
    vault auth enable github || {
        log_warning "GitHub auth method already enabled"
    }

    # Configure GitHub auth with organization
    # Note: In a real setup, you would configure this with your actual organization
    vault write auth/github/config \
        organization="GeniusVentures" \
        base_url="" \
        ttl="768h" \
        max_ttl="768h" || {
        log_error "Failed to configure GitHub auth"
        return 1
    }

    log_success "GitHub authentication configured"
}

# Create Vault policies
create_policies() {
    log_info "Creating Vault policies..."

    # Developer policy - read/write access to dev secrets
    cat > /tmp/dev-policy.hcl << EOF
path "secret/dev/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/test/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

    vault policy write dev-policy /tmp/dev-policy.hcl || {
        log_error "Failed to create dev policy"
        return 1
    }

    # CI policy - read access to all secrets, write access to ci secrets
    cat > /tmp/ci-policy.hcl << EOF
path "secret/ci/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/dev/*" {
  capabilities = ["read", "list"]
}

path "secret/test/*" {
  capabilities = ["read", "list"]
}
EOF

    vault policy write ci-policy /tmp/ci-policy.hcl || {
        log_error "Failed to create CI policy"
        return 1
    }

    # Read-only policy for external access
    cat > /tmp/read-policy.hcl << EOF
path "secret/dev/*" {
  capabilities = ["read", "list"]
}

path "secret/test/*" {
  capabilities = ["read", "list"]
}

path "secret/ci/*" {
  capabilities = ["read", "list"]
}
EOF

    vault policy write read-policy /tmp/read-policy.hcl || {
        log_error "Failed to create read policy"
        return 1
    }

    # Clean up temporary files
    rm -f /tmp/dev-policy.hcl /tmp/ci-policy.hcl /tmp/read-policy.hcl

    log_success "Vault policies created"
}

# Map GitHub teams to policies
setup_github_team_mappings() {
    log_info "Setting up GitHub team to policy mappings..."

    # Map GeniusVentures organization members to dev-policy
    vault write auth/github/map/teams/genius-ventures \
        value=dev-policy || {
        log_warning "Failed to map genius-ventures team (may not exist)"
    }

    # Map CI/CD team to ci-policy (if it exists)
    vault write auth/github/map/teams/ci-cd \
        value=ci-policy || {
        log_warning "Failed to map ci-cd team (may not exist)"
    }

    log_success "GitHub team mappings configured"
}

# Initialize secret paths with default structure
initialize_secret_paths() {
    log_info "Initializing secret paths..."

    # Create dev secrets path with placeholder
    vault kv put secret/dev/placeholder \
        value="This is a placeholder secret. Replace with actual secrets." || {
        log_warning "Failed to create dev placeholder secret"
    }

    # Create test secrets path with placeholder
    vault kv put secret/test/placeholder \
        value="This is a placeholder secret. Replace with actual secrets." || {
        log_warning "Failed to create test placeholder secret"
    }

    # Create ci secrets path with placeholder
    vault kv put secret/ci/placeholder \
        value="This is a placeholder secret. Replace with actual secrets." || {
        log_warning "Failed to create CI placeholder secret"
    }

    log_success "Secret paths initialized"
}

# Main initialization function
main() {
    log_info "Starting Vault initialization..."

    # Set Vault environment variables
    export VAULT_ADDR="$VAULT_ADDR"
    export VAULT_TOKEN="$VAULT_TOKEN"

    # Wait for Vault to be ready
    wait_for_vault

    # Setup components
    setup_github_auth
    create_policies
    setup_github_team_mappings
    initialize_secret_paths

    log_success "Vault initialization completed successfully!"
    log_info "Vault is ready at: $VAULT_ADDR"
    log_info "Root token: $VAULT_TOKEN"
    log_info ""
    log_info "Next steps:"
    log_info "1. Run vault-fetch-secrets.sh to retrieve secrets"
    log_info "2. Use VaultSecretManager.ts for programmatic access"
    log_info "3. Run migrate-secrets-to-vault.sh to import existing secrets"
}

# Run main function
main "$@"