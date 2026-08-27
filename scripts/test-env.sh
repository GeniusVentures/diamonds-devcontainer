#!/bin/bash
# Test script to verify environment variable setup
# Run inside the DevContainer to verify configuration

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== DevContainer Environment Variable Test ===${NC}\n"

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: Check DIAMOND_NAME
echo -e "${BLUE}Test 1: DIAMOND_NAME${NC}"
if [ -n "${DIAMOND_NAME:-}" ]; then
    echo -e "${GREEN}✓ PASS${NC} - DIAMOND_NAME is set: ${DIAMOND_NAME}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ INFO${NC} - DIAMOND_NAME not set in environment"
    
    # Check .env file
    if [ -f ".env" ] && grep -q "^DIAMOND_NAME=" .env; then
        DIAMOND_NAME_FROM_ENV=$(grep "^DIAMOND_NAME=" .env | cut -d '=' -f 2)
        echo -e "${GREEN}✓ PASS${NC} - DIAMOND_NAME found in .env: ${DIAMOND_NAME_FROM_ENV}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} - DIAMOND_NAME not found in environment or .env"
        ((TESTS_FAILED++))
    fi
fi

# Test 2: Check WORKSPACE_NAME  
echo -e "\n${BLUE}Test 2: WORKSPACE_NAME${NC}"
if [ -n "${WORKSPACE_NAME:-}" ]; then
    echo -e "${GREEN}✓ PASS${NC} - WORKSPACE_NAME is set: ${WORKSPACE_NAME}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ INFO${NC} - WORKSPACE_NAME not set in environment"
    
    # Check .env file
    if [ -f ".env" ] && grep -q "^WORKSPACE_NAME=" .env; then
        WORKSPACE_NAME_FROM_ENV=$(grep "^WORKSPACE_NAME=" .env | cut -d '=' -f 2)
        echo -e "${GREEN}✓ PASS${NC} - WORKSPACE_NAME found in .env: ${WORKSPACE_NAME_FROM_ENV}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠ WARN${NC} - WORKSPACE_NAME not found (using default: diamonds_project)"
        ((TESTS_PASSED++))
    fi
fi

# Test 3: Check current workspace directory
echo -e "\n${BLUE}Test 3: Workspace Directory${NC}"
CURRENT_DIR=$(basename "$PWD")
echo "Current directory: $PWD"
echo "Directory name: $CURRENT_DIR"
if [ "$CURRENT_DIR" = "diamonds_project" ] || [ "$CURRENT_DIR" = "diamonds_dev_env" ]; then
    echo -e "${GREEN}✓ PASS${NC} - In valid workspace directory"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ WARN${NC} - Unexpected workspace directory name"
    ((TESTS_PASSED++))
fi

# Test 4: Check .env file exists
echo -e "\n${BLUE}Test 4: .env File${NC}"
if [ -f ".env" ]; then
    echo -e "${GREEN}✓ PASS${NC} - .env file exists"
    ((TESTS_PASSED++))
    
    # Show relevant variables
    echo "Relevant .env variables:"
    grep -E "^(WORKSPACE_NAME|DIAMOND_NAME)=" .env || echo "  (none found)"
else
    echo -e "${RED}✗ FAIL${NC} - .env file not found"
    ((TESTS_FAILED++))
fi

# Test 5: Check Hardhat can read environment
echo -e "\n${BLUE}Test 5: Hardhat Configuration${NC}"
if command -v npx >/dev/null 2>&1; then
    if npx hardhat --version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC} - Hardhat is accessible"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} - Hardhat not working properly"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${RED}✗ FAIL${NC} - npx not found"
    ((TESTS_FAILED++))
fi

# Test 5.5: Check Vault CLI availability
echo -e "\n${BLUE}Test 5.5: Vault CLI${NC}"
if command -v vault >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} - Vault CLI is available"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ INFO${NC} - Vault CLI not found (optional for development)"
    ((TESTS_PASSED++))
fi

# Test 5.6: Check Vault connectivity
echo -e "\n${BLUE}Test 5.6: Vault Connectivity${NC}"
if command -v vault >/dev/null 2>&1; then
    if [[ -n "${VAULT_ADDR:-}" ]]; then
        if vault status >/dev/null 2>&1; then
            echo -e "${GREEN}✓ PASS${NC} - Vault is accessible at ${VAULT_ADDR}"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠ WARN${NC} - Vault not accessible at ${VAULT_ADDR:-localhost:8200}"
            echo -e "  Make sure Vault is running: docker-compose up vault-dev"
            ((TESTS_PASSED++))
        fi
    else
        echo -e "${YELLOW}⚠ INFO${NC} - VAULT_ADDR not set"
        ((TESTS_PASSED++))
    fi
else
    echo -e "${YELLOW}⚠ INFO${NC} - Vault CLI not available"
    ((TESTS_PASSED++))
fi

# Test 5.7: Check Vault authentication and secrets
echo -e "\n${BLUE}Test 5.7: Vault Secrets${NC}"
if command -v vault >/dev/null 2>&1 && [[ -n "${VAULT_ADDR:-}" ]]; then
    if vault status >/dev/null 2>&1; then
        if [[ -n "${VAULT_TOKEN:-}" ]] || [[ -f ~/.vault-token ]] || [[ -f .vault-token ]]; then
            if vault kv list secret/dev >/dev/null 2>&1; then
                echo -e "${GREEN}✓ PASS${NC} - Vault secrets are accessible"
                ((TESTS_PASSED++))
            else
                echo -e "${YELLOW}⚠ WARN${NC} - Vault authenticated but no secrets found in secret/dev"
                echo -e "  Run: ./scripts/setup/migrate-secrets-to-vault.sh"
                ((TESTS_PASSED++))
            fi
        else
            echo -e "${YELLOW}⚠ WARN${NC} - Vault accessible but not authenticated"
            echo -e "  Run: vault login -method=github token=\$(gh auth token)"
            ((TESTS_PASSED++))
        fi
    else
        echo -e "${YELLOW}⚠ INFO${NC} - Vault not accessible"
        ((TESTS_PASSED++))
    fi
else
    echo -e "${YELLOW}⚠ INFO${NC} - Vault not configured"
    ((TESTS_PASSED++))
fi

# Test 6: Check if contracts directory exists
echo -e "\n${BLUE}Test 6: Project Structure${NC}"
if [ -d "contracts" ] && [ -d "scripts" ] && [ -d "test" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Project structure looks good"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ WARN${NC} - Some project directories missing"
    ((TESTS_PASSED++))
fi

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    echo -e "\nEnvironment is properly configured."
    exit 0
else
    echo -e "\n${YELLOW}⚠ Some tests failed or have warnings.${NC}"
    echo -e "\nCheck the output above for details."
    echo -e "See .devcontainer/ENV_VARS.md for configuration help."
    exit 1
fi
