# Vault CLI Installation

## Overview

HashiCorp Vault CLI is installed in the DevContainer for local secret management. The CLI provides command-line access to read, write, and manage secrets stored in Vault.

## Installation Method

The Vault CLI is installed through multiple methods for reliability:

### Primary Method: HashiCorp APT Repository (Dockerfile)
```dockerfile
# Add HashiCorp GPG key and repository
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt-get update && apt-get install -y vault
```

### Fallback Method: Direct Binary Download
If the primary method fails, the installation script downloads the binary directly:
```bash
bash .devcontainer/scripts/install-vault-cli.sh
```

This script:
- Detects the system architecture (amd64, arm64, etc.)
- Downloads the appropriate Vault binary from releases.hashicorp.com
- Verifies the download with SHA256 checksums
- Installs to `/usr/local/bin/vault`
- Sets appropriate permissions

## Verification

### Check Installation
```bash
# Verify vault is in PATH
which vault
# Output: /usr/bin/vault or /usr/local/bin/vault

# Check version
vault version
# Output: Vault v1.15.0 (or similar)

# Check vault status
vault status
# Output: Shows sealed/unsealed status, cluster info
```

### Environment Variables
The following environment variables should be set:
```bash
echo $VAULT_ADDR
# Output: http://127.0.0.1:8200 (or configured address)

echo $VAULT_TOKEN
# Output: root or your authentication token
```

## Common Commands

### Reading Secrets
```bash
# Read a specific secret
vault kv get secret/dev/API_KEY

# Get secret in JSON format
vault kv get -format=json secret/dev/API_KEY

# Extract just the value
vault kv get -field=value secret/dev/API_KEY
```

### Writing Secrets
```bash
# Write a single value
vault kv put secret/dev/API_KEY value="your-api-key-here"

# Write multiple key-value pairs
vault kv put secret/dev/database \
  host="localhost" \
  port="5432" \
  username="admin" \
  password="secure-password"

# Write from a file
vault kv put secret/dev/config @config.json
```

### Listing Secrets
```bash
# List all secrets in a path
vault kv list secret/dev

# List secrets recursively (show directory structure)
vault kv list secret/
```

### Deleting Secrets
```bash
# Delete a secret (soft delete - can be undeleted)
vault kv delete secret/dev/API_KEY

# Permanently delete (all versions)
vault kv destroy secret/dev/API_KEY

# Undelete a soft-deleted secret
vault kv undelete -versions=1 secret/dev/API_KEY
```

### Managing Versions (KV v2)
```bash
# Get a specific version
vault kv get -version=2 secret/dev/API_KEY

# View secret metadata
vault kv metadata get secret/dev/API_KEY

# Rollback to a previous version
vault kv rollback -version=1 secret/dev/API_KEY
```

## Vault Status & Operations

### Check Vault Status
```bash
# Basic status
vault status

# Health check
curl http://127.0.0.1:8200/v1/sys/health

# Seal status (JSON)
vault read -format=json sys/seal-status
```

### Seal/Unseal Operations
```bash
# Seal Vault (requires authentication)
vault operator seal

# Unseal Vault (requires 3 of 5 unseal keys)
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>

# Check unseal progress
vault status
```

### Authentication
```bash
# Login with root token
vault login <root-token>

# Login with GitHub token
vault login -method=github token=<github-token>

# Check current token
vault token lookup

# Renew token
vault token renew
```

## Advanced Usage

### Secret Policies
```bash
# List policies
vault policy list

# Read a policy
vault policy read default

# Write a policy
vault policy write my-policy policy.hcl
```

### Audit Logs
```bash
# Enable audit logging
vault audit enable file file_path=/vault/logs/audit.log

# List audit devices
vault audit list

# Disable audit logging
vault audit disable file/
```

### Namespaces (Vault Enterprise)
```bash
# Create namespace
vault namespace create dev

# List namespaces
vault namespace list

# Use namespace
export VAULT_NAMESPACE=dev
vault kv list secret/
```

## Troubleshooting

### Issue: `vault: command not found`

**Cause**: Vault CLI not installed or not in PATH

**Solutions**:
```bash
# Check if vault is installed
dpkg -l | grep vault

# Reinstall using installation script
bash .devcontainer/scripts/install-vault-cli.sh

# Verify PATH
echo $PATH | grep -o '/usr/local/bin\|/usr/bin'

# If installed but not in PATH, add to .bashrc
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: `Error checking seal status: Get "http://127.0.0.1:8200/v1/sys/seal-status": dial tcp 127.0.0.1:8200: connect: connection refused`

**Cause**: Vault server is not running

**Solutions**:
```bash
# Check if Vault container is running
docker ps | grep vault

# Start Vault using docker-compose (if configured)
docker-compose up -d vault-dev

# Check Vault logs
docker-compose logs vault-dev

# Verify VAULT_ADDR is correct
echo $VAULT_ADDR
export VAULT_ADDR=http://127.0.0.1:8200
```

### Issue: `Error making API request: Code: 403. Errors: permission denied`

**Cause**: Not authenticated or insufficient permissions

**Solutions**:
```bash
# Check if you have a valid token
vault token lookup

# Login with root token
vault login root

# Or use token from file
export VAULT_TOKEN=$(cat .devcontainer/data/vault-data/.vault-token)

# Verify token works
vault token lookup
```

### Issue: `Error making API request: Code: 400. Errors: Vault is sealed`

**Cause**: Vault is sealed and cannot serve requests

**Solutions**:
```bash
# Check seal status
vault status

# Unseal manually (requires 3 of 5 keys from unseal-keys.json)
KEY1=$(jq -r '.unseal_keys_b64[0]' .devcontainer/data/vault-data/unseal-keys.json)
KEY2=$(jq -r '.unseal_keys_b64[1]' .devcontainer/data/vault-data/unseal-keys.json)
KEY3=$(jq -r '.unseal_keys_b64[2]' .devcontainer/data/vault-data/unseal-keys.json)

vault operator unseal $KEY1
vault operator unseal $KEY2
vault operator unseal $KEY3

# Or use auto-unseal script (if AUTO_UNSEAL=true)
bash .devcontainer/scripts/vault-auto-unseal.sh
```

### Issue: `unsupported kv store version` or `Invalid path for a versioned K/V secrets engine`

**Cause**: Using KV v1 commands on KV v2 engine or vice versa

**Solutions**:
```bash
# For KV v2 (default), use 'kv' commands
vault kv get secret/dev/API_KEY
vault kv put secret/dev/API_KEY value="new-value"

# Check which version is mounted
vault secrets list -detailed

# If using KV v1, use direct paths
vault read secret/dev/API_KEY
vault write secret/dev/API_KEY value="new-value"
```

### Issue: Installation fails with GPG errors

**Cause**: HashiCorp APT repository key issues

**Solutions**:
```bash
# Remove old key and repository
sudo rm /usr/share/keyrings/hashicorp-archive-keyring.gpg
sudo rm /etc/apt/sources.list.d/hashicorp.list

# Use direct binary download method
bash .devcontainer/scripts/install-vault-cli.sh

# This will download and install vault binary directly
```

### Issue: `vault version` shows old version after update

**Cause**: Multiple vault binaries in PATH

**Solutions**:
```bash
# Find all vault binaries
which -a vault

# Check versions
/usr/bin/vault version
/usr/local/bin/vault version

# Remove old version (be careful with sudo)
sudo rm /usr/local/bin/vault

# Reinstall from APT
sudo apt-get update && sudo apt-get install --reinstall vault
```

## Shell Completion

Enable shell completion for better CLI experience:

### Bash Completion
```bash
# Install completion
vault -autocomplete-install

# Reload shell configuration
source ~/.bashrc

# Test completion
vault kv <TAB><TAB>
```

### Zsh Completion
```bash
# Add to .zshrc
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/bin/vault vault
```

## Integration with Other Tools

### Using with jq for JSON Processing
```bash
# Get secret and extract specific field
vault kv get -format=json secret/dev/API_KEY | jq -r '.data.data.value'

# Get all secrets in path
vault kv list -format=json secret/dev | jq -r '.[]'

# Complex filtering
vault kv get -format=json secret/dev/database | \
  jq -r '.data.data | to_entries[] | "\(.key)=\(.value)"'
```

### Using with Environment Variables
```bash
# Export secret as environment variable
export API_KEY=$(vault kv get -field=value secret/dev/API_KEY)

# Load multiple secrets
eval $(vault kv get -format=json secret/dev/env | \
  jq -r '.data.data | to_entries[] | "export \(.key)=\(.value)"')
```

### Using in Scripts
```bash
#!/bin/bash
set -euo pipefail

# Authenticate (assuming VAULT_TOKEN is set)
if ! vault token lookup >/dev/null 2>&1; then
  echo "Error: Not authenticated with Vault"
  exit 1
fi

# Read secret
DB_PASSWORD=$(vault kv get -field=password secret/dev/database)

# Use secret in application
psql -h localhost -U admin -p 5432 <<EOF
  $(vault kv get -field=password secret/dev/database)
EOF
```

## Best Practices

1. **Never commit secrets to Git**: Always use Vault for secret storage
2. **Use specific paths**: Organize secrets by environment (dev, test, prod)
3. **Limit token TTL**: Set appropriate time-to-live for tokens
4. **Use policies**: Grant minimum necessary permissions
5. **Enable audit logging**: Track all secret access for security
6. **Rotate secrets regularly**: Update API keys and passwords periodically
7. **Use metadata**: Add descriptions and tags to secrets for documentation
8. **Version control**: KV v2 keeps secret versions for rollback capability

## References

- [Official Vault Documentation](https://www.vaultproject.io/docs)
- [Vault CLI Command Reference](https://www.vaultproject.io/docs/commands)
- [KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv)
- [Vault API Documentation](https://www.vaultproject.io/api-docs)
