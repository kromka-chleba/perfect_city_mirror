# Testing Documentation for Perfect City

This document describes how to run unit tests for the `pcity_mapgen` module.

## Overview

The unit tests for Perfect City run **inside the Luanti/Minetest engine**, following the pattern established by the [WorldEdit mod](https://github.com/Uberi/Minetest-WorldEdit). This approach was recommended by Luanti developers as the proper way to test mods.

**Important:** Tests must run inside the engine to have access to all Luanti APIs and ensure proper integration.

## Attribution and License

This test infrastructure is inspired by WorldEdit's test system:
- **WorldEdit**: https://github.com/Uberi/Minetest-WorldEdit
- **License**: GNU Affero General Public License v3 (AGPLv3)
- **Copyright**: © 2012 sfan5, Anthony Zhang (Uberi/Temperest), and Brett O'Donnell (cornernote)

We adapted the following concepts from WorldEdit:
- Running tests inside the Luanti engine (from `worldedit/test/init.lua`)
- Test registration and execution pattern
- Shell script test runner approach (from `.util/run_tests.sh`)
- Temporary world creation with singlenode mapgen
- Test success marker file pattern

Our implementation is licensed under GNU General Public License v3+ (GPLv3+), which is compatible with AGPLv3 code inspiration.

## Test Structure

```
.util/
└── run_tests.sh       # Shell script to automate test execution (run from repo root)

mods/pcity_mapgen/tests/
├── init.lua           # Test runner - loads and executes tests
├── tests_point.lua    # Point class unit tests (25 tests)
├── tests_path.lua     # Path class unit tests (38 tests)
└── TESTING.md         # This documentation
```

### How It Works

1. `.util/run_tests.sh` creates a temporary world with `singlenode` mapgen
2. Starts `minetest` or `luanti` with `--server` flag and `pcity_run_tests=true` setting
3. `tests/init.lua` loads test files and runs all registered tests
4. Tests execute using real Luanti APIs (vector, minetest functions)
5. Results are printed to console
6. If all tests pass, creates `tests_ok` file and shuts down server
7. Script checks for `tests_ok` file and reports success/failure

## Prerequisites

You need:
- **Luanti 5.12 or newer** - Required for features used by Perfect City
- **Luanti/Minetest** binary (`minetest`, `luanti`, or `minetestserver`) installed and in PATH
- That's it! No external dependencies required.

**Important:** Perfect City requires Luanti 5.12+. Older versions will not work.

## Installation

### Installing Luanti/Minetest

**Ubuntu/Debian (Recommended - Latest Stable from PPA):**
```bash
# Add the official Minetest PPA for the latest stable release
sudo add-apt-repository ppa:minetestdevs/stable
sudo apt-get update
sudo apt-get install minetest
```

**Important:** The default Ubuntu repositories may contain older versions of Minetest (< 5.12) that are incompatible with Perfect City. Always use the PPA to get version 5.12 or newer.

**Arch Linux:**
```bash
sudo pacman -S minetest
```

**From source:**
```bash
git clone https://github.com/minetest/minetest.git
cd minetest
cmake . -DBUILD_SERVER=TRUE
make -j$(nproc)
sudo make install
```

**Check installation:**
```bash
minetest --version
# or
luanti --version
```

**Verify you have version 5.12 or newer:**
After installation, make sure the output shows version 5.12.0 or higher. If you see an older version, you'll need to use the PPA or compile from source.

## Running Tests

### Using the Test Runner Script

**The test runner must be run from the repository root:**

```bash
cd /path/to/perfect_city_mirror
./.util/run_tests.sh
```

This will:
- Verify you're in the repository root (checks for mod.conf)
- Find minetest or luanti binary
- Create a temporary test world
- Start the server with tests enabled
- Run all tests
- Print results
- Exit with code 0 if tests pass, 1 if they fail

### Example Output

```
Using binary: /usr/bin/minetest
Starting test run...
Running 63 tests for pcity_mapgen on Luanti 5.15.0
---- Point class ----------------------------------------------------
point.new                                                    pass
point.check                                                  pass
point:copy                                                   pass
...
---- Path class -----------------------------------------------------
path.new                                                     pass
path.check                                                   pass
...

Results: 63 passed, 0 failed, 63 total
✓ All tests passed!
```

### Manual Testing

You can also run tests manually:

1. Create a world with singlenode mapgen
2. Add to `minetest.conf`:
   ```
   pcity_run_tests = true
   ```
3. Symlink or copy the mod to the world's `worldmods/` directory
4. Start the server:
   ```bash
   minetest --server --world /path/to/world --logfile /dev/null
   ```
5. Watch the console for test results

## Writing Tests

Tests are simple Lua functions that use `assert()` to verify behavior:

```lua
function tests.test_something()
    local p = point.new(vector.new(1, 2, 3))
    assert(p.pos.x == 1, "X coordinate should be 1")
    assert(p.id ~= nil, "Point should have an ID")
end
```

Then register the test:

```lua
local register_test = pcmg.register_test

register_test("Something")  -- Section header (no function)
register_test("test_something", tests.test_something)
```

### Test Guidelines

- Tests should be self-contained and not depend on execution order
- Use descriptive assertion messages
- Test one thing per function
- Group related tests under section headers
- Use Luanti's built-in APIs (vector, minetest functions)

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
      with:
        submodules: recursive
    
    - name: Install Minetest
      run: |
        sudo apt-get update
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository -y ppa:minetestdevs/stable
        sudo apt-get update
        sudo apt-get install -y minetest
    
    - name: Run tests
      run: ./.util/run_tests.sh
```

## Troubleshooting

### "Must be run from repository root"

Make sure you're running `.util/run_tests.sh` from the repository root:
```bash
cd /path/to/perfect_city_mirror
./.util/run_tests.sh
```

### "minetest or luanti binary not found"

Make sure Minetest/Luanti is installed and in your PATH:
```bash
which minetest
# or
which luanti
```

### Tests hang or don't complete

Check that:
1. The mod loads correctly (no Lua syntax errors)
2. `pcity_run_tests` setting is set to `true`
3. The temporary world directory has proper permissions

## Resources

- [WorldEdit test example](https://github.com/Uberi/Minetest-WorldEdit/blob/master/worldedit/test/init.lua)
- [Luanti/Minetest Lua API](https://github.com/minetest/minetest/blob/master/doc/lua_api.md)
- [Luanti website](https://www.luanti.org/)
