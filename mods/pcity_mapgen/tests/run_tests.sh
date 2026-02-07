#!/bin/bash
# Test runner script for pcity_mapgen
# Runs tests inside the Luanti engine
#
# Based on WorldEdit's test runner:
# https://github.com/Uberi/Minetest-WorldEdit
# Specifically: .util/run_tests.sh
#
# Copyright © 2012 sfan5, Anthony Zhang (Uberi/Temperest), and Brett O'Donnell (cornernote)
# Copyright (C) 2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# ---
#
# This implementation follows WorldEdit's pattern of:
# - Creating a temporary world with singlenode mapgen
# - Starting luantiserver with test settings enabled
# - Checking for a test success marker file
# - Cleaning up temporary files on exit
#
# The script has been adapted and extended for Perfect City's test infrastructure.

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

# Find minetestserver or minetest/luanti binary
mtserver=$(command -v minetestserver)
[ -z "$mtserver" ] && mtserver=$(command -v minetest)

# Check if we need to add --server flag (for minetest/luanti binary)
server_flag=""
if [ -z "$mtserver" ]; then
    echo "Error: minetestserver or minetest binary not found in PATH" >&2
    exit 1
fi

# If using minetest/luanti binary (not minetestserver), add --server flag
if [[ "$mtserver" == *"minetest"* ]] && [[ "$mtserver" != *"minetestserver"* ]]; then
    server_flag="--server"
fi

echo "Using server: $mtserver $server_flag"
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
$mtserver $server_flag --config "$confpath" --world "$worldpath" --logfile /dev/null 2>&1 || true

echo "---"

# Check if tests passed
if [ -f "$worldpath/tests_ok" ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Tests failed or did not complete"
    exit 1
fi
