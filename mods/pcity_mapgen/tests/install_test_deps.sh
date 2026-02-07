#!/bin/bash
# Installation script for Lua testing dependencies
# This script installs LuaJIT, LuaRocks, busted, and fetches Luanti for its built-in Lua modules
# LuaJIT is used because Luanti/Minetest uses LuaJIT

set -e

echo "Installing Lua testing dependencies..."

# Check if running on Ubuntu/Debian
if command -v apt-get &> /dev/null; then
    echo "Detected Debian/Ubuntu system"
    
    # Update package list
    sudo apt-get update
    
    # Install LuaJIT, LuaRocks, and git
    echo "Installing LuaJIT, LuaRocks, and git..."
    sudo apt-get install -y luajit libluajit-5.1-dev luarocks git
    
    # Make LuaJIT the default Lua interpreter for LuaRocks if not already
    if ! luarocks config | grep -q "luajit"; then
        echo "Configuring LuaRocks to use LuaJIT..."
        luarocks config lua_interpreter luajit 2>/dev/null || true
    fi
    
# Check if running on macOS
elif command -v brew &> /dev/null; then
    echo "Detected macOS system"
    
    # Install LuaJIT, LuaRocks, and git via Homebrew
    echo "Installing LuaJIT, LuaRocks, and git..."
    brew install luajit luarocks git
    
# Check if running on Fedora/RHEL
elif command -v dnf &> /dev/null; then
    echo "Detected Fedora/RHEL system"
    
    # Install LuaJIT, LuaRocks, and git
    echo "Installing LuaJIT, LuaRocks, and git..."
    sudo dnf install -y luajit luajit-devel luarocks git
    
else
    echo "Warning: Unsupported operating system. Please install LuaJIT, LuaRocks, and git manually."
    echo "Visit: https://luajit.org/download.html"
    echo "       https://luarocks.org/"
    echo "       https://git-scm.com/"
    exit 1
fi

# Verify LuaJIT is installed
if ! command -v luajit &> /dev/null; then
    echo "Error: LuaJIT installation failed or luajit command not found."
    exit 1
fi

echo "LuaJIT version: $(luajit -v)"

# Install busted via LuaRocks
echo "Installing busted testing framework..."
if command -v luarocks &> /dev/null; then
    # Install busted (may need --local flag if not running as root)
    if luarocks install busted 2>/dev/null; then
        echo "Busted installed globally"
    else
        echo "Installing busted locally (in ~/.luarocks)..."
        luarocks install --local busted
        
        # Add local LuaRocks to PATH if not already there
        if ! echo "$PATH" | grep -q ".luarocks/bin"; then
            echo ""
            echo "Note: Add the following to your ~/.bashrc or ~/.zshrc:"
            echo "export PATH=\$HOME/.luarocks/bin:\$PATH"
            echo "export LUA_PATH='\$HOME/.luarocks/share/lua/5.1/?.lua;\$HOME/.luarocks/share/lua/5.1/?/init.lua;;\$LUA_PATH'"
            echo "export LUA_CPATH='\$HOME/.luarocks/lib/lua/5.1/?.so;;\$LUA_CPATH'"
        fi
    fi
else
    echo "Error: luarocks not found. Please install LuaRocks manually."
    exit 1
fi

# Clone Luanti repository to get built-in Lua modules
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LUANTI_DIR="$SCRIPT_DIR/luanti"
LUANTI_VERSION="5.10.0"

if [ -d "$LUANTI_DIR" ]; then
    echo ""
    echo "Luanti directory already exists. Checking version..."
    cd "$LUANTI_DIR"
    CURRENT_TAG=$(git describe --tags 2>/dev/null || echo "unknown")
    if [ "$CURRENT_TAG" = "$LUANTI_VERSION" ]; then
        echo "Luanti version $LUANTI_VERSION already installed."
    else
        echo "Updating to Luanti version $LUANTI_VERSION..."
        git fetch --tags
        git checkout "$LUANTI_VERSION"
    fi
    cd "$SCRIPT_DIR"
else
    echo ""
    echo "Cloning Luanti repository version $LUANTI_VERSION for built-in Lua modules..."
    git clone --depth=1 --branch="$LUANTI_VERSION" https://github.com/luanti-org/luanti.git "$LUANTI_DIR"
    
    # Verify the clone was successful
    if [ ! -f "$LUANTI_DIR/builtin/common/vector.lua" ]; then
        echo "Error: Failed to clone Luanti or vector.lua not found."
        echo "Please check your internet connection and try again."
        exit 1
    fi
fi

echo "Luanti version: $LUANTI_VERSION"

echo ""
echo "Installation complete!"
echo ""
echo "To verify installation, run:"
echo "  luajit -v"
echo "  busted --version"
echo ""
echo "To run tests, execute:"
echo "  ./mods/pcity_mapgen/tests/run_tests.sh"
