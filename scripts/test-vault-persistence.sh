#!/usr/bin/env bash
# Test script for verifying Vault data persistence across container restarts
# Run this from the HOST machine (not inside DevContainer)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"

echo "[INFO] Testing Vault data persistence across container restarts"
echo ""

# Create temporary docker-compose for testing
cat > "$DEVCONTAINER_DIR/docker-compose.persistence-test.yml" <<'EOF'
version: "3.8"

services:
  vault-persistence-test:
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

# Step 1: Initialize Vault and write a test secret
echo "[STEP 1] Starting Vault and initializing..."
docker compose -f docker-compose.persistence-test.yml up -d vault-persistence-test
sleep 10

echo "[INFO] Initializing Vault..."
INIT_RESPONSE=$(curl -s -X PUT -d '{"secret_shares":5,"secret_threshold":3}' http://localhost:8200/v1/sys/init)

UNSEAL_KEY_1=$(echo "$INIT_RESPONSE" | jq -r '.keys[0]')
UNSEAL_KEY_2=$(echo "$INIT_RESPONSE" | jq -r '.keys[1]')
UNSEAL_KEY_3=$(echo "$INIT_RESPONSE" | jq -r '.keys[2]')
ROOT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r '.root_token')

echo "[INFO] Unsealing Vault..."
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_1\"}" http://localhost:8200/v1/sys/unseal > /dev/null
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_2\"}" http://localhost:8200/v1/sys/unseal > /dev/null
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_3\"}" http://localhost:8200/v1/sys/unseal > /dev/null

echo "[INFO] Vault unsealed. Writing test secret..."
TEST_SECRET_VALUE="persistence-test-$(date +%s)"

curl -s -X POST \
  -H "X-Vault-Token: $ROOT_TOKEN" \
  -d "{\"data\":{\"value\":\"$TEST_SECRET_VALUE\"}}" \
  http://localhost:8200/v1/secret/data/test/persistence

echo "[SUCCESS] Test secret written: $TEST_SECRET_VALUE"
echo ""

# Step 2: Stop and restart Vault
echo "[STEP 2] Stopping Vault container..."
docker compose -f docker-compose.persistence-test.yml down

echo "[INFO] Checking Raft database files..."
if [ -d "$DEVCONTAINER_DIR/data/vault-data/raft" ]; then
    echo "[SUCCESS] Raft database directory exists"
    ls -lh "$DEVCONTAINER_DIR/data/vault-data/raft/" | head -5
else
    echo "[ERROR] Raft database directory not found!"
    exit 1
fi
echo ""

echo "[STEP 3] Restarting Vault container..."
docker compose -f docker-compose.persistence-test.yml up -d vault-persistence-test
sleep 10

# Step 3: Unseal and verify secret persisted
echo "[INFO] Unsealing Vault after restart..."
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_1\"}" http://localhost:8200/v1/sys/unseal > /dev/null
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_2\"}" http://localhost:8200/v1/sys/unseal > /dev/null
curl -s -X PUT -d "{\"key\":\"$UNSEAL_KEY_3\"}" http://localhost:8200/v1/sys/unseal > /dev/null

echo "[INFO] Reading test secret after restart..."
READ_RESPONSE=$(curl -s -H "X-Vault-Token: $ROOT_TOKEN" \
  http://localhost:8200/v1/secret/data/test/persistence)

RETRIEVED_VALUE=$(echo "$READ_RESPONSE" | jq -r '.data.data.value')

echo ""
if [ "$RETRIEVED_VALUE" = "$TEST_SECRET_VALUE" ]; then
    echo "[SUCCESS] ✓ Data persistence verified!"
    echo "  Original: $TEST_SECRET_VALUE"
    echo "  Retrieved: $RETRIEVED_VALUE"
else
    echo "[ERROR] ✗ Data persistence failed!"
    echo "  Expected: $TEST_SECRET_VALUE"
    echo "  Got: $RETRIEVED_VALUE"
    exit 1
fi

# Cleanup
echo ""
echo "[INFO] Cleaning up test..."
docker compose -f docker-compose.persistence-test.yml down
rm -f "$DEVCONTAINER_DIR/docker-compose.persistence-test.yml"

echo ""
echo "[SUCCESS] Persistence test completed successfully!"
echo ""
echo "Summary:"
echo "  - Vault initialized with Raft backend"
echo "  - Test secret written to persistent storage"
echo "  - Container stopped and restarted"
echo "  - Secret successfully retrieved after restart"
echo "  - Raft database verified in: data/vault-data/raft/"
