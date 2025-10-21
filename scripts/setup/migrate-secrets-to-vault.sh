#!/bin/bash
# migrate-secrets-to-vault.sh
# Script to migrate secrets from .env file to HashiCorp Vault
# This script safely moves sensitive configuration to Vault while maintaining backups

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Vault connectivity
check_vault_connection() {
    log_info "Checking Vault connectivity..."

    if [[ -z "${VAULT_TOKEN}" ]]; then
        log_error "VAULT_TOKEN is not set. Please authenticate with Vault first."
        log_info "Run: .devcontainer/scripts/setup/vault-setup-wizard.sh --non-interactive"
        exit 1
    fi

    export VAULT_TOKEN

    # Check Vault health using HTTP API
    if ! curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
        log_error "Cannot connect to Vault at ${VAULT_ADDR}"
        log_error "Make sure Vault is running and accessible"
        exit 1
    fi

    log_success "Vault connection established"
}

# Function to identify secret variables
is_secret_variable() {
    local var_name="$1"
    local var_value="$2"

    # Skip non-secret variables
    case "$var_name" in
        WORKSPACE_NAME|HH_CHAIN_ID|*_MOCK_CHAIN_ID|*_BLOCK|DIAMOND_NAME)
            return 1 # Not a secret
            ;;
        *)
            # Check if value looks like a secret (contains sensitive patterns)
            if [[ "$var_value" =~ ^(sk|pk|xoxp|xoxb|ghp)_ ]] || \
               [[ "$var_value" =~ ^0x[0-9a-fA-F]{64}$ ]] || \
               [[ "$var_name" =~ (PRIVATE_KEY|SECRET|TOKEN|KEY|PASSWORD)$ ]]; then
                return 0 # Is a secret
            else
                return 1 # Not a secret
            fi
            ;;
    esac
}

# Function to backup .env file
create_backup() {
    local env_file="$1"
    local backup_file="logs/${env_file}.vault-migrated.$(date +%Y%m%d_%H%M%S)"

    log_info "Creating backup of .env file: ${backup_file}"
    cp "$env_file" "$backup_file"

    # Add backup file to .gitignore if not already present
    local gitignore_file="$(dirname "$env_file")/.gitignore"
    if [[ -f "$gitignore_file" ]] && ! grep -q "^${backup_file}$" "$gitignore_file"; then
        echo "${backup_file}" >> "$gitignore_file"
        log_info "Added backup file to .gitignore"
    fi

    echo "$backup_file"
}

# Function to migrate secrets to Vault
migrate_secrets() {
    local env_file="$1"
    local vault_path="${2:-secret/dev}"

    log_info "Starting secret migration from ${env_file} to Vault path: ${vault_path}"

    local secrets_found=0
    local secrets_migrated=0
    local non_secret_vars=()

    # Read .env file and process each line
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Remove leading/trailing whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if is_secret_variable "$key" "$value"; then
            log_info "Migrating secret: ${key}"

            # Store in Vault using HTTP API
            if ! curl -s -X POST \
                -H "X-Vault-Token: $VAULT_TOKEN" \
                -d "{\"data\": {\"value\": \"$value\"}}" \
                "$VAULT_ADDR/v1/secret/data/${vault_path}/${key}" >/dev/null 2>&1; then
                log_error "Failed to migrate: ${key}"
                exit 1
            fi

            log_success "Successfully migrated: ${key}"
            ((secrets_found++))
            ((secrets_migrated++))
        else
            # Keep non-secret variables
            non_secret_vars+=("$key=$value")
        fi
    done < "$env_file"

    log_info "Found ${secrets_found} secrets, migrated ${secrets_migrated} secrets"

    # Only update .env file if there were secrets to migrate
    if [[ $secrets_found -gt 0 ]]; then
        log_info "Creating new .env file with non-secret variables..."
        # Create new .env file with only non-secret variables
        {
            echo "# .env file - Non-secret configuration only"
            echo "# Secrets have been migrated to Vault (${vault_path})"
            echo "# To retrieve secrets, run: .devcontainer/scripts/vault-fetch-secrets.sh"
            echo ""
            printf '%s\n' "${non_secret_vars[@]}"
        } > "${env_file}.new"

        log_info "Contents of .env.new:"
        cat "${env_file}.new"

        log_info "Updating .env file..."
        # Use cat and rm instead of cp to avoid device busy issues
        if cat "${env_file}.new" > "$env_file"; then
            log_info "File update successful, removing temp file..."
            rm "${env_file}.new"
            log_success "Updated .env file to contain only non-secret configuration"
        else
            log_error "Failed to update .env file - permission denied or device busy"
            log_info "You can manually update the .env file by replacing its contents with:"
            log_info "${env_file}.new"
            exit 1
        fi
    else
        log_info "No secrets found to migrate - .env file unchanged"
    fi
}

# Function to validate migration
validate_migration() {
    local env_file="$1"
    local vault_path="${2:-secret/dev}"

    log_info "Validating migration..."

    local secrets_remaining=0

    # Check if any secrets remain in .env file
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if is_secret_variable "$key" "$value"; then
            log_error "Secret still found in .env file: ${key}"
            ((secrets_remaining++))
        fi
    done < "$env_file"

    if [[ $secrets_remaining -gt 0 ]]; then
        log_error "Migration validation failed: ${secrets_remaining} secrets still remain in .env file"
        exit 1
    fi

    # Verify secrets are accessible in Vault
    local vault_secrets
    vault_secrets=$(curl -s \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/metadata/${vault_path}?list=true" | \
        jq -r '.data.keys[]' 2>/dev/null || echo "")

    if [[ -z "$vault_secrets" ]]; then
        log_warning "No secrets found in Vault path: ${vault_path}"
        log_warning "This might be expected if no secrets were migrated"
    else
        log_success "Secrets successfully stored in Vault:"
        echo "$vault_secrets" | while read -r secret; do
            [[ -n "$secret" ]] && log_info "  - ${secret}"
        done
    fi

    log_success "Migration validation completed successfully"
}

# Main function
main() {
    local env_file="${PROJECT_ROOT}/.env"
    local vault_path="secret/dev"

    log_info "Secret Migration to Vault"
    log_info "=================================="

    # Check if .env file exists
    if [[ ! -f "$env_file" ]]; then
        log_error ".env file not found: ${env_file}"
        exit 1
    fi

    # Check Vault connection
    check_vault_connection

    # Create backup
    local backup_file
    backup_file=$(create_backup "$env_file")

    # Migrate secrets
    migrate_secrets "$env_file" "$vault_path"

    log_info "Migration completed, starting validation..."

    # Validate migration
    validate_migration "$env_file" "$vault_path"

    log_success "Secret migration completed successfully!"
    log_info "Backup created: ${backup_file}"
    log_info "To restore from backup: cp '${backup_file}' '${env_file}'"
    log_info "To retrieve secrets: .devcontainer/scripts/vault-fetch-secrets.sh"
}

# Run main function
main "$@"