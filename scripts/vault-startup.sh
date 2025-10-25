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
    # Check if raft directory exists (try mounted path first, then local path)
    if [[ -d "/vault/data/raft" ]]; then
        RAFT_DIR="/vault/data/raft"
    elif [[ -d "${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/raft" ]]; then
        RAFT_DIR="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/raft"
    else
        return 1
    fi

    # Check if raft directory has any files (indicating initialization)
    if [[ -z "$(ls -A "$RAFT_DIR" 2>/dev/null)" ]]; then
        return 1
    fi

    # Check for raft database files
    if [[ ! -f "$RAFT_DIR/raft.db" ]]; then
        return 1
    fi

    return 0
}

# Initialize persistent Vault
initialize_persistent() {
    echo "Initializing persistent Vault for the first time..."

    # Determine paths based on environment
    if [[ -d "/vault/data" ]]; then
        # Running in container with mounted volumes
        RAFT_DATA_DIR="/vault/data/raft"
        MODE_CONF_FILE="/vault/data/vault-mode.conf"
        UNSEAL_KEYS_FILE="/vault/data/vault-unseal-keys.json"
        CONFIG_FILE="/vault/config/vault-persistent.hcl"
    else
        # Running locally in devcontainer
        RAFT_DATA_DIR="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/raft"
        MODE_CONF_FILE="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-mode.conf"
        UNSEAL_KEYS_FILE="${WORKSPACE_FOLDER}/.devcontainer/data/vault-unseal-keys.json"
        CONFIG_FILE="${WORKSPACE_FOLDER}/.devcontainer/config/vault-persistent.hcl"
    fi

    # Create raft directory if it doesn't exist
    mkdir -p "$RAFT_DATA_DIR"

    # Determine config file to use
    if [[ -f "/vault/config/vault-persistent.hcl" ]]; then
        CONFIG_FILE="/vault/config/vault-persistent.hcl"
    else
        # Create a local config file for testing
        CONFIG_FILE="${WORKSPACE_FOLDER}/.devcontainer/config/vault-persistent-local.hcl"
        cat > "$CONFIG_FILE" << EOF
storage "raft" {
  path = "${WORKSPACE_FOLDER}/.devcontainer/data/vault-data"
  node_id = "vault-dev-local"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
ui = true
disable_mlock = true
EOF
    fi

    # Start Vault in persistent mode (will be sealed initially)
    echo "Starting Vault in persistent mode for initialization..."
    vault server -config="$CONFIG_FILE" &
    VAULT_PID=$!

    # Wait for Vault to be ready (but sealed)
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

    # Initialize Vault using operator init
    echo "Initializing Vault with raft storage..."
    if command -v vault >/dev/null 2>&1; then
        # Use vault CLI if available
        export VAULT_ADDR="http://127.0.0.1:8200"
        INIT_RESPONSE=$(vault operator init -key-shares=5 -key-threshold=3 -format=json 2>/dev/null)
        INIT_SUCCESS=$?
    else
        # Fallback to HTTP API
        INIT_RESPONSE=$(curl -s -X PUT -d '{"secret_shares": 5, "secret_threshold": 3}' http://127.0.0.1:8200/v1/sys/init)
        INIT_SUCCESS=$?
    fi

    if [[ $INIT_SUCCESS -eq 0 ]] && echo "$INIT_RESPONSE" | grep -q '"keys"'; then
        echo "Vault initialized successfully"

        # Save unseal keys
        echo "$INIT_RESPONSE" > "$UNSEAL_KEYS_FILE"
        chmod 600 "$UNSEAL_KEYS_FILE"

        # Extract root token
        if command_exists vault; then
            ROOT_TOKEN=$(echo "$INIT_RESPONSE" | jq -r '.root_token' 2>/dev/null)
        else
            ROOT_TOKEN=$(echo "$INIT_RESPONSE" | grep -o '"root_token":"[^"]*' | cut -d'"' -f4)
        fi

        echo "Root token: $ROOT_TOKEN"

        # Stop Vault (it will be restarted in persistent mode)
        echo "Stopping Vault after initialization..."
        kill $VAULT_PID 2>/dev/null || true
        sleep 2

        echo "Persistent Vault initialization complete."
        echo "Root token saved. Unseal keys saved to $UNSEAL_KEYS_FILE"
        echo "Please restart to start Vault in persistent mode."
    else
        echo "Failed to initialize Vault"
        echo "Response: $INIT_RESPONSE"
        kill $VAULT_PID 2>/dev/null || true
        exit 1
    fi

    exit 0
}

# Unseal Vault if it's sealed
unseal_vault() {
    echo "Checking if Vault needs to be unsealed..."
    
    # Set VAULT_ADDR for the vault CLI
    export VAULT_ADDR="http://127.0.0.1:8200"
    
    # Wait longer for Vault to be ready
    local max_attempts=60
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if vault status >/dev/null 2>&1; then
            break
        fi
        echo "Waiting for Vault to be ready... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    if ! vault status >/dev/null 2>&1; then
        echo "Vault is not responding after 2 minutes"
        return 1
    fi

    # Check if Vault is sealed
    if vault status 2>/dev/null | grep -q "Sealed.*true"; then
        echo "Vault is sealed. Attempting to unseal..."
        
        # Try to find unseal keys
        UNSEAL_KEYS_FILE=""
        if [[ -f "/vault/data/vault-unseal-keys.json" ]]; then
            UNSEAL_KEYS_FILE="/vault/data/vault-unseal-keys.json"
        elif [[ -n "${WORKSPACE_FOLDER}" ]] && [[ -f "${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-unseal-keys.json" ]]; then
            UNSEAL_KEYS_FILE="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-unseal-keys.json"
        fi
        
        if [[ -n "$UNSEAL_KEYS_FILE" ]]; then
            # Extract first 3 keys using grep/sed instead of jq
            KEYS=$(grep -o '"keys":\[[^]]*\]' "$UNSEAL_KEYS_FILE" | sed 's/"keys":\[\([^]]*\)\]/\1/' | tr -d '"' | tr ',' '\n' | head -3)
            if [[ -n "$KEYS" ]]; then
                echo "$KEYS" | while read -r key; do
                    if [[ -n "$key" ]]; then
                        echo "Using unseal key: ${key:0:10}..."
                        vault operator unseal "$key"
                    fi
                done
                echo "Vault unsealing completed"
            else
                echo "Could not extract unseal keys from $UNSEAL_KEYS_FILE"
            fi
        else
            echo "No unseal keys file found"
        fi
    else
        echo "Vault is already unsealed"
    fi
}

# Main logic
# Determine which vault-mode.conf file to use
VAULT_MODE_FILE=""
if [[ -f "/vault/data/vault-mode.conf" ]]; then
    VAULT_MODE_FILE="/vault/data/vault-mode.conf"
elif [[ -n "${WORKSPACE_FOLDER}" ]] && [[ -f "${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-mode.conf" ]]; then
    VAULT_MODE_FILE="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-mode.conf"
fi

if [[ -n "$VAULT_MODE_FILE" ]] && grep -q 'INITIALIZE_PERSISTENT="true"' "$VAULT_MODE_FILE" 2>/dev/null; then
    echo "Found INITIALIZE_PERSISTENT flag in $VAULT_MODE_FILE"
    # Remove the initialization flag
    sed -i '/INITIALIZE_PERSISTENT/d' "$VAULT_MODE_FILE"
    initialize_persistent
elif [[ "${VAULT_COMMAND}" == *"-config="* ]] || [[ "${VAULT_COMMAND}" == "server -config="* ]]; then
    # VAULT_COMMAND is set to persistent mode
    if raft_initialized; then
        echo "Starting Vault in persistent mode (raft initialized)..."
        # Use local config if mounted config doesn't exist
        if [[ -f "/vault/config/vault-persistent.hcl" ]]; then
            vault server -config=/vault/config/vault-persistent.hcl &
            VAULT_PID=$!
        elif [[ -n "${WORKSPACE_FOLDER}" ]] && [[ -f "${WORKSPACE_FOLDER}/.devcontainer/config/vault-persistent.hcl" ]]; then
            vault server -config="${WORKSPACE_FOLDER}/.devcontainer/config/vault-persistent.hcl" &
            VAULT_PID=$!
        else
            echo "Error: vault-persistent.hcl config file not found"
            exec vault ${EPHEMERAL_CMD}
        fi
        
        # Unseal if necessary
        unseal_vault
        
        # Wait for Vault process
        wait $VAULT_PID
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