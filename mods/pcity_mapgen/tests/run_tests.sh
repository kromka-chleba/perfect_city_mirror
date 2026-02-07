#!/bin/bash
# Test runner script for pcity_mapgen
# Runs tests inside the Luanti engine
# Based on WorldEdit's test runner: https://github.com/Uberi/Minetest-WorldEdit

set -e

tempdir=$(mktemp -d)
confpath=$tempdir/minetest.conf
worldpath=$tempdir/world

trap 'rm -rf "$tempdir"' EXIT

# Find the mod directory
moddir=$(dirname "$(readlink -f "$0")")
moddir=$(dirname "$moddir")  # Go up from tests/ to pcity_mapgen/

# Check if we're in the right place
[ -f "$moddir/mod.conf" ] || { echo "Error: Could not find mod.conf. Run this script from mods/pcity_mapgen/tests/" >&2; exit 1; }

# Find luantiserver or minetestserver
mtserver=$(command -v luantiserver)
[ -z "$mtserver" ] && mtserver=$(command -v minetestserver)
[ -z "$mtserver" ] && { echo "Error: luantiserver or minetestserver not found in PATH" >&2; exit 1; }

echo "Using server: $mtserver"
echo "Mod directory: $moddir"
echo "Temp directory: $tempdir"

# Create temporary world
mkdir -p "$worldpath"

# Create map_meta.txt with singlenode mapgen
cat > "$worldpath/map_meta.txt" << 'MAPEOF'
mg_name = singlenode
[end_of_params]
MAPEOF

# Create minetest.conf with test settings
cat > "$confpath" << 'CONFEOF'
pcity_run_tests = true
max_forceloaded_blocks = 9999
CONFEOF

# Create worldmods directory and symlink our mod
mkdir -p "$worldpath/worldmods"
ln -s "$moddir" "$worldpath/worldmods/pcity_mapgen"

echo "Starting test run..."
echo "---"

# Run the server
# Redirect stderr to stdout so we see everything
$mtserver --config "$confpath" --world "$worldpath" --logfile /dev/null 2>&1 || true

echo "---"

# Check if tests passed
if [ -f "$worldpath/tests_ok" ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Tests failed or did not complete"
    exit 1
fi
