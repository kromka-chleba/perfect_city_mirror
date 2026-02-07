#!/bin/bash
# Test runner script for pcity_mapgen
# Based on WorldEdit's test runner
# https://github.com/Uberi/Minetest-WorldEdit/blob/master/.util/run_tests.sh

set -e

tempdir=$(mktemp -d)
confpath=$tempdir/minetest.conf
worldpath=$tempdir/world
gamepath="$tempdir/games/Perfect City"

trap 'rm -rf "$tempdir"' EXIT

[ -f mods/pcity_mapgen/mod.conf ] || { echo "Must be run from repository root." >&2; exit 1; }
[ -f game.conf ] || { echo "game.conf not found. Must be run from Perfect City game root." >&2; exit 1; }

# Find minetest/luanti binary
mtserver=$(command -v minetest)
[ -z "$mtserver" ] && mtserver=$(command -v luanti)
[ -z "$mtserver" ] && { echo "minetest or luanti binary not found in PATH." >&2; exit 1; }

echo "Using binary: $mtserver"

# Set up the game directory structure
mkdir -p "$gamepath"
# Symlink essential game files and directories
ln -s "$(pwd)/game.conf" "$gamepath/"
ln -s "$(pwd)/mods" "$gamepath/"
[ -f settingtypes.txt ] && ln -s "$(pwd)/settingtypes.txt" "$gamepath/"
[ -d menu ] && ln -s "$(pwd)/menu" "$gamepath/"
[ -f minetest.conf ] && ln -s "$(pwd)/minetest.conf" "$gamepath/"

# Create world
mkdir -p "$worldpath"
printf '%s\n' 'mg_name = singlenode' '[end_of_params]' > "$worldpath/map_meta.txt"

# Create minetest.conf with test settings and game path
# Set path_user to tempdir so minetest looks for games in $tempdir/games
cat > "$confpath" << CONFEOF
pcity_run_tests = true
max_forceloaded_blocks = 9999
path_user = $tempdir
CONFEOF

echo "Starting test run..."
$mtserver --server --gameid "Perfect City" --config "$confpath" --world "$worldpath" --logfile /dev/null

test -f "$worldpath/tests_ok" || exit 1
exit 0
