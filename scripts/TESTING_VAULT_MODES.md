# Vault Mode Testing Scripts

This directory contains test scripts to verify both ephemeral and persistent Vault modes work correctly with the Docker Compose configuration.

## Overview

Two test scripts are provided:
- `test-ephemeral-mode.sh` - Tests Vault in dev mode (default)
- `test-persistent-mode.sh` - Tests Vault with Raft storage backend

## Prerequisites

These scripts **must be run from the HOST machine**, not from inside the DevContainer, as they require Docker access to start/stop services.

## Running the Tests

### Test Ephemeral (Dev) Mode

```bash
# From the project root on the HOST machine:
./.devcontainer/scripts/test-ephemeral-mode.sh
```

**What it tests:**
- Vault starts in dev mode with `-dev` flag
- Vault is automatically unsealed and initialized
- Root token is `root` and works correctly
- Basic secret operations (write/read) work
- Data is temporary (ephemeral)

**Expected behavior:**
- ✓ Vault logs show "dev mode" messages
- ✓ Vault health endpoint returns `"sealed": false`
- ✓ Vault health endpoint returns `"initialized": true`
- ✓ Can write and read secrets immediately
- ⚠ Data will be lost when container stops

### Test Persistent (Raft) Mode

```bash
# From the project root on the HOST machine:
./.devcontainer/scripts/test-persistent-mode.sh
```

**What it tests:**
- Vault starts with Raft storage configuration
- Configuration file is mounted correctly
- Data directory is mounted at `/vault/data`
- Vault uses persistent storage backend
- Raft database files are created

**Expected behavior:**
- ✓ Vault logs mention "raft" storage backend
- ✓ Vault health endpoint returns `"sealed": true` (on first start)
- ✓ Raft data directory exists at `.devcontainer/data/vault-data/raft`
- ✓ Raft database files are created in data directory
- ℹ Requires manual initialization and unsealing

**To initialize and use persistent Vault:**
```bash
# Initialize (only needed once)
vault operator init

# Unseal (needed after each restart)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>

# Set root token and use
export VAULT_TOKEN=<root-token-from-init>
vault status
```

## Script Features

Both scripts:
- ✓ Automatically backup `.env` before testing
- ✓ Configure appropriate mode in `.env`
- ✓ Validate docker-compose configuration
- ✓ Start Vault service and wait for initialization
- ✓ Display Vault logs for inspection
- ✓ Check health endpoint and verify expected state
- ✓ Provide summary of results
- ✓ Optionally stop service and restore original `.env`

## Switching Modes in Development

To switch between modes permanently, edit `.devcontainer/.env`:

### For Ephemeral Mode (Default):
```bash
VAULT_COMMAND=server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
VAULT_MODE=ephemeral
```

### For Persistent Mode:
```bash
VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl
VAULT_MODE=persistent
```

Then rebuild or restart the DevContainer:
```bash
# Option 1: Rebuild DevContainer (from VS Code)
# Command Palette > Dev Containers: Rebuild Container

# Option 2: Restart services (from host)
docker compose -f .devcontainer/docker-compose.dev.yml restart vault-dev
```

## Troubleshooting

### "Cannot connect to Docker daemon"
- Scripts must be run from the HOST machine
- Ensure Docker is running
- Check Docker socket permissions

### "Command not found: vault"
- For ephemeral mode tests with Vault CLI operations
- Vault CLI must be installed on the host machine
- Or comment out CLI operation sections in scripts

### "Vault not responding"
- Vault may still be starting (wait 10-15 seconds)
- Check logs: `docker compose -f .devcontainer/docker-compose.dev.yml logs vault-dev`
- Verify ports: `netstat -an | grep 8200`

### Persistent mode shows no Raft files
- Files may not be created until first write operation
- Initialize Vault first, then check directory again
- Verify bind mount: `docker compose -f .devcontainer/docker-compose.dev.yml config`

## Related Files

- `.devcontainer/.env` - Environment variables controlling Vault mode
- `.devcontainer/.env.example` - Documentation and examples
- `.devcontainer/docker-compose.dev.yml` - Service configuration with VAULT_COMMAND variable
- `.devcontainer/config/vault-persistent.hcl` - Raft storage configuration
- `.devcontainer/data/vault-data/` - Persistent storage directory (gitignored)

## More Information

See the main PRD documentation:
- `.devcontainer/prompts/tasks/tasks-vault-persistence-cli-prd.md`
