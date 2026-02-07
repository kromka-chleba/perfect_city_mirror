#!/bin/bash -e
# Test runner for Perfect City game using Luanti Docker images
# Based on minetest_game test pattern
# https://github.com/luanti-org/minetest_game/blob/master/utils/test/run.sh

tmpdir=$(mktemp -d)
# Use || : to ignore errors on cleanup (e.g., permission denied on symlinks)
trap 'rm -rf "$tmpdir" 2>/dev/null || :' EXIT

[ -f game.conf ] || { echo "Must be run in game root folder." >&2; exit 1; }
[ -n "$DOCKER_IMAGE" ] || { echo "Specify a docker image." >&2; exit 1; }

mkdir -p "$tmpdir/world"
chmod -R 777 "$tmpdir" # container uses unprivileged user inside

vol=(
-v "$PWD/utils/test/minetest.conf":/etc/minetest/minetest.conf
-v "$tmpdir":/var/lib/minetest/.minetest
-v "$PWD":/var/lib/minetest/.minetest/games/perfect_city
)
docker run --rm -i "${vol[@]}" "$DOCKER_IMAGE" --config /etc/minetest/minetest.conf --gameid perfect_city

# Check if tests ran successfully (test creates tests_ok marker file)
test -f "$tmpdir/world/tests_ok"
