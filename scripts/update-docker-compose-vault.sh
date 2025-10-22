#!/usr/bin/env bash
# Helper script to update Docker Compose configuration based on vault-mode.conf
# Updates .env file to control Vault container command and behavior

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VAULT_MODE_CONF="${PROJECT_ROOT}/.devcontainer/data/vault-mode.conf"
ENV_FILE="${PROJECT_ROOT}/.devcontainer/.env"

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Main function
main() {
    log_info "Updating Docker Compose configuration based on Vault mode..."
    
    # Check if vault-mode.conf exists
    if [[ ! -f "$VAULT_MODE_CONF" ]]; then
        log_error "vault-mode.conf not found: $VAULT_MODE_CONF"
        log_info "Run vault setup wizard first: .devcontainer/scripts/setup/vault-setup-wizard.sh"
        exit 1
    fi
    
    # Source the configuration
    source "$VAULT_MODE_CONF"
    
    # Validate VAULT_MODE
    if [[ -z "${VAULT_MODE:-}" ]]; then
        log_error "VAULT_MODE not set in $VAULT_MODE_CONF"
        exit 1
    fi
    
    if [[ "$VAULT_MODE" != "persistent" ]] && [[ "$VAULT_MODE" != "ephemeral" ]]; then
        log_error "Invalid VAULT_MODE: $VAULT_MODE (must be 'persistent' or 'ephemeral')"
        exit 1
    fi
    
    log_info "Detected Vault mode: $VAULT_MODE"
    log_info "Auto-unseal: ${AUTO_UNSEAL:-false}"
    
    # Determine the appropriate Vault command
    local vault_command
    if [[ "$VAULT_MODE" == "persistent" ]]; then
        vault_command="server -config=/vault/config/vault-persistent.hcl"
        log_info "Using persistent mode with Raft storage"
    else
        vault_command="server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
        log_info "Using ephemeral dev mode"
    fi
    
    # Backup .env file if it exists
    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "${ENV_FILE}.backup"
        log_info "Backed up existing .env file"
    fi
    
    # Update or create VAULT_COMMAND in .env
    if [[ -f "$ENV_FILE" ]] && grep -q "^VAULT_COMMAND=" "$ENV_FILE" 2>/dev/null; then
        # Update existing VAULT_COMMAND
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed syntax
            sed -i '' "s|^VAULT_COMMAND=.*|VAULT_COMMAND=\"$vault_command\"|" "$ENV_FILE"
        else
            # Linux sed syntax
            sed -i "s|^VAULT_COMMAND=.*|VAULT_COMMAND=\"$vault_command\"|" "$ENV_FILE"
        fi
        log_success "Updated VAULT_COMMAND in $ENV_FILE"
    else
        # Add VAULT_COMMAND to .env
        echo "" >> "$ENV_FILE"
        echo "# Vault Configuration (managed by update-docker-compose-vault.sh)" >> "$ENV_FILE"
        echo "VAULT_COMMAND=\"$vault_command\"" >> "$ENV_FILE"
        log_success "Added VAULT_COMMAND to $ENV_FILE"
    fi
    
    # Display summary
    echo ""
    log_success "✅ Docker Compose configuration updated successfully!"
    echo ""
    log_info "Summary:"
    echo "  • Vault Mode: $VAULT_MODE"
    echo "  • Auto-unseal: ${AUTO_UNSEAL:-false}"
    echo "  • Command: $vault_command"
    echo ""
    log_info "Next steps:"
    echo "  1. Restart Vault service:"
    echo "     cd .devcontainer && docker-compose restart vault-dev"
    echo ""
    echo "  2. Or rebuild container to apply changes:"
    echo "     docker-compose down && docker-compose up -d"
    echo ""
    
    # Verify docker-compose syntax
    # Step 5: Validate Docker Compose configuration
log_info "Validating Docker Compose configuration..."

if docker compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
    log_success "✓ Docker Compose configuration is valid"
else
    log_error "✗ Docker Compose configuration validation failed!"
    log_error "Restoring backup..."
    
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$ENV_FILE"
        log_info "Backup restored"
    fi
    
    echo ""
    log_error "❌ Configuration update failed. Please check your settings."
    exit 1
fi
    
    # Clean up backup if successful
    if [[ -f "${ENV_FILE}.backup" ]]; then
        rm "${ENV_FILE}.backup"
    fi
    
    exit 0
}

# Run main function
main "$@"
