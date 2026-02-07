#!/bin/bash
# Test runner script for pcity_mapgen unit tests
# This script runs busted tests in the correct directory with proper Lua paths

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if busted is installed
if ! command -v busted &> /dev/null; then
    echo "Error: busted is not installed or not in PATH"
    echo ""
    echo "Please run the installation script first:"
    echo "  ./install_test_deps.sh"
    echo ""
    echo "Or install busted manually:"
    echo "  luarocks install busted"
    echo ""
    echo "If you installed busted locally, make sure these are in your shell config:"
    echo "  export PATH=\$HOME/.luarocks/bin:\$PATH"
    echo "  export LUA_PATH='\$HOME/.luarocks/share/lua/5.1/?.lua;\$HOME/.luarocks/share/lua/5.1/?/init.lua;;\$LUA_PATH'"
    echo "  export LUA_CPATH='\$HOME/.luarocks/lib/lua/5.1/?.so;;\$LUA_CPATH'"
    exit 1
fi

# Print busted version
echo "Running tests with busted $(busted --version 2>&1 | head -1)"
echo ""

# Run busted with the tests directory as the working directory
# This allows require("test_helper") to work correctly
busted --pattern=_spec.lua "$@"

echo ""
echo "All tests completed successfully!"
