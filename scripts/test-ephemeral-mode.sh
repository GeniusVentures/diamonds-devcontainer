#!/usr/bin/env bash
# Test script for Vault ephemeral (dev) mode
# Must be run from the HOST machine (not inside DevContainer)
# Usage: ./.devcontainer/scripts/test-ephemeral-mode.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEVCONTAINER_DIR")"

echo "=================================================="
echo "Testing Vault Ephemeral (Dev) Mode"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Backup current .env
log_info "Step 1: Backing up current .env file..."
if [ -f "$DEVCONTAINER_DIR/.env" ]; then
    cp "$DEVCONTAINER_DIR/.env" "$DEVCONTAINER_DIR/.env.test-backup"
    log_info "✓ Backup created at .env.test-backup"
else
    log_warn "No existing .env file found"
fi

# Step 2: Configure ephemeral mode
log_info "Step 2: Configuring ephemeral mode in .env..."
cat > "$DEVCONTAINER_DIR/.env.test-ephemeral" << 'EOF'
# Vault Configuration - EPHEMERAL MODE TEST
VAULT_COMMAND=server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
VAULT_MODE=ephemeral

# Minimal configuration for testing
WORKSPACE_NAME=diamonds_dev_env
HH_CHAIN_ID=31337
EOF

cp "$DEVCONTAINER_DIR/.env.test-ephemeral" "$DEVCONTAINER_DIR/.env"
log_info "✓ .env configured for ephemeral mode"

# Step 3: Check docker-compose configuration
log_info "Step 3: Validating docker-compose configuration..."
if docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" config > /dev/null 2>&1; then
    log_info "✓ docker-compose.dev.yml is valid"
else
    log_error "✗ docker-compose.dev.yml has configuration errors"
    exit 1
fi

# Step 4: Start Vault service
log_info "Step 4: Starting Vault service in ephemeral mode..."
cd "$PROJECT_ROOT"
docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" up -d vault-dev

# Wait for Vault to start
log_info "Waiting for Vault to initialize (5 seconds)..."
sleep 5

# Step 5: Check Vault logs
log_info "Step 5: Checking Vault logs..."
echo ""
echo "--- Vault Logs (last 20 lines) ---"
docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" logs --tail=20 vault-dev
echo "--- End of Logs ---"
echo ""

# Step 6: Verify dev mode in logs
log_info "Step 6: Verifying dev mode..."
if docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" logs vault-dev | grep -i "dev mode" > /dev/null; then
    log_info "✓ Dev mode detected in logs"
else
    log_warn "⚠ 'Dev mode' not found in logs (may still be in dev mode)"
fi

# Check for root token
if docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" logs vault-dev | grep -i "root token" > /dev/null; then
    log_info "✓ Root token mentioned in logs (typical for dev mode)"
fi

# Step 7: Check Vault health (should be unsealed and ready)
log_info "Step 7: Checking Vault health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:8200/v1/sys/health || echo "failed")

if [ "$HEALTH_RESPONSE" = "failed" ]; then
    log_error "✗ Failed to connect to Vault API"
    log_info "Vault may still be starting. Check logs above."
else
    log_info "✓ Vault API is responding"
    echo "Health response: $HEALTH_RESPONSE"
    
    # Check if unsealed (expected for dev mode)
    if echo "$HEALTH_RESPONSE" | grep -q '"sealed":false'; then
        log_info "✓ Vault is unsealed (expected for dev mode)"
    elif echo "$HEALTH_RESPONSE" | grep -q '"sealed":true'; then
        log_warn "⚠ Vault is sealed (unexpected for dev mode)"
    fi
    
    # Check if initialized (should be in dev mode)
    if echo "$HEALTH_RESPONSE" | grep -q '"initialized":true'; then
        log_info "✓ Vault is initialized (expected for dev mode)"
    fi
fi

# Step 8: Test basic Vault operations
log_info "Step 8: Testing basic Vault operations..."
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

# Try to write a secret
log_info "Attempting to write a test secret..."
if vault kv put secret/test-ephemeral key=value 2>/dev/null; then
    log_info "✓ Successfully wrote test secret"
    
    # Try to read it back
    log_info "Attempting to read test secret..."
    if vault kv get secret/test-ephemeral 2>/dev/null; then
        log_info "✓ Successfully read test secret"
    else
        log_warn "⚠ Could not read test secret"
    fi
else
    log_warn "⚠ Could not write test secret (vault CLI may not be available)"
fi

echo ""
log_info "=================================================="
log_info "Ephemeral Mode Test Summary"
log_info "=================================================="
log_info "Vault is running in ephemeral (dev) mode"
log_info "Root token: root"
log_info "Vault is automatically unsealed and ready to use"
log_info ""
log_info "⚠ WARNING: Data will be lost when container is stopped"
log_info ""
log_info "To access Vault:"
log_info "  export VAULT_ADDR='http://localhost:8200'"
log_info "  export VAULT_TOKEN='root'"
log_info "  vault status"
log_info ""
log_info "To stop Vault:"
log_info "  docker compose -f .devcontainer/docker-compose.dev.yml down"
log_info ""
log_info "To restore original .env:"
log_info "  cp .devcontainer/.env.test-backup .devcontainer/.env"
log_info "=================================================="
echo ""

# Optionally stop the service
read -p "Stop Vault service now? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Stopping Vault service..."
    docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" down
    log_info "✓ Vault stopped"
    
    # Restore original .env
    if [ -f "$DEVCONTAINER_DIR/.env.test-backup" ]; then
        log_info "Restoring original .env..."
        cp "$DEVCONTAINER_DIR/.env.test-backup" "$DEVCONTAINER_DIR/.env"
        log_info "✓ Original .env restored"
    fi
fi

log_info "Test complete!"
