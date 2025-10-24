#!/bin/bash
# Vault Startup Script
# Determines whether to start Vault in ephemeral or persistent mode
# based on the state of the raft directory

set -e

# Default commands
EPHEMERAL_CMD="server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
PERSISTENT_CMD="server -config=/vault/config/vault-persistent.hcl"

# Check if raft directory exists and has data
raft_initialized() {
    # Check if raft directory exists
    if [[ ! -d "/vault/data/raft" ]]; then
        return 1
    fi

    # Check if raft directory has any files (indicating initialization)
    if [[ -z "$(ls -A /vault/data/raft 2>/dev/null)" ]]; then
        return 1
    fi

    # Check for raft database files
    if [[ ! -f "/vault/data/raft/raft.db" ]]; then
        return 1
    fi

    return 0
}

# Initialize persistent Vault
initialize_persistent() {
    echo "Initializing persistent Vault for the first time..."

    # Create raft directory in the DevContainer data/vault-data/ if it doesn't exist
    mkdir -p ${WORKSPACE_FOLDER}/data/vault-data/raft 

    # Start Vault in ephemeral mode first to get it running
    echo "Starting Vault in ephemeral mode for initialization..."
    vault ${EPHEMERAL_CMD} &
    VAULT_PID=$!

    # Wait for Vault to be ready
    echo "Waiting for Vault to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:8200/v1/sys/health >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    if ! curl -s http://localhost:8200/v1/sys/health >/dev/null 2>&1; then
        echo "Failed to start Vault for initialization"
        kill $VAULT_PID 2>/dev/null || true
        exit 1
    fi

    # Initialize Vault
    echo "Initializing Vault..."
    INIT_RESPONSE=$(curl -s -X POST -d '{"secret_shares": 5, "secret_threshold": 3}' http://localhost:8200/v1/sys/init)

    if echo "$INIT_RESPONSE" | grep -q '"keys"'; then
        echo "Vault initialized successfully"

        # Save unseal keys
        echo "$INIT_RESPONSE" > /vault/data/vault-unseal-keys.json
        chmod 600 /vault/data/vault-unseal-keys.json

        # Extract root token
        ROOT_TOKEN=$(echo "$INIT_RESPONSE" | grep -o '"root_token":"[^"]*' | cut -d'"' -f4)

        # Stop ephemeral Vault
        echo "Stopping ephemeral Vault..."
        kill $VAULT_PID 2>/dev/null || true
        sleep 2

        echo "Persistent Vault initialization complete."
        echo "Root token saved. Unseal keys saved to /vault/data/vault-unseal-keys.json"
        echo "Please restart the container to start Vault in persistent mode."
    else
        echo "Failed to initialize Vault"
        kill $VAULT_PID 2>/dev/null || true
        exit 1
    fi

    exit 0
}

# Main logic
if [[ -f "/vault/data/vault-mode.conf" ]] && grep -q 'INITIALIZE_PERSISTENT="true"' /vault/data/vault-mode.conf; then
    # Remove the initialization flag
    sed -i '/INITIALIZE_PERSISTENT/d' /vault/data/vault-mode.conf
    initialize_persistent
elif [[ "${VAULT_COMMAND}" == *"-config="* ]] || [[ "${VAULT_COMMAND}" == "server -config="* ]]; then
    # VAULT_COMMAND is set to persistent mode
    if raft_initialized; then
        echo "Starting Vault in persistent mode (raft initialized)..."
        exec vault ${VAULT_COMMAND}
    else
        echo "Raft directory not initialized. Starting Vault in ephemeral mode for initial setup..."
        echo "Run the vault-setup-wizard.sh to initialize persistent mode."
        exec vault ${EPHEMERAL_CMD}
    fi
else
    # VAULT_COMMAND is ephemeral or default
    echo "Starting Vault in ephemeral mode..."
    exec vault ${VAULT_COMMAND:-${EPHEMERAL_CMD}}
fi