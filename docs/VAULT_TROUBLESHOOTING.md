# Vault Troubleshooting Guide for Diamonds Project

This guide provides step-by-step solutions for common HashiCorp Vault integration issues in the Diamonds Project development environment.

## Quick Diagnosis

### Run Diagnostic Script

```bash
# Comprehensive Vault diagnostics
./.devcontainer/scripts/validate-vault-setup.sh

# Environment validation
./.devcontainer/scripts/test-env.sh

# Manual secret fetch
./.devcontainer/scripts/vault-fetch-secrets.sh
```

### Check System Status

```bash
# Vault container status
docker-compose ps vault-dev

# Vault service health
curl http://vault-dev:8200/v1/sys/health

# Network connectivity
ping vault-dev

# Environment variables
echo "VAULT_ADDR: $VAULT_ADDR"
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:0:10}..."
```

## Common Issues and Solutions

### Issue 1: Vault Container Not Running

**Symptoms:**
- `ERROR: Vault is not available at http://vault-dev:8200`
- `Connection refused` errors
- Vault commands fail with network errors

**Diagnosis:**
```bash
docker-compose ps vault-dev
# Should show: vault-dev running
```

**Solutions:**

1. **Start Vault Service:**
   ```bash
   docker-compose up -d vault-dev
   ```

2. **Check Container Logs:**
   ```bash
   docker-compose logs vault-dev
   ```

3. **Restart Services:**
   ```bash
   docker-compose down
   docker-compose up -d
   ```

4. **Check Docker Resources:**
   ```bash
   docker system df
   docker container ls -a
   ```

### Issue 2: GitHub Authentication Failed

**Symptoms:**
- `Vault authentication failed, falling back to .env`
- `GitHub authentication failed` errors
- `GITHUB_TOKEN not set` warnings

**Diagnosis:**
```bash
# Check token exists
echo $GITHUB_TOKEN

# Check token format (should start with ghp_)
echo $GITHUB_TOKEN | head -c 10

# Test token validity
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/user
```

**Solutions:**

1. **Generate New GitHub Token:**
   - Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
   - Create token with `repo` scope
   - Copy token and set environment variable

2. **Set Environment Variable:**
   ```bash
   export GITHUB_TOKEN=ghp_your_token_here
   echo "export GITHUB_TOKEN=$GITHUB_TOKEN" >> ~/.bashrc
   ```

3. **Verify Token Permissions:**
   ```bash
   # Test repository access
   curl -H "Authorization: token $GITHUB_TOKEN" \
        https://api.github.com/repos/<ORG-NAME>/<REPO-NAME>
   ```

4. **Check Organization Membership:**
   - Ensure you're a member of the Diamonds Project GitHub organization
   - Verify token has access to private repositories

### Issue 3: Secrets Not Loading

**Symptoms:**
- Environment variables not set after container start
- `Critical secrets missing` errors
- Applications can't find required secrets

**Diagnosis:**
```bash
# Check Vault authentication
vault status

# List available secrets
vault kv list secret/dev

# Check specific secret
vault kv get secret/dev/PRIVATE_KEY

# Verify environment variables
echo $PRIVATE_KEY | head -c 10  # Should show start of key
```

**Solutions:**

1. **Re-authenticate with Vault:**
   ```bash
   vault login -method=github token=$GITHUB_TOKEN
   ```

2. **Check Secret Paths:**
   ```bash
   # List all secrets
   vault kv list secret/dev

   # Verify expected secrets exist
   vault kv get secret/dev/PRIVATE_KEY
   vault kv get secret/dev/TEST_PRIVATE_KEY
   ```

3. **Force Secret Refresh:**
   ```bash
   ./.devcontainer/scripts/vault-fetch-secrets.sh
   ```

4. **Check File Permissions:**
   ```bash
   ls -la ./.devcontainer/scripts/vault-fetch-secrets.sh
   chmod +x ./.devcontainer/scripts/vault-fetch-secrets.sh
   ```

### Issue 4: Fallback to .env Not Working

**Symptoms:**
- Vault fails and .env fallback doesn't load secrets
- `Fallback .env file not found` errors
- Environment variables still missing after fallback

**Diagnosis:**
```bash
# Check .env file exists
ls -la .env

# Check .env file contents
head -10 .env

# Test manual sourcing
source .env
echo $TEST_PRIVATE_KEY
```

**Solutions:**

1. **Verify .env File Location:**
   ```bash
   # Should be in project root
   ls -la <WORKSPACE_name>/.env
   ```

2. **Check .env File Format:**
   ```bash
   # File should contain KEY=VALUE pairs
   cat .env | grep -E "^[A-Z_]+="
   ```

3. **Fix .env File Permissions:**
   ```bash
   chmod 600 .env
   ```

4. **Test Manual Fallback:**
   ```bash
   ./.devcontainer/scripts/vault-fetch-secrets.sh --no-fallback
   # Should show .env loading messages
   ```

### Issue 5: Network Connectivity Problems

**Symptoms:**
- `Connection timed out` errors
- `Network is unreachable` messages
- Intermittent connectivity issues

**Diagnosis:**
```bash
# Test basic connectivity
ping vault-dev

# Test Vault port
nc -zv vault-dev 8200

# Check Docker network
docker network ls
docker inspect bridge

# Test with different address
curl http://localhost:8200/v1/sys/health
```

**Solutions:**

1. **Check Docker Network:**
   ```bash
   # Verify containers are on same network
   docker-compose ps
   docker network inspect <PROJECT_NAME>_default
   ```

2. **Restart Network:**
   ```bash
   docker-compose down
   docker network prune
   docker-compose up -d
   ```

3. **Check Firewall Settings:**
   ```bash
   # Linux firewall
   sudo ufw status
   sudo iptables -L

   # Disable firewall temporarily for testing
   sudo ufw disable
   ```

4. **VPN/Network Issues:**
   - Ensure VPN is connected (if required)
   - Check proxy settings
   - Verify DNS resolution

### Issue 6: Permission Denied Errors

**Symptoms:**
- `Permission denied` when accessing secrets
- `access denied` in Vault logs
- Scripts fail with permission errors

**Diagnosis:**
```bash
# Check Vault policies
vault policy list

# Check token capabilities
vault token lookup

# Test specific path access
vault kv get secret/dev/PRIVATE_KEY
```

**Solutions:**

1. **Check GitHub Organization Membership:**
   - Ensure you're a member of Diamonds Project organization
   - Verify organization approval for private repos

2. **Re-authenticate:**
   ```bash
   vault login -method=github token=$GITHUB_TOKEN
   ```

3. **Check Token Scopes:**
   - GitHub token must have `repo` scope
   - Regenerate token if scopes are incorrect

4. **Verify Repository Access:**
   ```bash
   # Test API access
   curl -H "Authorization: token $GITHUB_TOKEN" \
        https://api.github.com/user/repos
   ```

### Issue 7: Container Lifecycle Issues

**Symptoms:**
- Secrets not available after container restart
- post-start.sh fails silently
- Environment variables lost between sessions

**Diagnosis:**
```bash
# Check container logs
docker-compose logs devcontainer

# Test post-start script manually
./.devcontainer/scripts/post-start.sh

# Check environment persistence
echo $PRIVATE_KEY
```

**Solutions:**

1. **Check Script Permissions:**
   ```bash
   ls -la ./.devcontainer/scripts/
   chmod +x ./.devcontainer/scripts/*.sh
   ```

2. **Test Individual Scripts:**
   ```bash
   # Test post-create
   ./.devcontainer/scripts/post-create.sh

   # Test post-start
   ./.devcontainer/scripts/post-start.sh

   # Test environment validation
   ./.devcontainer/scripts/test-env.sh
   ```

3. **Check DevContainer Configuration:**
   ```bash
   cat .devcontainer/devcontainer.json
   # Verify postCreateCommand and postStartCommand
   ```

4. **Manual Environment Setup:**
   ```bash
   # Force secret loading
   ./.devcontainer/scripts/vault-fetch-secrets.sh

   # Export to persistent environment
   ./.devcontainer/scripts/vault-fetch-secrets.sh --export
   ```

## Advanced Troubleshooting

### Debug Logging

Enable detailed logging for investigation:

```bash
# Enable debug mode
export DEBUG=true
export VAULT_LOG_LEVEL=debug

# Run with verbose output
./.devcontainer/scripts/validate-vault-setup.sh

# Check logs
tail -f logs/vault-debug.log
tail -f logs/hook-performance.log
```

### Vault Server Logs

Check Vault internal logs:

```bash
# Container logs
docker-compose logs -f vault-dev

# Vault audit logs (if enabled)
docker exec vault-dev tail -f /vault/logs/audit.log
```

### Network Debugging

Advanced network diagnostics:

```bash
# TCP connection test
timeout 5 bash -c "</dev/tcp/vault-dev/8200" && echo "Port open" || echo "Port closed"

# DNS resolution
nslookup vault-dev

# Route table
ip route show

# Network interfaces
ip addr show
```

### Environment Inspection

Check complete environment state:

```bash
# All environment variables
env | grep -E "(VAULT|GITHUB|PRIVATE|API)" | sort

# Process environment
ps aux | grep vault

# Docker environment
docker exec <PROJECT_NAME>-devcontainer-1 env
```

## Recovery Procedures

### Emergency .env Mode

When Vault is completely unavailable:

```bash
# Force .env fallback
export FALLBACK_TO_ENV=true
export VAULT_ADDR=""

# Ensure .env has all required secrets
cat > .env << EOF
PRIVATE_KEY=your_private_key_here
TEST_PRIVATE_KEY=your_test_key_here
INFURA_API_KEY=your_infura_key
# ... other secrets
EOF

# Run setup
./.devcontainer/scripts/post-create.sh --skip-vault
```

### Vault Data Reset

Complete Vault reset (use with caution):

```bash
# Stop all services
docker-compose down

# Remove Vault data volume
docker volume rm <PROJECT_NAME>_vault-data

# Clean up containers
docker system prune -f

# Restart environment
docker-compose up -d

# Reinitialize Vault
./scripts/setup/init-vault.sh
```

### Clean Rebuild

Complete environment rebuild:

```bash
# Full cleanup
docker-compose down -v --remove-orphans
docker system prune -f
docker volume prune -f

# Fresh start
rm -rf node_modules .next
npm install
docker-compose up --build -d
```

## Prevention and Monitoring

### Regular Maintenance

```bash
# Weekly checks
./.devcontainer/scripts/validate-vault-setup.sh

# Monitor disk usage
docker system df

# Check for updates
docker-compose pull
```

### Proactive Monitoring

Set up monitoring alerts:

```bash
# Health check script
#!/bin/bash
if ! curl -s http://vault-dev:8200/v1/sys/health > /dev/null; then
    echo "Vault health check failed" | mail -s "Vault Alert" admin@example.com
fi
```

### Backup Strategy

Regular Vault backups:

```bash
# Backup Vault data
docker run --rm -v <PROJECT_NAME>_vault-data:/vault-data \
  alpine tar czf - -C /vault-data . > vault-backup-$(date +%Y%m%d).tar.gz

# Store backups securely
aws s3 cp vault-backup-*.tar.gz s3://diamonds-backups/
```

## Getting Help

### Escalation Path

1. **Self-Service**: Check this troubleshooting guide
2. **Team Support**: Ask in #devops Slack channel
3. **Documentation**: Review [VAULT_SETUP.md](VAULT_SETUP.md)
4. **Issue Tracking**: Create GitHub issue with `vault` label
5. **Security Team**: Contact for security-related issues

### Support Information

When reporting issues, include:

```bash
# System information
uname -a
docker --version
docker-compose --version

# Environment status
./.devcontainer/scripts/validate-vault-setup.sh

# Relevant logs
docker-compose logs vault-dev | tail -50
```

### Emergency Contacts

- **DevOps Team**: devops@example.com
- **Security Team**: security@example.com
- **Infrastructure**: infra@example.com

---

**Last Updated**: October 2024
**Version**: 1.0
**Maintainer**: Diamonds Project DevOps Team</content>
