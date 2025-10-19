# HashiCorp Vault Setup Guide for Diamonds Project DevContainer

This guide provides comprehensive instructions for setting up and using HashiCorp Vault for secure secret management in the Diamonds Project development environment.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Vault Architecture](#vault-architecture)
5. [Environment Configuration](#environment-configuration)
6. [Secret Management](#secret-management)
7. [DevContainer Integration](#devcontainer-integration)
8. [Troubleshooting](#troubleshooting)
9. [Security Considerations](#security-considerations)

## Overview

The Diamonds Project project uses HashiCorp Vault for secure secret management in development and CI/CD environments. Vault provides:

- **Secure Storage**: Encrypted storage of sensitive data (API keys, private keys, tokens)
- **Access Control**: Role-based access control with GitHub authentication
- **Audit Logging**: Complete audit trail of secret access
- **Dynamic Secrets**: On-demand secret generation and rotation
- **Multi-Environment Support**: Separate secret paths for dev/staging/production

### Key Benefits

- **Enhanced Security**: Secrets never stored in code or plain text files
- **Compliance**: Audit trails and access controls for regulatory compliance
- **Developer Experience**: Seamless integration with existing development workflows
- **CI/CD Integration**: Automated secret injection in deployment pipelines

## Prerequisites

### System Requirements

- Docker and Docker Compose
- GitHub account with repository access
- Node.js 18+ (for development tooling)
- Bash shell environment

### Vault Access

- GitHub Personal Access Token with `repo` scope
- Access to Diamonds Project GitHub organization
- VPN access (if required for corporate networks)

## Quick Start

### 1. Environment Setup

```bash
# Clone the repository
git clone https://github.com/GeniusVentures/diamonds-base.git
cd diamonds-base

# Set up GitHub token for Vault authentication
export GITHUB_TOKEN=your_github_token_here

# Start the development environment
docker-compose up -d

# Open in VS Code DevContainer
code .
```

### 2. Verify Vault Integration

```bash
# Run environment validation
./.devcontainer/scripts/test-env.sh

# Check Vault status
./.devcontainer/scripts/validate-vault-setup.sh

# Fetch secrets manually
./.devcontainer/scripts/vault-fetch-secrets.sh
```

### 3. Development Workflow

Once set up, Vault integration works transparently:

- Secrets are automatically loaded on container startup
- Environment variables are available in your development session
- Secrets refresh every 5 minutes to pick up updates

## Vault Architecture

### Service Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DevContainer  │────│     Vault       │────│   GitHub Auth   │
│                 │    │   (vault-dev)   │    │                 │
│ • post-create.sh│    │ • KV Secrets    │    │ • Token Auth    │
│ • post-start.sh │    │ • GitHub Auth   │    │ • User Mapping  │
│ • test-env.sh   │    │ • Policies      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Secret Store  │
                    │                 │
                    │ • private keys  │
                    │ • API tokens    │
                    │ • RPC URLs      │
                    │ • credentials   │
                    └─────────────────┘
```

### Secret Path Structure

```
secret/dev/
├── PRIVATE_KEY              # Main deployment private key
├── TEST_PRIVATE_KEY         # Test network private key
├── RPC_URL                  # Mainnet RPC URL
├── INFURA_API_KEY           # Infura API key
├── ALCHEMY_API_KEY          # Alchemy API key
├── ETHERSCAN_API_KEY        # Etherscan API key
├── GITHUB_TOKEN             # GitHub API token
├── SNYK_TOKEN               # Snyk security token
└── SOCKET_CLI_API_TOKEN     # Socket CLI token
```

### Authentication Flow

1. **GitHub Token**: Developer provides GitHub Personal Access Token
2. **Vault Login**: Token exchanged for Vault authentication
3. **Policy Application**: User-specific policies applied
4. **Secret Access**: Encrypted secrets retrieved via KV engine
5. **Environment Injection**: Secrets exported as environment variables

## Environment Configuration

### Required Environment Variables

```bash
# Vault Configuration
VAULT_ADDR=http://vault-dev:8200          # Vault server address
GITHUB_TOKEN=ghp_...                      # GitHub Personal Access Token

# Optional Configuration
FALLBACK_TO_ENV=true                      # Enable .env fallback
ENV_FILE=../../.env                       # Path to fallback .env file
```

### Docker Compose Configuration

The `docker-compose.yml` includes:

```yaml
services:
  vault-dev:
    image: hashicorp/vault:latest
    environment:
      - VAULT_DEV_ROOT_TOKEN_ID=dev-token
      - VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
    ports:
      - "8200:8200"
    volumes:
      - vault-data:/vault/data
    cap_add:
      - IPC_LOCK
```

### DevContainer Configuration

The `.devcontainer/devcontainer.json` includes:

```json
{
  "postCreateCommand": "./.devcontainer/scripts/post-create.sh",
  "postStartCommand": "./.devcontainer/scripts/post-start.sh",
  "remoteEnv": {
    "VAULT_ADDR": "http://vault-dev:8200"
  }
}
```

## Secret Management

### Adding New Secrets

1. **Authenticate with Vault**:
   ```bash
   vault login -method=github token=$GITHUB_TOKEN
   ```

2. **Add a secret**:
   ```bash
   vault kv put secret/dev/NEW_SECRET_KEY value="your-secret-value"
   ```

3. **Verify the secret**:
   ```bash
   vault kv get secret/dev/NEW_SECRET_KEY
   ```

### Updating Secrets

```bash
# Update existing secret
vault kv put secret/dev/EXISTING_KEY value="new-value"

# Secrets automatically refresh in DevContainer (every 5 minutes)
# Or force refresh immediately
./.devcontainer/scripts/vault-fetch-secrets.sh --quiet
```

### Secret Rotation

For enhanced security, rotate secrets regularly:

```bash
# Generate new API key from provider
# Update in Vault
vault kv put secret/dev/API_KEY value="new-key"

# Update any external references
# Verify applications still work
./.devcontainer/scripts/test-env.sh
```

## DevContainer Integration

### Lifecycle Hooks

#### post-create.sh
- Runs once when DevContainer is created
- Installs dependencies and sets up development environment
- Calls vault-fetch-secrets.sh to load initial secrets

#### post-start.sh
- Runs every time DevContainer starts
- Performs health checks (including Vault connectivity)
- Refreshes secrets if needed (every 5 minutes)

#### test-env.sh
- Validates environment configuration
- Tests Vault connectivity and authentication
- Verifies secret accessibility

### Automatic Fallback

When Vault is unavailable, the system gracefully falls back to `.env` file:

1. **Vault Unavailable**: Connection check fails
2. **Fallback Triggered**: Scripts load from `.env` file
3. **Warning Displayed**: User notified of fallback mode
4. **Continued Operation**: Development workflow uninterrupted

### Error Handling

The integration includes comprehensive error handling:

- **Network Issues**: Automatic retry with exponential backoff
- **Authentication Failures**: Clear error messages with resolution steps
- **Missing Secrets**: Graceful degradation with available secrets
- **Permission Issues**: Detailed logging for troubleshooting

## Troubleshooting

### Common Issues

#### Vault Not Accessible

**Symptoms**: `Vault is not available` warnings

**Solutions**:
```bash
# Check if Vault container is running
docker-compose ps vault-dev

# Restart Vault service
docker-compose restart vault-dev

# Check Vault logs
docker-compose logs vault-dev

# Verify network connectivity
curl http://vault-dev:8200/v1/sys/health
```

#### Authentication Failed

**Symptoms**: `Vault authentication failed` errors

**Solutions**:
```bash
# Verify GitHub token
echo $GITHUB_TOKEN | head -c 10  # Should start with ghp_

# Check token permissions (needs repo scope)
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/user

# Try manual authentication
vault login -method=github token=$GITHUB_TOKEN
```

#### Secrets Not Loading

**Symptoms**: Environment variables not set

**Solutions**:
```bash
# Check Vault status
vault status

# Verify secret exists
vault kv list secret/dev

# Check authentication
vault token lookup

# Force secret refresh
./.devcontainer/scripts/vault-fetch-secrets.sh
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Run with debug output
export DEBUG=true
./.devcontainer/scripts/validate-vault-setup.sh

# Check detailed logs
tail -f logs/vault-debug.log
```

### Recovery Procedures

#### Complete Vault Reset

```bash
# Stop all services
docker-compose down

# Remove Vault data
docker volume rm <PROJECT_NAME>_vault-data

# Restart environment
docker-compose up -d

# Reinitialize Vault
./scripts/setup/init-vault.sh
```

#### Emergency .env Fallback

If Vault is completely unavailable:

```bash
# Disable Vault integration
export FALLBACK_TO_ENV=true

# Ensure .env file exists with required secrets
ls -la .env

# Run setup without Vault
./.devcontainer/scripts/post-create.sh --no-vault
```

## Security Considerations

### Access Control

- **GitHub Authentication**: Only authorized repository members can access secrets
- **Path-Based Policies**: Users only see secrets they need
- **Token Expiration**: GitHub tokens expire, requiring re-authentication
- **Audit Logging**: All secret access is logged and auditable

### Best Practices

#### Developer Guidelines

1. **Never Commit Secrets**: Use Vault for all sensitive data
2. **Rotate Regularly**: Change secrets every 30-90 days
3. **Principle of Least Privilege**: Only access required secrets
4. **Monitor Access**: Review audit logs regularly

#### Operational Security

1. **Network Security**: Use VPN for corporate environments
2. **Token Management**: Store GitHub tokens securely
3. **Backup Strategy**: Regular Vault data backups
4. **Incident Response**: Defined procedures for security incidents

### Compliance

The Vault integration supports:

- **SOC 2**: Audit trails and access controls
- **GDPR**: Data encryption and access logging
- **Industry Standards**: Secure secret management practices

## Advanced Configuration

### Custom Vault Policies

Create organization-specific policies:

```hcl
# policy.hcl
path "secret/dev/*" {
  capabilities = ["read", "list"]
}

path "secret/dev/PRIVATE_KEY" {
  capabilities = ["deny"]
}
```

### Multi-Environment Setup

Configure different Vault instances for each environment:

```bash
# Development
export VAULT_ADDR=http://vault-dev:8200

# Staging
export VAULT_ADDR=https://vault-staging.company.com

# Production
export VAULT_ADDR=https://vault.company.com
```

### CI/CD Integration

Integrate with GitHub Actions:

```yaml
# .github/workflows/deploy.yml
- name: Authenticate to Vault
  run: |
    vault login -method=github token=${{ secrets.GITHUB_TOKEN }}

- name: Fetch Secrets
  run: |
    ./scripts/vault-fetch-secrets.sh --quiet
```

## Support

### Getting Help

1. **Documentation**: Check this guide and related docs
2. **Team Chat**: Ask in #devops or #security channels
3. **Issue Tracking**: Create GitHub issue with `vault` label
4. **Security Issues**: Contact security team directly

### Resources

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Diamonds Project Security Guidelines](../../SECURITY.md)
- [DevContainer Troubleshooting](VAULT_TROUBLESHOOTING.md)
- [CI/CD Pipeline Documentation](../../docs/CI-PIPELINE.md)

---

**Last Updated**: October 2025
**Version**: 1.0
**Maintainer**: Diamonds DevOps Team</content>