#!/bin/bash
# Script to set host environment variables for DevContainer
# Run this on your HOST machine before opening the DevContainer
# Usage: source .devcontainer/set-host-env.sh

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting DevContainer environment variables...${NC}"

# Read from .env file if it exists
if [ -f ".env" ]; then
    echo -e "${GREEN}Loading values from .env file...${NC}"
    
    # Extract WORKSPACE_NAME from .env
    if grep -q "^WORKSPACE_NAME=" .env; then
        export WORKSPACE_NAME=$(grep "^WORKSPACE_NAME=" .env | cut -d '=' -f 2)
        echo "Set WORKSPACE_NAME=${WORKSPACE_NAME}"
    else
        echo -e "${YELLOW}WORKSPACE_NAME not found in .env, using default: diamonds_project${NC}"
        export WORKSPACE_NAME=diamonds_project
    fi
    
    # Extract DIAMOND_NAME from .env
    if grep -q "^DIAMOND_NAME=" .env; then
        export DIAMOND_NAME=$(grep "^DIAMOND_NAME=" .env | cut -d '=' -f 2)
        echo "Set DIAMOND_NAME=${DIAMOND_NAME}"
    else
        echo -e "${YELLOW}DIAMOND_NAME not found in .env, using default: ExampleDiamond${NC}"
        export DIAMOND_NAME=ExampleDiamond
    fi
else
    echo -e "${YELLOW}.env file not found, using defaults${NC}"
    export WORKSPACE_NAME=diamonds_project
    export DIAMOND_NAME=ExampleDiamond
fi

echo ""
echo -e "${GREEN}Environment variables set successfully!${NC}"
echo "WORKSPACE_NAME=${WORKSPACE_NAME}"
echo "DIAMOND_NAME=${DIAMOND_NAME}"
echo ""
echo "You can now open the DevContainer in VS Code."
echo "The container will use these values during build."
