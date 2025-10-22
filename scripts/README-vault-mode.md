# Vault Mode CLI Utility

User-friendly command-line interface for managing HashiCorp Vault modes in the development environment.

## Overview

The `vault-mode` CLI utility simplifies switching between persistent and ephemeral Vault modes, providing:

- Easy mode switching with data migration
- Comprehensive status information
- Interactive prompts to prevent data loss
- Integration with Docker Compose configuration

## Installation

### Add to PATH

To use `vault-mode` from anywhere in the terminal, add the scripts directory to your PATH:

#### Option 1: Temporary (Current Session Only)

```bash
export PATH="$PATH:/workspaces/diamonds_dev_env/.devcontainer/scripts"
```

#### Option 2: Permanent (Add to .bashrc)

```bash
echo 'export PATH="$PATH:/workspaces/diamonds_dev_env/.devcontainer/scripts"' >> ~/.bashrc
source ~/.bashrc
```

#### Option 3: Direct Execution

Run directly without adding to PATH:

```bash
/workspaces/diamonds_dev_env/.devcontainer/scripts/vault-mode status
```

Or create an alias:

```bash
alias vault-mode='/workspaces/diamonds_dev_env/.devcontainer/scripts/vault-mode'
```

## Usage

### Show Current Status

Display comprehensive information about the current Vault mode and configuration:

```bash
vault-mode status
```

**Output includes:**
- Current mode (persistent/ephemeral)
- Configuration file status
- Docker service status (if accessible)
- Vault initialization and seal status
- Persistent storage information
- Vault health status

### Switch Modes

Switch between persistent and ephemeral modes:

```bash
vault-mode switch persistent
vault-mode switch ephemeral
```

**Interactive Migration Options:**

When switching modes, you'll be prompted with three options:

1. **Migrate secrets** - Uses `vault-migrate-mode.sh` to backup and restore secrets
2. **Switch without migration** - Changes mode without preserving secrets (⚠️ data loss)
3. **Cancel** - Abort the operation

**What Happens During a Switch:**

1. Checks if already in target mode
2. Prompts for migration preference
3. Updates configuration files:
   - `.devcontainer/data/vault-mode.conf`
   - `.devcontainer/.env`
4. Restarts Vault service (if Docker accessible)
5. Displays new status

### Get Help

Display usage information and examples:

```bash
vault-mode help
vault-mode --help
```

## Vault Modes

### Persistent Mode

- **Storage:** Raft storage backend
- **Data:** Persists across container restarts
- **Location:** `.devcontainer/data/vault/raft`
- **Use Case:** Production-like development, data preservation

**Configuration:**
```bash
VAULT_MODE=persistent
AUTO_UNSEAL=true
VAULT_COMMAND="server -config=/vault/config/vault-server-persistent.hcl"
```

### Ephemeral Mode

- **Storage:** In-memory (dev mode)
- **Data:** Lost on container restart
- **Root Token:** `root`
- **Use Case:** Testing, temporary experiments

**Configuration:**
```bash
VAULT_MODE=ephemeral
AUTO_UNSEAL=false
VAULT_COMMAND="server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
```

## Examples

### Check Current Mode

```bash
$ vault-mode status

═══════════════════════════════════════════════════════════
Vault Mode Status
═══════════════════════════════════════════════════════════

Mode: ephemeral
Config: /workspaces/diamonds_dev_env/.devcontainer/data/vault-mode.conf

Docker Service Status:
  vault-hashicorp    running

Vault Health:
  Initialized: true
  Sealed: false
  Standby: false

Persistent Storage:
  Raft Directory: Not available (ephemeral mode)
```

### Switch to Persistent with Migration

```bash
$ vault-mode switch persistent

Current mode: ephemeral
Target mode: persistent

Migration Options:
1. Migrate secrets (recommended - uses vault-migrate-mode.sh)
2. Switch without migration (⚠️  WARNING: Current secrets will be lost)
3. Cancel

Enter your choice [1-3]: 1

Migrating secrets...
[INFO] Starting migration from ephemeral to persistent...
[SUCCESS] Migration complete!

Updating configuration files...
Restarting Vault service...

New status:
Mode: persistent
Storage: raft (persistent)
```

### Switch to Ephemeral Without Migration

```bash
$ vault-mode switch ephemeral

Current mode: persistent
Target mode: ephemeral

Migration Options:
1. Migrate secrets (recommended - uses vault-migrate-mode.sh)
2. Switch without migration (⚠️  WARNING: Current secrets will be lost)
3. Cancel

Enter your choice [1-3]: 2

⚠️  WARNING: Switching without migration will lose all current secrets!

Continue without migration? (yes/no): yes

Updating configuration files...
Restarting Vault service...

New status:
Mode: ephemeral
```

## Configuration Files

### vault-mode.conf

Location: `.devcontainer/data/vault-mode.conf`

```bash
VAULT_MODE=persistent
AUTO_UNSEAL=true
VAULT_COMMAND="server -config=/vault/config/vault-server-persistent.hcl"
```

### Docker Compose .env

Location: `.devcontainer/.env`

Contains `VAULT_MODE` variable used by Docker Compose:

```bash
VAULT_MODE=persistent
```

## Migration Integration

The `vault-mode switch` command integrates with `vault-migrate-mode.sh` to:

1. **Backup secrets** from current mode
2. **Switch mode** and restart Vault
3. **Restore secrets** to new mode
4. **Handle errors** with automatic rollback

### Migration Features

- Timestamped backups (YYYYMMDD-HHMMSS)
- Individual JSON export per secret
- Metadata tracking
- Automatic cleanup (keeps last 5 backups)
- Rollback capability

## Error Handling

### Docker Not Accessible

If running inside the DevContainer without Docker access:

```
Note: Docker not accessible - cannot check service status
Configuration files will be updated.
Please restart Vault manually on the host.
```

**Solution:** Run mode switch on the host machine or access Docker socket.

### Already in Target Mode

```
[INFO] Already in persistent mode. No action needed.
```

### Invalid Mode

```
[ERROR] Invalid mode: invalid_mode
Valid modes: persistent, ephemeral
```

## Testing

Run the comprehensive test suite:

```bash
/workspaces/diamonds_dev_env/.devcontainer/scripts/test-vault-mode-cli.sh
```

**Tests include:**
- Script existence and permissions
- Help command functionality
- Status command output
- Invalid command handling
- Function definitions
- Migration integration
- Configuration handling
- Docker availability handling
- Service restart functionality
- Colored output
- Detailed status information
- Confirmation prompts
- Command dispatcher

## Troubleshooting

### Command not found

```bash
# Add to PATH
export PATH="$PATH:/workspaces/diamonds_dev_env/.devcontainer/scripts"
```

### Permission denied

```bash
# Make executable
chmod +x /workspaces/diamonds_dev_env/.devcontainer/scripts/vault-mode
```

### Vault not responding

```bash
# Check service status
docker compose ps vault-hashicorp

# Check logs
docker compose logs vault-hashicorp

# Restart service
docker compose restart vault-hashicorp
```

### Migration failed

Check the migration script logs:

```bash
# List backups
ls -la /workspaces/diamonds_dev_env/.devcontainer/data/vault-backups/

# Check latest backup
cat /workspaces/diamonds_dev_env/.devcontainer/data/vault-backups/latest/metadata.json

# Manual rollback
/workspaces/diamonds_dev_env/.devcontainer/scripts/vault-migrate-mode.sh rollback
```

## Related Scripts

- **vault-migrate-mode.sh** - Handles secret migration between modes
- **vault-init.sh** - Initializes Vault
- **vault-unseal.sh** - Unseals Vault
- **update-docker-compose-vault.sh** - Updates Docker Compose configuration

## Notes

- **DevContainer Environment:** The CLI detects when Docker is not accessible and provides appropriate guidance
- **Color Output:** Uses ANSI color codes for better readability (cyan, green, yellow, red)
- **Safety:** Interactive confirmations prevent accidental data loss
- **Integration:** Works seamlessly with existing vault management scripts

## Version

Part of Vault Persistence CLI system, Task 8.0

## Support

For issues or questions, refer to:
- Task documentation: `.devcontainer/prompts/tasks/tasks-vault-persistence-cli-prd.md`
- Migration script: `vault-migrate-mode.sh`
- Test suite: `test-vault-mode-cli.sh`
