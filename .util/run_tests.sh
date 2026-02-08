#!/bin/bash
# Test runner script for pcity_mapgen
# Based on WorldEdit's test runner and minetest_game test patterns
# https://github.com/Uberi/Minetest-WorldEdit/blob/master/.util/run_tests.sh
# https://github.com/luanti-org/minetest_game/blob/master/utils/test/run.sh

set -e

gamedir="$(pwd)"
tempdir=$(mktemp -d)
confpath="$tempdir/minetest.conf"
worldpath="$tempdir/worlds/world"
gamepath="$tempdir/games/perfect_city"

trap 'rm -rf "$tempdir"' EXIT

[ -f mods/pcity_mapgen/mod.conf ] || { echo "Must be run from repository root." >&2; exit 1; }
[ -f game.conf ] || { echo "game.conf not found. Must be run from Perfect City game root." >&2; exit 1; }

# Find minetest/luanti binary
mtserver=$(command -v minetest)
[ -z "$mtserver" ] && mtserver=$(command -v luanti)
[ -z "$mtserver" ] && { echo "minetest or luanti binary not found in PATH." >&2; exit 1; }

echo "Using binary: $mtserver"

# Set up the game directory structure - use symlink to entire game directory
mkdir -p "$tempdir/games"
ln -s "$gamedir" "$gamepath"

# Create world directory
mkdir -p "$worldpath"
printf '%s\n' 'mg_name = singlenode' '[end_of_params]' > "$worldpath/map_meta.txt"

# Create minetest.conf with test settings
cat > "$confpath" << CONFEOF
pcity_run_tests = true
max_forceloaded_blocks = 9999
CONFEOF

echo "Starting test run..."
echo "Game dir: $gamedir"
echo "Temp dir: $tempdir"
echo "Game path: $gamepath"
echo "World path: $worldpath"

# Run with explicit paths - set HOME to tempdir so .minetest is created there
HOME="$tempdir" $mtserver --server --gameid "perfect_city" --config "$confpath" --world "$worldpath" --logfile /dev/null

test -f "$worldpath/tests_ok" || exit 1
exit 0
