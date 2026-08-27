#!/bin/sh
# Vault Startup Script
# Determines whether to start Vault in ephemeral or persistent mode
# based on the state of the raft directory
# POSIX-compliant for use with sh (not bash)

set -e

# Default commands
EPHEMERAL_CMD="server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
PERSISTENT_CMD="server -config=/vault/config/vault-persistent.hcl"

# Check if raft directory exists and has data
raft_initialized() {
    # Check if raft directory exists (try mounted path first, then local path)
    if [ -d "/vault/data/raft" ]; then
        RAFT_DIR="/vault/data/raft"
        UNSEAL_CHECK="/vault/data/vault-unseal-keys.json"
    elif [ -d "${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/raft" ]; then
        RAFT_DIR="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/raft"
        UNSEAL_CHECK="${WORKSPACE_FOLDER}/.devcontainer/data/vault-unseal-keys.json"
    else
        return 1
    fi

    # Check if raft directory has any files (indicating initialization)
    if [ -z "$(ls -A "$RAFT_DIR" 2>/dev/null)" ]; then
        return 1
    fi

    # Check for raft database files
    if [ ! -f "$RAFT_DIR/raft.db" ]; then
        return 1
    fi
    
    # CRITICAL: Also check if unseal keys exist
    # Without unseal keys, the raft database is unusable
    if [ ! -f "$UNSEAL_CHECK" ]; then
        echo "WARNING: raft.db exists but no unseal keys found"
        echo "This indicates corrupted or incomplete initialization"
        echo "Removing corrupted raft data..."
        rm -rf "$RAFT_DIR"
        return 1
    fi

    return 0
}

# Initialize persistent Vault
initialize_persistent() {
    echo "Initializing persistent Vault for the first time..."

    # Determine paths based on environment
    if [ -d "/vault/data" ]; then
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
    if [ -f "/vault/config/vault-persistent.hcl" ]; then
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
    
    # Give Vault a moment to start binding to ports
    echo "Giving Vault 3 seconds to start..."
    sleep 3

    # Wait for Vault to be ready (but sealed)
    echo "Waiting for Vault to be ready for initialization..."
    i=1
    vault_ready=0
    while [ $i -le 60 ]; do
        # Check if Vault process is still running
        if ! kill -0 $VAULT_PID 2>/dev/null; then
            echo "ERROR: Vault process died unexpectedly"
            exit 1
        fi
        
        # Try health check - try to get any response from Vault
        # Simpler approach: just try curl and check if we get any output
        health_response=$(curl -s http://127.0.0.1:8200/v1/sys/health 2>&1)
        
        # DEBUG: Show what we got every 5 iterations
        if [ $((i % 5)) -eq 0 ]; then
            response_preview=$(echo "$health_response" | head -c 50)
            echo "DEBUG: Got response: '$response_preview'"
        fi
        
        # Vault is ready when we get ANY response (even error JSON means it's responding)
        if [ -n "$health_response" ]; then
            echo "Vault is responding - ready for initialization"
            echo "Response: $(echo "$health_response" | head -c 100)"
            sleep 1
            vault_ready=1
            break
        fi
        
        # Only show status every 3 iterations to reduce noise
        remainder=$((i % 3))
        if [ $remainder -eq 0 ]; then
            echo "Waiting... ($i/60)"
        fi
        
        sleep 2
        i=$((i + 1))
    done

    if [ $vault_ready -eq 0 ]; then
        echo "Failed to start Vault for initialization - timed out after 2 minutes"
        echo "Vault may not be starting properly. Check logs above."
        kill $VAULT_PID 2>/dev/null || true
        exit 1
    fi

    # Initialize Vault using operator init
    echo "Initializing Vault with raft storage..."
    export VAULT_ADDR="http://127.0.0.1:8200"
    
    # Use curl directly for initialization (more reliable in this environment)
    INIT_RESPONSE=$(curl -s -X PUT -d '{"secret_shares": 5, "secret_threshold": 3}' http://127.0.0.1:8200/v1/sys/init 2>&1)
    INIT_SUCCESS=$?
    
    echo "Initialization response code: $INIT_SUCCESS"

    if [ $INIT_SUCCESS -eq 0 ] && echo "$INIT_RESPONSE" | grep -q '"keys"'; then
        echo "Vault initialized successfully"

        # Save unseal keys
        echo "$INIT_RESPONSE" > "$UNSEAL_KEYS_FILE"
        chmod 600 "$UNSEAL_KEYS_FILE"

        # Extract root token
        ROOT_TOKEN=$(echo "$INIT_RESPONSE" | grep -o '"root_token":"[^"]*' | cut -d'"' -f4)

        if [ -n "$ROOT_TOKEN" ]; then
            echo "Root token: $ROOT_TOKEN"
            echo "Unseal keys saved to: $UNSEAL_KEYS_FILE"
        else
            echo "WARNING: Could not extract root token from response"
        fi

        # Stop Vault (it will be restarted in persistent mode)
        echo "Stopping Vault after initialization..."
        kill $VAULT_PID 2>/dev/null || true
        sleep 3

        echo ""
        echo "============================================"
        echo "Persistent Vault initialization complete!"
        echo "============================================"
        echo ""
        echo "IMPORTANT: Save your unseal keys securely!"
        echo "Location: $UNSEAL_KEYS_FILE"
        echo ""
        
        # Now start Vault in persistent mode with unsealing
        echo "Starting Vault in persistent mode with auto-unseal..."
        vault server -config="$CONFIG_FILE" &
        VAULT_PID=$!
        
        # Wait for Vault to be ready
        sleep 3
        i=1
        while [ $i -le 30 ]; do
            if curl -s http://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1; then
                echo "Vault is ready for unsealing"
                break
            fi
            sleep 2
            i=$((i + 1))
        done
        
        # Unseal the vault
        echo "Unsealing Vault with saved keys..."
        export VAULT_ADDR="http://127.0.0.1:8200"
        
        # Extract first 3 unseal keys from the JSON response
        KEYS=$(echo "$INIT_RESPONSE" | grep -o '"keys":\[[^]]*\]' | grep -o '"[^"]*"' | grep -v 'keys' | head -3 | tr -d '"')
        
        key_count=0
        echo "$KEYS" | while read -r key; do
            if [ -n "$key" ]; then
                key_preview=$(echo "$key" | cut -c1-10)
                echo "Using unseal key $((key_count + 1)): ${key_preview}..."
                vault operator unseal "$key"
                key_count=$((key_count + 1))
            fi
        done
        
        echo ""
        echo "============================================"
        echo "Persistent Vault initialized and unsealed!"
        echo "============================================"
        echo ""
        echo "Vault is now running in persistent mode"
        echo "Root token: $ROOT_TOKEN"
        echo ""
        
        # Wait for the Vault process to keep container running
        wait $VAULT_PID
    else
        echo "Failed to initialize Vault"
        echo "HTTP Response: $INIT_RESPONSE"
        kill $VAULT_PID 2>/dev/null || true
        exit 1
    fi
}

# Unseal Vault if it's sealed
unseal_vault() {
    echo "Checking if Vault needs to be unsealed..."
    
    # Set VAULT_ADDR for the vault CLI
    export VAULT_ADDR="http://127.0.0.1:8200"
    
    # Wait longer for Vault to be ready
    max_attempts=60
    attempt=1
    vault_ready=0
    while [ $attempt -le $max_attempts ]; do
        # Check if Vault responds at all
        if curl -s http://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1; then
            vault_ready=1
            break
        fi
        echo "Waiting for Vault to be ready... ($attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    if [ $vault_ready -eq 0 ]; then
        echo "Vault is not responding after 2 minutes"
        echo "Vault may not be initialized. Check if raft data is corrupted."
        return 1
    fi
    
    # Check if Vault is initialized
    if ! vault status >/dev/null 2>&1; then
        echo "Vault is not initialized"
        echo "This may indicate corrupted raft data. Consider:"
        echo "  1. Remove .devcontainer/data/vault-data/ and reinitialize"
        echo "  2. Or run vault operator init manually"
        return 1
    fi

    # Check if Vault is sealed
    if vault status 2>/dev/null | grep -q "Sealed.*true"; then
        echo "Vault is sealed. Attempting to unseal..."
        
        # Try to find unseal keys
        UNSEAL_KEYS_FILE=""
        if [ -f "/vault/data/vault-unseal-keys.json" ]; then
            UNSEAL_KEYS_FILE="/vault/data/vault-unseal-keys.json"
        elif [ -n "${WORKSPACE_FOLDER}" ] && [ -f "${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-unseal-keys.json" ]; then
            UNSEAL_KEYS_FILE="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-unseal-keys.json"
        fi
        
        if [ -n "$UNSEAL_KEYS_FILE" ]; then
            # Extract first 3 keys using grep/sed instead of jq
            KEYS=$(grep -o '"keys":\[[^]]*\]' "$UNSEAL_KEYS_FILE" | sed 's/"keys":\[\([^]]*\)\]/\1/' | tr -d '"' | tr ',' '\n' | head -3)
            if [ -n "$KEYS" ]; then
                echo "$KEYS" | while read -r key; do
                    if [ -n "$key" ]; then
                        # POSIX substring (first 10 chars)
                        key_preview=$(echo "$key" | cut -c1-10)
                        echo "Using unseal key: ${key_preview}..."
                        vault operator unseal "$key"
                    fi
                done
                echo "Vault unsealing completed"
            else
                echo "Could not extract unseal keys from $UNSEAL_KEYS_FILE"
            fi
        else
            echo "No unseal keys file found"
            echo "Manual unseal required. Use: vault operator unseal <key>"
        fi
    else
        echo "Vault is already unsealed"
    fi
}

# Main logic
# Determine which vault-mode.conf file to use
VAULT_MODE_FILE=""
if [ -f "/vault/data/vault-mode.conf" ]; then
    VAULT_MODE_FILE="/vault/data/vault-mode.conf"
elif [ -n "${WORKSPACE_FOLDER}" ] && [ -f "${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-mode.conf" ]; then
    VAULT_MODE_FILE="${WORKSPACE_FOLDER}/.devcontainer/data/vault-data/vault-mode.conf"
fi

if [ -n "$VAULT_MODE_FILE" ] && grep -q 'INITIALIZE_PERSISTENT="true"' "$VAULT_MODE_FILE" 2>/dev/null; then
    echo "Found INITIALIZE_PERSISTENT flag in $VAULT_MODE_FILE"
    # Remove the initialization flag before attempting (so we don't retry on failure loops)
    sed -i '/INITIALIZE_PERSISTENT/d' "$VAULT_MODE_FILE"
    # Initialize persistent mode (this will exec and keep container running)
    initialize_persistent
elif echo "${VAULT_COMMAND}" | grep -q "config="; then
    # VAULT_COMMAND is set to persistent mode
    if raft_initialized; then
        echo "Starting Vault in persistent mode (raft initialized)..."
        # Use local config if mounted config doesn't exist
        if [ -f "/vault/config/vault-persistent.hcl" ]; then
            vault server -config=/vault/config/vault-persistent.hcl &
            VAULT_PID=$!
        elif [ -n "${WORKSPACE_FOLDER}" ] && [ -f "${WORKSPACE_FOLDER}/.devcontainer/config/vault-persistent.hcl" ]; then
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