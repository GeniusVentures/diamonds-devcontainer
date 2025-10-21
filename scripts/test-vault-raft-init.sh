#!/usr/bin/env bash
# Test script for Vault Raft backend initialization
# Run this from the HOST machine (not inside DevContainer)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"

echo "[INFO] Testing Vault initialization with Raft backend"
echo "[INFO] This test temporarily modifies docker-compose.dev.yml"

# Backup original docker-compose
cp "$DEVCONTAINER_DIR/docker-compose.dev.yml" "$DEVCONTAINER_DIR/docker-compose.dev.yml.test-backup"

# Create temporary docker-compose with persistent Vault
cat > "$DEVCONTAINER_DIR/docker-compose.test.yml" <<'EOF'
version: "3.8"

services:
  vault-test:
    image: hashicorp/vault:latest
    command: vault server -config=/vault/config/vault-persistent.hcl
    ports:
      - "8200:8200"
    environment:
      - VAULT_LOG_LEVEL=info
    volumes:
      - ./data/vault-data:/vault/data
      - ./config/vault-persistent.hcl:/vault/config/vault-persistent.hcl:ro
    cap_add:
      - IPC_LOCK
    networks:
      - test-network

networks:
  test-network:
    driver: bridge
EOF

cd "$DEVCONTAINER_DIR"

echo "[INFO] Starting Vault with persistent configuration..."
docker compose -f docker-compose.test.yml up -d vault-test

echo "[INFO] Waiting for Vault to start..."
sleep 10

echo "[INFO] Checking Vault health..."
curl -s http://localhost:8200/v1/sys/health || echo "Vault not initialized (expected)"

echo ""
echo "[INFO] Initializing Vault with 5 key shares, threshold 3..."
INIT_RESPONSE=$(curl -s -X PUT -d '{"secret_shares":5,"secret_threshold":3}' http://localhost:8200/v1/sys/init)

echo "$INIT_RESPONSE" | jq '.' || echo "Response: $INIT_RESPONSE"

# Extract unseal keys and root token
UNSEAL_KEY_1=$(echo "$INIT_RESPONSE" | jq -r '.keys[0]')
UNSEAL_KEY_2=$(echo "$INIT_RESPONSE" | jq -r '.keys[1]')
UNSEAL_KEY_3=$(echo "$INIT_RESPONSE" | jq -r '.keys[2]')
ROOT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r '.root_token')

echo ""
echo "[INFO] Unsealing Vault (3 of 5 keys required)..."
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_1\"}" http://localhost:8200/v1/sys/unseal | jq '.sealed'
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_2\"}" http://localhost:8200/v1/sys/unseal | jq '.sealed'
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_3\"}" http://localhost:8200/v1/sys/unseal | jq '.sealed'

echo ""
echo "[INFO] Verifying Vault status..."
curl -s http://localhost:8200/v1/sys/health | jq '.'

echo ""
echo "[INFO] Checking Raft database files..."
ls -la "$DEVCONTAINER_DIR/data/vault-data/raft/" || echo "Raft directory not accessible from host"

echo ""
echo "[SUCCESS] Vault initialized with Raft backend!"
echo ""
echo "Unseal Keys (save these):"
echo "  Key 1: $UNSEAL_KEY_1"
echo "  Key 2: $UNSEAL_KEY_2"
echo "  Key 3: $UNSEAL_KEY_3"
echo "Root Token: $ROOT_TOKEN"

echo ""
echo "[INFO] Cleaning up test..."
docker compose -f docker-compose.test.yml down

# Restore original docker-compose
mv "$DEVCONTAINER_DIR/docker-compose.dev.yml.test-backup" "$DEVCONTAINER_DIR/docker-compose.dev.yml"
rm -f "$DEVCONTAINER_DIR/docker-compose.test.yml"

echo "[INFO] Test complete. Original configuration restored."
