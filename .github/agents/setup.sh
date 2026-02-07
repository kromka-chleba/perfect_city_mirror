#!/bin/bash
# Setup script for GitHub Copilot Coding Agent
# This script installs dependencies needed to run tests for Perfect City

set -e

echo "=== Perfect City - Agent Environment Setup ==="
echo ""

# Check if we're running in a container/agent environment
if [ -f /.dockerenv ] || [ -n "$CODESPACE_NAME" ] || [ -n "$GITHUB_ACTIONS" ]; then
    echo "Running in containerized/CI environment"
    USE_SUDO="sudo"
else
    echo "Running in local environment"
    USE_SUDO=""
fi

# Check if luantiserver or minetestserver is already installed
if command -v luantiserver &> /dev/null; then
    echo "✓ luantiserver already installed"
    luantiserver --version
    exit 0
elif command -v minetestserver &> /dev/null; then
    echo "✓ minetestserver already installed"
    minetestserver --version
    exit 0
fi

echo "Installing Luanti/Minetest server..."
echo ""

# Detect OS and install appropriate package
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS. Please install luanti-server or minetest-server manually."
    exit 1
fi

case "$OS" in
    ubuntu|debian)
        echo "Detected Ubuntu/Debian"
        
        # Install software-properties-common for add-apt-repository
        if ! command -v add-apt-repository &> /dev/null; then
            echo "Installing software-properties-common..."
            $USE_SUDO apt-get update -qq
            $USE_SUDO apt-get install -y software-properties-common
        fi
        
        # Add Luanti PPA for latest stable version
        echo "Adding Luanti PPA for latest stable release..."
        $USE_SUDO add-apt-repository -y ppa:luanti/luanti
        $USE_SUDO apt-get update -qq
        
        # Install luanti-server (newer name for minetest-server)
        echo "Installing luanti-server from PPA..."
        if $USE_SUDO apt-get install -y luanti-server; then
            echo "✓ Installed luanti-server from PPA"
        else
            echo "✗ Failed to install Luanti server"
            exit 1
        fi
        ;;
    arch|manjaro)
        echo "Detected Arch Linux"
        $USE_SUDO pacman -Sy --noconfirm luanti || $USE_SUDO pacman -Sy --noconfirm minetest
        ;;
    fedora|rhel|centos)
        echo "Detected Fedora/RHEL/CentOS"
        $USE_SUDO dnf install -y minetest-server || $USE_SUDO yum install -y minetest-server
        ;;
    *)
        echo "Unsupported OS: $OS"
        echo "Please install luanti-server or minetest-server manually"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo "Verifying installation..."
if command -v luantiserver &> /dev/null; then
    echo "✓ luantiserver installed successfully"
    luantiserver --version
elif command -v minetestserver &> /dev/null; then
    echo "✓ minetestserver installed successfully"
    minetestserver --version
else
    echo "✗ Installation verification failed"
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo "You can now run tests with: cd mods/pcity_mapgen/tests && ./run_tests.sh"
