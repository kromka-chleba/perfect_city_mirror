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
        $USE_SUDO apt-get update -qq
        # Try luanti-server first (newer name), fall back to minetest-server
        if $USE_SUDO apt-get install -y luanti-server 2>/dev/null; then
            echo "✓ Installed luanti-server"
        elif $USE_SUDO apt-get install -y minetest-server 2>/dev/null; then
            echo "✓ Installed minetest-server"
        else
            echo "✗ Failed to install Luanti/Minetest server"
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
