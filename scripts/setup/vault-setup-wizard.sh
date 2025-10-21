#!/bin/bash
# vault-setup-wizard.sh
# Interactive wizard for HashiCorp Vault configuration and setup
# Guides users through the complete Vault setup process

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
VAULT_ADDR="${VAULT_ADDR:-http://vault-dev:8200}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Wizard state
STEP=1
TOTAL_STEPS=9

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

log_step() {
    echo -e "${PURPLE}[STEP $1/$TOTAL_STEPS]${NC} $2"
}

log_header() {
    echo -e "${CYAN}================================================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================================================================${NC}"
}

# Function to check if running in a container
is_running_in_container() {
    # Check for common container indicators
    [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || grep -q 'docker\|containerd\|podman' /proc/1/cgroup 2>/dev/null || [[ -n "${CONTAINER:-}" ]]
}

# Function to check Vault connectivity
check_vault_connectivity() {
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 5 "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt user for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt [Y/n]: " response
            response=${response:-y}
        else
            read -p "$prompt [y/N]: " response
            response=${response:-n}
        fi

        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to prompt user for input
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local response

    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " response
        response=${response:-$default}
    else
        read -p "$prompt: " response
    fi

    echo "$response"
}

# Step 1: Welcome and prerequisites check
step_welcome() {
    log_header "Vault Setup Wizard"
    echo ""
    echo "This wizard will guide you through setting up HashiCorp Vault for secure"
    echo "secret management in your Diamonds development environment."
    echo ""

    if is_running_in_container; then
        echo "Running in DevContainer environment - Vault service integration detected."
        echo ""
        echo "Prerequisites:"
        echo "  • GitHub account with repository access"
        echo "  • GitHub Personal Access Token (will be created if needed)"
        echo "  • curl for HTTP requests"
    else
        echo "Prerequisites:"
        echo "  • Docker and Docker Compose installed"
        echo "  • GitHub account with repository access"
        echo "  • GitHub Personal Access Token (will be created if needed)"
    fi
    echo ""

    if ! prompt_yes_no "Do you want to continue with the Vault setup?"; then
        log_info "Setup cancelled by user"
        exit 0
    fi


    ((STEP++))
}

# Step 2: Check system prerequisites
step_check_prerequisites() {
    log_step $STEP "Checking System Prerequisites"

    local all_good=true

    if is_running_in_container; then
        log_info "Running in containerized environment - adapting checks..."

        # In DevContainer, check for Vault connectivity instead of Docker tools
        if check_vault_connectivity; then
            log_success "Vault service is accessible at $VAULT_ADDR"
        else
            log_warning "Vault service not yet accessible - will be configured"
        fi

        # Check curl for HTTP requests
        if command_exists curl; then
            log_success "curl is available for HTTP requests"
        else
            log_error "curl is not available"
            all_good=false
        fi
    else
        # Original checks for non-containerized environment
        # Check Docker
        if command_exists docker; then
            log_success "Docker is installed"
        else
            log_error "Docker is not installed"
            all_good=false
        fi

        # Check Docker Compose
        if command_exists docker-compose; then
            log_success "Docker Compose is installed"
        else
            log_error "Docker Compose is not installed"
            all_good=false
        fi
    fi

    # Common checks for both environments
    # Check GitHub CLI
    if command_exists gh; then
        log_success "GitHub CLI is installed"
    else
        log_warning "GitHub CLI not found - you can install it or use manual token entry"
    fi

    # Check Vault CLI
    if command_exists vault; then
        log_success "Vault CLI is installed"
    else
        log_warning "Vault CLI not found - will be installed automatically"
    fi

    if [[ "$all_good" != "true" ]]; then
        log_error "Prerequisites not met. Please install missing tools and try again."
        exit 1
    fi

    ((STEP++))
}

# Step 3: Configure Vault address
step_configure_vault() {
    log_step $STEP "Configuring Vault Server"

    echo "Vault will run as a Docker service. The default address is:"
    echo "  http://vault-dev:8200"
    echo ""

    VAULT_ADDR=$(prompt_input "Vault server address" "$VAULT_ADDR")
    export VAULT_ADDR

    # Set default token for development mode
    VAULT_TOKEN="${VAULT_TOKEN:-root}"
    export VAULT_TOKEN

    log_success "Vault address set to: $VAULT_ADDR"

    ((STEP++))
}

# Step 4: Set up GitHub authentication
step_github_auth() {
    log_step $STEP "Setting up GitHub Authentication"

    echo "Vault uses GitHub authentication to control access to secrets."
    echo "You'll need a GitHub Personal Access Token with 'repo' scope."
    echo ""

    # Check if token is already set
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        if prompt_yes_no "GitHub token is already set. Use existing token?"; then
            log_success "Using existing GitHub token"
            ((STEP++))
            return
        fi
    fi

    # Try to get token from GitHub CLI
    if command_exists gh && gh auth status >/dev/null 2>&1; then
        if prompt_yes_no "GitHub CLI is authenticated. Use it to get a token?"; then
            GITHUB_TOKEN=$(gh auth token)
            export GITHUB_TOKEN
            log_success "GitHub token obtained from CLI"
            ((STEP++))
            return
        fi
    fi

    # Manual token entry
    echo "You'll need to create a Personal Access Token:"
    echo "  1. Go to: https://github.com/settings/tokens"
    echo "  2. Click 'Generate new token (classic)'"
    echo "  3. Select 'repo' scope"
    echo "  4. Copy the token"
    echo ""

    GITHUB_TOKEN=$(prompt_input "Enter your GitHub Personal Access Token")
    export GITHUB_TOKEN

    log_success "GitHub token configured"

    ((STEP++))
}

# Step 5: Start Vault service
step_start_vault() {
    log_step $STEP "Starting Vault Service"

    if is_running_in_container; then
        echo "Running in DevContainer environment - checking Vault service..."
        echo ""

        # In DevContainer, Vault should already be running as a service
        if check_vault_connectivity; then
            log_success "Vault service is running and accessible at $VAULT_ADDR"
        else
            log_warning "Vault service not yet accessible. Waiting..."
            local retries=30
            while [[ $retries -gt 0 ]]; do
                if check_vault_connectivity; then
                    log_success "Vault service is now accessible"
                    break
                fi
                log_info "Waiting for Vault service... ($retries attempts remaining)"
                sleep 2
                ((retries--))
            done

            if [[ $retries -eq 0 ]]; then
                log_error "Vault service failed to become accessible within 60 seconds"
                log_info "Please check that the vault-dev service is running in docker-compose"
                exit 1
            fi
        fi
    else
        echo "Starting Vault development server..."
        echo ""

        if ! docker-compose ps vault-dev | grep -q "Up"; then
            log_info "Starting Vault container..."
            docker-compose up -d vault-dev

            # Wait for Vault to be ready
            log_info "Waiting for Vault to initialize..."
            local retries=30
            while [[ $retries -gt 0 ]]; do
                if curl -s "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
                    break
                fi
                sleep 2
                ((retries--))
            done

            if [[ $retries -eq 0 ]]; then
                log_error "Vault failed to start within 60 seconds"
                exit 1
            fi
        else
            log_success "Vault container is already running"
        fi
    fi

    log_success "Vault service is ready"

    ((STEP++))
}

# Step 6: Initialize Vault
step_initialize_vault() {
    log_step $STEP "Initializing Vault"

    echo "Initializing Vault with development settings..."
    echo ""

    # Check if Vault is already initialized
    if vault status >/dev/null 2>&1; then
        log_success "Vault is already initialized"
    else
        # Run vault-init.sh
        echo "Current directory: $(pwd)"
        local init_script="/workspaces/$WORKSPACE_NAME/.devcontainer/scripts/vault-init.sh"
        if [[ -f "$init_script" ]]; then
            log_info "Running Vault initialization script..."
            if "$init_script"; then
                log_success "Vault initialized successfully"
            else
                log_error "Vault initialization failed"
                exit 1
            fi
        else
            log_error "Vault initialization script not found: $init_script"
            exit 1
        fi
    fi

    ((STEP++))
}

# Step 7: Authenticate with Vault
step_authenticate() {
    log_step $STEP "Authenticating with Vault"

    echo "Authenticating with Vault using GitHub token..."
    echo ""

    # Check if we already have a valid token by trying to access sys/health
    if curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
        log_success "Already authenticated with Vault (using root token)"
    else
        # Try to authenticate with GitHub token
        AUTH_RESPONSE=$(curl -s -X POST \
            -d "{\"token\": \"$GITHUB_TOKEN\"}" \
            "$VAULT_ADDR/v1/auth/github/login")

        if echo "$AUTH_RESPONSE" | grep -q '"auth"'; then
            # Extract the client token from the response
            CLIENT_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"client_token":"[^"]*' | cut -d'"' -f4)
            if [ -n "$CLIENT_TOKEN" ]; then
                export VAULT_TOKEN="$CLIENT_TOKEN"
                log_success "Successfully authenticated with Vault using GitHub token"
            else
                log_error "Failed to extract client token from authentication response"
                exit 1
            fi
        else
            log_error "Vault authentication failed"
            log_info "Check your GitHub token and try again"
            log_info "Auth response: $AUTH_RESPONSE"
            exit 1
        fi
    fi

    ((STEP++))
}

# Step 8: Migrate secrets
step_migrate_secrets() {
    log_step $STEP "Migrating Secrets to Vault"

    echo "The final step is to migrate your secrets from .env to Vault."
    echo "This will:"
    echo "  • Read secrets from your .env file"
    echo "  • Store them securely in Vault"
    echo "  • Create a backup of your .env file"
    echo "  • Remove secrets from the .env file"
    echo ""

    if [[ ! -f ".env" ]]; then
        log_warning ".env file not found - no secrets to migrate"
        log_info "You can add secrets to Vault manually using: vault kv put secret/dev/KEY value=VALUE"
    else
        if prompt_yes_no "Ready to migrate secrets from .env to Vault?"; then
            local migrate_script="/workspaces/$WORKSPACE_NAME/.devcontainer/scripts/setup/migrate-secrets-to-vault.sh"
            if [[ -f "$migrate_script" ]]; then
                log_info "Running secret migration..."
                if "$migrate_script"; then
                    log_success "Secrets migrated successfully!"
                else
                    log_error "Secret migration failed"
                    exit 1
                fi
            else
                log_error "Migration script not found: $migrate_script"
                exit 1
            fi
        else
            log_info "Secret migration skipped"
            log_info "You can run it later with: ./.devcontainer/scripts/setup/migrate-secrets-to-vault.sh"
        fi
    fi

    ((STEP++))
}

# Step 9: Final verification and summary
step_final_verification() {
    log_step $STEP "Final Verification"

    echo "Running final verification of your Vault setup..."
    echo ""

    # Prefer the more comprehensive validate script in the setup/ folder
    local verify_script_setup="/workspaces/$WORKSPACE_NAME/.devcontainer/scripts/setup/validate-vault-setup.sh"
    local verify_script_root="/workspaces/$WORKSPACE_NAME/.devcontainer/scripts/validate-vault-setup.sh"

    if [[ -f "$verify_script_setup" ]]; then
        if env VAULT_ADDR="$VAULT_ADDR" VAULT_TOKEN="$VAULT_TOKEN" bash "$verify_script_setup"; then
            log_success "Vault setup verification passed!"
        else
            log_warning "Some verification checks failed"
            log_info "Check the output above for details"
        fi
    elif [[ -f "$verify_script_root" ]]; then
        if env VAULT_ADDR="$VAULT_ADDR" VAULT_TOKEN="$VAULT_TOKEN" bash "$verify_script_root"; then
            log_success "Vault setup verification passed!"
        else
            log_warning "Some verification checks failed"
            log_info "Check the output above for details"
        fi
    else
        log_warning "Verification script not found - running HTTP basic checks"

        # Basic HTTP checks (no Vault CLI required)
        local healthy=false
        if curl -s --max-time 3 "$VAULT_ADDR/v1/sys/health" >/dev/null 2>&1; then
            log_success "Vault is reachable at $VAULT_ADDR"
            healthy=true
        else
            log_error "Vault is not accessible at $VAULT_ADDR"
        fi

        # Check that secrets path has entries (KV v2 metadata list)
        if $healthy; then
            local list_resp
            list_resp=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN:-}" "$VAULT_ADDR/v1/secret/metadata/dev?list=true" 2>/dev/null || echo "")
            if echo "$list_resp" | grep -q 'keys\|"keys"'; then
                log_success "Secrets appear to be present under secret/dev"
                log_success "Vault setup verification passed!"
            else
                log_warning "No keys returned from secret/dev metadata; secrets may not be present"
            fi
        fi
    fi

    ((STEP++))
}

# Completion summary
show_completion() {
    log_header "Vault Setup Complete!"

    echo ""
    echo "🎉 Your HashiCorp Vault is now configured and ready to use!"
    echo ""
    echo "What you can do now:"
    echo "  • Secrets are automatically loaded in DevContainer"
    echo "  • Use vault-fetch-secrets.sh to load secrets manually"
    echo "  • Run validate-vault-setup.sh to check configuration"
    echo "  • View secrets: vault kv list secret/dev"
    echo ""
    echo "Useful commands:"
    echo "  • Add secret: vault kv put secret/dev/KEY value=VALUE"
    echo "  • Get secret: vault kv get secret/dev/KEY"
    echo "  • List secrets: vault kv list secret/dev"
    echo ""
    echo "Documentation:"
    echo "  • Setup Guide: docs/devs/VAULT_SETUP.md"
    echo "  • Troubleshooting: docs/devs/VAULT_TROUBLESHOOTING.md"
    echo ""
    echo "Need help? Check the troubleshooting guide or ask in #devops"
    echo ""
}

# Main function
main() {
    # Run all steps
    step_welcome
    step_check_prerequisites
    step_configure_vault
    step_github_auth
    step_start_vault
    step_initialize_vault
    step_authenticate
    step_migrate_secrets
    step_final_verification

    # Show completion
    show_completion
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Vault Setup Wizard"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --non-interactive  Run without user prompts (uses defaults)"
        echo ""
        echo "This wizard guides you through setting up HashiCorp Vault"
        echo "for secure secret management in Diamonds development."
        exit 0
        ;;
    --non-interactive)
        # Set default values for non-interactive mode
        VAULT_ADDR="${VAULT_ADDR:-http://vault-dev:8200}"
        export VAULT_ADDR

        # Try to get GitHub token from environment or CLI
        if [[ -z "${GITHUB_TOKEN:-}" ]]; then
            if command_exists gh && gh auth status >/dev/null 2>&1; then
                GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
                export GITHUB_TOKEN
            fi
        fi

        # Override prompt functions for non-interactive mode
        prompt_yes_no() { return 0; }  # Always yes
        prompt_input() {
            local prompt="$1"
            local default="${2:-}"
            echo "$default"
        }

        log_info "Running in non-interactive mode..."
        ;;
    *)
        # Interactive mode - check if running in terminal
        if [[ ! -t 0 ]]; then
            log_error "Interactive mode requires a terminal. Use --non-interactive for automated setup."
            exit 1
        fi
        ;;
esac

# Run main function
main "$@"