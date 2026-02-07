# Perfect City - Agent Environment Guide

This guide helps GitHub Copilot Coding Agent understand and work with the Perfect City project.

## Project Overview

Perfect City is a psychological horror game built as a Luanti/Minetest game. It features:
- Procedural city generation
- Custom character models and textures
- In-engine unit testing system
- Multiple mods for nodes, mapgen, player API, etc.

## Repository Structure

```
perfect_city_mirror/
├── mods/
│   ├── pcity_mapgen/      # Main mapgen logic with 63 unit tests
│   │   ├── tests/         # Test suite (runs inside Luanti engine)
│   │   │   ├── run_tests.sh      # Test runner script
│   │   │   ├── init.lua          # Test registration
│   │   │   ├── tests_point.lua   # Point class tests (25)
│   │   │   └── tests_path.lua    # Path class tests (38)
│   │   ├── point.lua      # Point geometry class
│   │   ├── path.lua       # Path geometry class
│   │   └── ...            # Other mapgen files
│   ├── pcity_nodes/       # Node definitions
│   ├── pcity_environment/ # Sky and environment
│   ├── pcity_seba/        # Player character
│   └── player_api/        # Player API (modified from Minetest Game)
├── .github/
│   ├── workflows/         # GitHub Actions CI
│   └── agents/            # This directory - agent configuration
└── doc/                   # Documentation

```

## Testing System

### Prerequisites

Tests require **Luanti server** (`luantiserver`) or **Minetest server** (`minetestserver`).

**To install dependencies, run:**
```bash
./.github/agents/setup.sh
```

This script will:
- Detect your OS (Ubuntu/Debian/Arch/Fedora)
- Install luanti-server or minetest-server
- Verify installation

### Running Tests

**Quick test run:**
```bash
cd mods/pcity_mapgen/tests
./run_tests.sh
```

**What it does:**
1. Creates temporary world with singlenode mapgen
2. Starts luantiserver with `pcity_run_tests=true`
3. Tests execute inside the engine (using real Luanti APIs)
4. Creates `tests_ok` marker file on success
5. Returns exit code 0 on pass, 1 on fail

**Test output format:**
```
Running 63 tests for pcity_mapgen on Luanti 5.15.0
---- Point class ----------------------------------------------------
point.new                                                    pass
point.check                                                  pass
...
---- Path class -----------------------------------------------------
path.new                                                     pass
...
Results: 63 passed, 0 failed, 63 total
```

### Writing Tests

Tests are Lua functions using `assert()`:

```lua
function tests.test_something()
    local p = point.new(vector.new(1, 2, 3))
    assert(p ~= nil, "Point should be created")
    assert(p:get_x() == 1, "X coordinate should be 1")
end

-- Register the test
pcmg.register_test("test_something", tests.test_something)
```

## Development Workflow

When making code changes:

1. **Make changes** to Lua files in `mods/`
2. **Run tests** to verify: `cd mods/pcity_mapgen/tests && ./run_tests.sh`
3. **Check results** - All 63 tests should pass
4. **If tests fail** - Review the failure output and fix the issue

## Common Tasks

### Modifying Point class
- Edit: `mods/pcity_mapgen/point.lua`
- Tests: `mods/pcity_mapgen/tests/tests_point.lua` (25 tests)
- Run: `cd mods/pcity_mapgen/tests && ./run_tests.sh`

### Modifying Path class
- Edit: `mods/pcity_mapgen/path.lua`
- Tests: `mods/pcity_mapgen/tests/tests_path.lua` (38 tests)
- Run: `cd mods/pcity_mapgen/tests && ./run_tests.sh`

### Adding new nodes
- Edit: `mods/pcity_nodes/*.lua`
- No automated tests yet for nodes

## API Reference

### Core Namespaces

- `core.*` - Luanti engine API (alias for `minetest.*`)
- `vector` - Vector math (from Luanti)
- `pcity_mapgen` / `pcmg` - Main mapgen module
- `pcity_nodes` - Node definitions
- `player_api` - Player model/animation API

### Key APIs Used

```lua
-- Vector operations
vector.new(x, y, z)
vector.add(v1, v2)
vector.distance(v1, v2)

-- Core functions
core.get_modpath(modname)
core.register_node(name, definition)
core.register_alias(alias, original)

-- Tests
pcmg.register_test(name, function)
```

## Licensing

- **Code**: AGPL-3.0-or-later (Jan Wielkiewicz)
- **Character model/texture**: CC BY-SA 3.0 (Modified from Minetest Game)
- **Test infrastructure**: Inspired by WorldEdit (AGPL-3.0)

## Troubleshooting

### Tests won't run
- Ensure luantiserver/minetestserver is installed: `which luantiserver`
- Run setup script: `./.github/agents/setup.sh`

### Tests fail
- Check the test output for specific assertion failures
- Review changes to affected classes (Point, Path)
- Ensure Luanti APIs are used correctly

### Server not found
```bash
# Install manually (Ubuntu/Debian - Latest stable from PPA):
sudo add-apt-repository ppa:luanti/luanti
sudo apt-get update
sudo apt-get install luanti-server

# Or for Arch Linux:
sudo pacman -S luanti
```

## Additional Resources

- Test documentation: `mods/pcity_mapgen/tests/TESTING.md`
- Main README: `README.md`
- GitHub Actions: `.github/workflows/test.yml`
