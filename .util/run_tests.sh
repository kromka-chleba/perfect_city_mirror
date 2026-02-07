#!/bin/bash
# Test runner script for pcity_mapgen
# Based on WorldEdit's test runner
# https://github.com/Uberi/Minetest-WorldEdit/blob/master/.util/run_tests.sh

set -e

tempdir=$(mktemp -d)
confpath=$tempdir/minetest.conf
worldpath=$tempdir/world

trap 'rm -rf "$tempdir"' EXIT

[ -f mods/pcity_mapgen/mod.conf ] || { echo "Must be run from repository root." >&2; exit 1; }

# Find minetest/luanti binary
mtserver=$(command -v minetest)
[ -z "$mtserver" ] && mtserver=$(command -v luanti)
[ -z "$mtserver" ] && { echo "minetest or luanti binary not found in PATH." >&2; exit 1; }

echo "Using binary: $mtserver"

mkdir -p "$worldpath"
printf '%s\n' 'mg_name = singlenode' '[end_of_params]' > "$worldpath/map_meta.txt"
printf '%s\n' 'pcity_run_tests = true' 'max_forceloaded_blocks = 9999' > "$confpath"

mkdir -p "$worldpath/worldmods"
ln -s "$(pwd)/mods/pcity_mapgen" "$worldpath/worldmods/pcity_mapgen"

echo "Starting test run..."
$mtserver --server --config "$confpath" --world "$worldpath" --logfile /dev/null

test -f "$worldpath/tests_ok" || exit 1
exit 0
