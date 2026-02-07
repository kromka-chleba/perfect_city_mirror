#!/bin/bash
# Installation script for Lua testing dependencies
# This script installs Lua, LuaRocks, and busted for running unit tests

set -e

echo "Installing Lua testing dependencies..."

# Check if running on Ubuntu/Debian
if command -v apt-get &> /dev/null; then
    echo "Detected Debian/Ubuntu system"
    
    # Update package list
    sudo apt-get update
    
    # Install Lua 5.1 and LuaRocks
    echo "Installing Lua 5.1 and LuaRocks..."
    sudo apt-get install -y lua5.1 liblua5.1-0-dev luarocks
    
# Check if running on macOS
elif command -v brew &> /dev/null; then
    echo "Detected macOS system"
    
    # Install Lua and LuaRocks via Homebrew
    echo "Installing Lua and LuaRocks..."
    brew install lua@5.1 luarocks
    
# Check if running on Fedora/RHEL
elif command -v dnf &> /dev/null; then
    echo "Detected Fedora/RHEL system"
    
    # Install Lua and LuaRocks
    echo "Installing Lua 5.1 and LuaRocks..."
    sudo dnf install -y lua luarocks
    
else
    echo "Warning: Unsupported operating system. Please install Lua 5.1 and LuaRocks manually."
    echo "Visit: https://www.lua.org/download.html"
    echo "       https://luarocks.org/"
    exit 1
fi

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

echo ""
echo "Installation complete!"
echo ""
echo "To verify installation, run:"
echo "  busted --version"
echo ""
echo "To run tests, execute:"
echo "  ./mods/pcity_mapgen/tests/run_tests.sh"
