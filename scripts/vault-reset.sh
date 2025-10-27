#!/bin/bash
# Vault Reset Script
# Resets Vault to a clean state by removing persistent data
# Use this when Vault fails to start or is in a corrupted state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VAULT_DATA_DIR="${PROJECT_ROOT}/.devcontainer/data/vault-data"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}WARNING: This will delete all Vault data!${NC}"
echo "Location: $VAULT_DATA_DIR"
echo ""
echo "This includes:"
echo "  - All stored secrets"
echo "  - Unseal keys"
echo "  - Vault configuration"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${YELLOW}Stopping Vault container...${NC}"
docker compose -f "${PROJECT_ROOT}/.devcontainer/docker-compose.dev.yml" stop vault-dev 2>/dev/null || true

echo -e "${YELLOW}Removing Vault data...${NC}"
if [ -d "$VAULT_DATA_DIR" ]; then
    # Remove with sudo if needed (due to Docker file ownership)
    if rm -rf "$VAULT_DATA_DIR" 2>/dev/null; then
        echo -e "${GREEN}Vault data removed successfully${NC}"
    else
        echo -e "${YELLOW}Attempting with sudo...${NC}"
        sudo rm -rf "$VAULT_DATA_DIR"
        echo -e "${GREEN}Vault data removed successfully${NC}"
    fi
fi

# Recreate directory structure
mkdir -p "$VAULT_DATA_DIR"
touch "$VAULT_DATA_DIR/.gitkeep"

echo ""
echo -e "${GREEN}Vault has been reset!${NC}"
echo ""
echo "Next steps:"
echo "  1. Set Vault to ephemeral mode in .devcontainer/.env:"
echo "     VAULT_COMMAND=server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200"
echo ""
echo "  2. Restart the DevContainer or run:"
echo "     docker compose -f .devcontainer/docker-compose.dev.yml up vault-dev"
echo ""
echo "  3. Run the setup wizard to configure Vault:"
echo "     .devcontainer/scripts/setup/vault-setup-wizard.sh"
