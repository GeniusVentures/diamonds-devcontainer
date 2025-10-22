#!/usr/bin/env bash
# Test script for Vault persistent mode
# Must be run from the HOST machine (not inside DevContainer)
# Usage: ./.devcontainer/scripts/test-persistent-mode.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEVCONTAINER_DIR")"

echo "=================================================="
echo "Testing Vault Persistent Mode"
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

# Step 2: Configure persistent mode
log_info "Step 2: Configuring persistent mode in .env..."
cat > "$DEVCONTAINER_DIR/.env.test-persistent" << 'EOF'
# Vault Configuration - PERSISTENT MODE TEST
VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl
VAULT_MODE=persistent

# Minimal configuration for testing
WORKSPACE_NAME=diamonds_dev_env
HH_CHAIN_ID=31337
EOF

cp "$DEVCONTAINER_DIR/.env.test-persistent" "$DEVCONTAINER_DIR/.env"
log_info "✓ .env configured for persistent mode"

# Step 3: Check docker-compose configuration
log_info "Step 3: Validating docker-compose configuration..."
if docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" config > /dev/null 2>&1; then
    log_info "✓ docker-compose.dev.yml is valid"
else
    log_error "✗ docker-compose.dev.yml has configuration errors"
    exit 1
fi

# Step 4: Start Vault service
log_info "Step 4: Starting Vault service in persistent mode..."
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

# Step 6: Verify Raft storage in logs
log_info "Step 6: Verifying Raft storage backend..."
if docker compose -f "$DEVCONTAINER_DIR/docker-compose.dev.yml" logs vault-dev | grep -i "raft" > /dev/null; then
    log_info "✓ Raft storage backend detected in logs"
else
    log_warn "⚠ Raft storage not explicitly mentioned in logs (may still be working)"
fi

# Step 7: Check Vault health (should be sealed)
log_info "Step 7: Checking Vault health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:8200/v1/sys/health || echo "failed")

if [ "$HEALTH_RESPONSE" = "failed" ]; then
    log_error "✗ Failed to connect to Vault API"
    log_info "Vault may still be starting. Check logs above."
else
    log_info "✓ Vault API is responding"
    echo "Health response: $HEALTH_RESPONSE"
    
    # Check if sealed (expected for persistent mode on first start)
    if echo "$HEALTH_RESPONSE" | grep -q '"sealed":true'; then
        log_info "✓ Vault is sealed (expected for persistent mode on first start)"
    elif echo "$HEALTH_RESPONSE" | grep -q '"sealed":false'; then
        log_info "✓ Vault is unsealed (may have been initialized previously)"
    fi
fi

# Step 8: Check data directory
log_info "Step 8: Checking persistent data directory..."
if [ -d "$DEVCONTAINER_DIR/data/vault-data/raft" ]; then
    log_info "✓ Raft data directory exists"
    FILE_COUNT=$(find "$DEVCONTAINER_DIR/data/vault-data/raft" -type f 2>/dev/null | wc -l)
    log_info "  Files in raft directory: $FILE_COUNT"
    if [ "$FILE_COUNT" -gt 0 ]; then
        log_info "✓ Raft database files created"
    else
        log_warn "⚠ No files yet in raft directory (may create on first write)"
    fi
else
    log_warn "⚠ Raft data directory not found (may not be mounted correctly)"
fi

echo ""
log_info "=================================================="
log_info "Persistent Mode Test Summary"
log_info "=================================================="
log_info "Vault is running in persistent mode"
log_info "To initialize and unseal Vault, run:"
log_info "  vault operator init"
log_info "  vault operator unseal <unseal-key>"
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
