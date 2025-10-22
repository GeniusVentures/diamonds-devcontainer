#!/usr/bin/env bash
# Fallback script for installing HashiCorp Vault CLI
# Used when APT repository installation fails during Docker build
# Can be run manually from within the DevContainer

set -euo pipefail

# Logging functions
log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warning() {
    echo "[WARNING] $*"
}

# Check if we have sudo access
HAS_SUDO=false
if command -v sudo &> /dev/null && sudo -n true 2>/dev/null; then
    HAS_SUDO=true
    log_info "Running with sudo privileges"
elif [ "$EUID" -eq 0 ]; then
    HAS_SUDO=true
    log_info "Running as root"
else
    log_info "No sudo access - will attempt user-level installation"
fi

# Check if Vault is already installed
if command -v vault &> /dev/null; then
    INSTALLED_VERSION=$(vault version | head -n1 | awk '{print $2}' | sed 's/v//')
    log_success "Vault CLI already installed: $INSTALLED_VERSION"
    exit 0
fi

log_info "Installing HashiCorp Vault CLI..."

# Method 1: Try APT repository installation (requires sudo)
if [ "$HAS_SUDO" = true ]; then
    log_info "Attempting installation via HashiCorp APT repository..."
    
    # Detect the correct command prefix
    SUDO_CMD=""
    if [ "$EUID" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi
    
    # Download and add HashiCorp GPG key
    if wget -O - https://apt.releases.hashicorp.com/gpg | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null; then
        log_success "HashiCorp GPG key added"
    else
        log_error "Failed to download HashiCorp GPG key"
        log_info "Falling back to binary installation..."
        HAS_SUDO=false  # Force fallback to binary installation
    fi
    
    if [ "$HAS_SUDO" = true ]; then
        # Add HashiCorp repository
        CODENAME=$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release 2>/dev/null || lsb_release -cs 2>/dev/null || echo "bookworm")
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $CODENAME main" | $SUDO_CMD tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
        
        log_info "Updating package lists..."
        if $SUDO_CMD apt-get update 2>/dev/null; then
            log_info "Installing Vault via apt..."
            if $SUDO_CMD apt-get install -y vault 2>/dev/null; then
                log_success "Vault CLI installed via APT repository"
                vault --version
                exit 0
            else
                log_warning "APT installation failed, trying binary installation..."
                HAS_SUDO=false
            fi
        else
            log_warning "apt-get update failed, trying binary installation..."
            HAS_SUDO=false
        fi
    fi
fi

# Method 2: Binary installation (fallback)
log_info "Installing Vault CLI via binary download (fallback method)..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        VAULT_ARCH="amd64"
        ;;
    aarch64|arm64)
        VAULT_ARCH="arm64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Vault version to install
VAULT_VERSION="${VAULT_VERSION:-1.15.0}"
VAULT_URL="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${VAULT_ARCH}.zip"

log_info "Downloading Vault ${VAULT_VERSION} for ${VAULT_ARCH}..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if ! curl -fsSL "$VAULT_URL" -o "$TEMP_DIR/vault.zip"; then
    log_error "Failed to download Vault CLI from $VAULT_URL"
    log_error "Please check your internet connection"
    exit 1
fi

log_info "Extracting Vault CLI..."
if ! unzip -q "$TEMP_DIR/vault.zip" -d "$TEMP_DIR"; then
    log_error "Failed to extract Vault CLI"
    exit 1
fi

log_info "Installing Vault CLI..."
# Install to user's local bin directory (no sudo required)
mkdir -p "$HOME/.local/bin"
mv "$TEMP_DIR/vault" "$HOME/.local/bin/vault"
chmod +x "$HOME/.local/bin/vault"
INSTALL_PATH="$HOME/.local/bin/vault"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    log_info "Adding ~/.local/bin to PATH"
    
    # Add to .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    
    # Add to current session
    export PATH="$HOME/.local/bin:$PATH"
fi

log_success "Vault CLI installed successfully"
log_info "Installation path: $INSTALL_PATH"

# Verify installation
if command -v vault &> /dev/null; then
    INSTALLED_VERSION=$(vault version)
    log_success "Verification: $INSTALLED_VERSION"
else
    log_error "Vault CLI installation verification failed"
    log_error "Please restart your terminal or run: source ~/.bashrc"
    exit 1
fi

log_success "Vault CLI is ready to use!"
log_info "Try: vault version"

