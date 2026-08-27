# Environment Variable Propagation Guide

This document explains how environment variables are used to configure Vault modes and how they propagate through the Docker Compose and DevContainer setup.

## Overview

The Vault configuration uses environment variables to enable easy switching between ephemeral (dev) and persistent (Raft) storage modes without modifying Docker Compose files.

## Key Environment Variables

### VAULT_COMMAND
Controls which Vault server command is executed.

**Location**: `.devcontainer/.env`

**Values**:
- **Ephemeral (default)**: `server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200`
- **Persistent**: `server -config=/vault/config/vault-persistent.hcl`

**Usage in docker-compose.dev.yml**:
```yaml
vault-dev:
  command: ${VAULT_COMMAND:-server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200}
```

### VAULT_ADDR
Points to the Vault server API endpoint.

**Location**: `.devcontainer/devcontainer.json` (containerEnv)

**Value**: `http://vault-dev:8200`

This is automatically set for all processes running inside the DevContainer, allowing Vault CLI commands to work without manual configuration.

### VAULT_SKIP_VERIFY
Disables TLS certificate verification for development.

**Location**: `.devcontainer/devcontainer.json` (containerEnv)

**Value**: `true`

Needed for dev mode which uses self-signed certificates.

## Environment Variable Precedence

Docker Compose resolves environment variables in the following order (highest to lowest priority):

1. **Shell environment variables** (command-line override)
2. **`.env` file** (in same directory as docker-compose.yml)
3. **Default values** (in docker-compose.yml using `:-` syntax)

### Example Precedence

Given this in `docker-compose.dev.yml`:
```yaml
command: ${VAULT_COMMAND:-server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200}
```

**Scenario 1: No .env file, no shell override**
- Result: Uses default `server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200`

**Scenario 2: .env file sets VAULT_COMMAND**
```bash
# .env
VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl
```
- Result: Uses persistent mode from .env

**Scenario 3: Shell override (highest priority)**
```bash
VAULT_COMMAND='server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200' \
  docker compose up -d
```
- Result: Uses command-line value, ignoring .env

## How Changes Propagate

### Changing Modes via .env

1. Edit `.devcontainer/.env`:
   ```bash
   # For persistent mode:
   VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl
   
   # For ephemeral mode:
   VAULT_COMMAND=server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
   ```

2. Restart the Vault service:
   ```bash
   docker compose -f .devcontainer/docker-compose.dev.yml restart vault-dev
   ```
   
   Or rebuild the container:
   ```bash
   docker compose -f .devcontainer/docker-compose.dev.yml down
   docker compose -f .devcontainer/docker-compose.dev.yml up -d
   ```

### Temporary Override (Command-Line)

Override without changing .env:
```bash
VAULT_COMMAND='server -config=/vault/config/vault-persistent.hcl' \
  docker compose -f .devcontainer/docker-compose.dev.yml up -d vault-dev
```

This is useful for testing without modifying files.

## Verification

### Check Resolved Configuration

View what Docker Compose will actually use:
```bash
docker compose -f .devcontainer/docker-compose.dev.yml config
```

Look for the `vault-dev` service and its `command` field to see the resolved value.

### Check Running Container

See the actual command a running container is using:
```bash
CONTAINER_ID=$(docker compose -f .devcontainer/docker-compose.dev.yml ps -q vault-dev)
docker inspect $CONTAINER_ID --format='{{.Config.Cmd}}'
```

### Run Verification Script

Automated verification:
```bash
./.devcontainer/scripts/verify-env-propagation.sh
```

This script tests:
- ✓ VAULT_COMMAND exists in .env
- ✓ VAULT_COMMAND documented in .env.example
- ✓ docker-compose.dev.yml references VAULT_COMMAND
- ✓ Configuration syntax is valid
- ✓ Variable resolves correctly
- ✓ Bind mounts are configured
- ✓ Storage directories exist
- ✓ Config files exist
- ✓ Runtime behavior (if service is running)

## DevContainer Environment Variables

Environment variables set in `devcontainer.json` under `containerEnv` are available to all processes inside the DevContainer:

```json
"containerEnv": {
  "VAULT_ADDR": "http://vault-dev:8200",
  "VAULT_SKIP_VERIFY": "true"
}
```

These are automatically exported in the container's environment, so:
```bash
# Inside DevContainer - works without configuration
vault status

# Equivalent to:
VAULT_ADDR=http://vault-dev:8200 VAULT_SKIP_VERIFY=true vault status
```

## Common Issues

### Issue: Changes to .env not taking effect

**Cause**: Container still running with old environment

**Solution**: Restart services:
```bash
docker compose -f .devcontainer/docker-compose.dev.yml down
docker compose -f .devcontainer/docker-compose.dev.yml up -d
```

### Issue: VAULT_ADDR not working inside DevContainer

**Cause**: devcontainer.json not reloaded

**Solution**: Rebuild DevContainer
- VS Code: Command Palette > "Dev Containers: Rebuild Container"

### Issue: Can't connect to Vault from host

**Cause**: Port not forwarded or service not running

**Solutions**:
1. Check service status: `docker compose ps`
2. Check port forwarding in VS Code (Ports tab)
3. Test: `curl http://localhost:8200/v1/sys/health`

### Issue: Shell override doesn't work

**Cause**: Quotes or escaping issues

**Solution**: Use proper quoting:
```bash
# Correct:
VAULT_COMMAND='server -config=/vault/config/vault-persistent.hcl' docker compose up -d

# Also correct:
VAULT_COMMAND="server -config=/vault/config/vault-persistent.hcl" docker compose up -d

# Wrong (shell interprets spaces):
VAULT_COMMAND=server -config=/vault/config/vault-persistent.hcl docker compose up -d
```

## Best Practices

1. **Use .env for persistent changes** - Commit-worthy configuration
2. **Use shell overrides for testing** - Temporary experiments
3. **Document in .env.example** - Help other developers understand options
4. **Verify after changes** - Run verification script
5. **Restart services cleanly** - Use `down` then `up` to ensure fresh state
6. **Check logs** - `docker compose logs vault-dev` to verify mode

## Related Files

- `.devcontainer/.env` - Active configuration
- `.devcontainer/.env.example` - Documentation and examples
- `.devcontainer/docker-compose.dev.yml` - Service definitions
- `.devcontainer/devcontainer.json` - DevContainer environment variables
- `.devcontainer/scripts/verify-env-propagation.sh` - Verification tool

## More Information

For testing scripts and mode-specific details, see:
- `TESTING_VAULT_MODES.md` - Test scripts for both modes
