# Testing Documentation for Perfect City

This document describes how to run unit tests for the `pcity_mapgen` module using the busted testing framework.

## Overview

The unit tests for Perfect City have been migrated to use [busted](https://lunarmodules.github.io/busted/), a popular Lua testing framework. The tests can now run standalone without requiring Minetest/Luanti to be installed.

**Important:** The tests use LuaJIT (not standard Lua) because Luanti/Minetest uses LuaJIT as its runtime. LuaJIT is a Just-In-Time compiler for Lua 5.1 that provides better performance.

## Test Structure

The tests are organized as follows:

```
mods/pcity_mapgen/tests/
├── install_test_deps.sh  # Script to install testing dependencies and clone Luanti
├── run_tests.sh          # Script to run all tests
├── test_helper.lua       # Test bootstrap and module loading
├── luanti/               # Cloned Luanti repository (gitignored)
│   └── builtin/common/   # Luanti's built-in Lua modules (vector, math, etc.)
├── point_spec.lua        # Point class unit tests
└── path_spec.lua         # Path class unit tests
```

### Key Components

- **luanti/**: Cloned from https://github.com/luanti-org/luanti (version 5.10.0) - provides the actual Luanti/Minetest built-in Lua implementations
- **test_helper.lua**: Bootstrap file that loads Luanti's built-in modules (vector.lua, math.lua) and sets up the test environment
- **point_spec.lua**: Tests for the Point class (25 test cases)
- **path_spec.lua**: Tests for the Path class (38 test cases)

**Important**: Tests use the *actual* Luanti built-in modules (version 5.10.0), not mocks. This ensures perfect compatibility and catches any real incompatibilities with Luanti/Minetest.

**Why version 5.10.0?** The tests are pinned to Luanti 5.10.0 to ensure reproducible test results across different environments and time periods. This version is known to be stable and compatible with the current codebase.

## Installation

### Prerequisites

You need to install:
- LuaJIT (JIT compiler for Lua 5.1 - same runtime used by Luanti/Minetest)
- LuaRocks (Lua package manager)
- busted (testing framework)

**Note:** While standard Lua 5.1 may work for tests, LuaJIT is recommended as it matches the actual runtime environment of Luanti/Minetest.

### Automated Installation

Run the installation script which will automatically install all dependencies:

```bash
cd mods/pcity_mapgen/tests
./install_test_deps.sh
```

This script works on:
- Ubuntu/Debian (uses apt-get)
- macOS (uses Homebrew)
- Fedora/RHEL (uses dnf)

### Manual Installation

If you prefer to install manually or are on a different system:

#### 1. Install LuaJIT

**Ubuntu/Debian:**
```bash
sudo apt-get install luajit libluajit-5.1-dev
```

**macOS:**
```bash
brew install luajit
```

**Fedora/RHEL:**
```bash
sudo dnf install luajit luajit-devel
```

**Other systems:**
Download from https://luajit.org/download.html

**Why LuaJIT?** Luanti/Minetest uses LuaJIT for better performance. LuaJIT is backwards compatible with Lua 5.1 but includes JIT compilation and some extensions.

#### 2. Install LuaRocks

**Ubuntu/Debian:**
```bash
sudo apt-get install luarocks
```

**macOS:**
```bash
brew install luarocks
```

**Fedora/RHEL:**
```bash
sudo dnf install luarocks
```

**Other systems:**
Download from https://luarocks.org/

#### 3. Install busted

```bash
# Global installation (requires sudo/admin)
luarocks install busted

# Or local installation (no sudo required)
luarocks install --local busted
```

**Note:** If you have both Lua 5.1 and LuaJIT installed, make sure LuaRocks is configured to use LuaJIT:
```bash
luarocks config lua_interpreter luajit
```

If you install locally, add these to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH=$HOME/.luarocks/bin:$PATH
export LUA_PATH="$HOME/.luarocks/share/lua/5.1/?.lua;$HOME/.luarocks/share/lua/5.1/?/init.lua;;$LUA_PATH"
export LUA_CPATH="$HOME/.luarocks/lib/lua/5.1/?.so;;$LUA_CPATH"
```

Then reload your shell:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Running Tests

### Using the Test Runner Script

The easiest way to run tests:

```bash
cd mods/pcity_mapgen/tests
./run_tests.sh
```

This will run all tests and display the results.

### Running Specific Tests

You can run specific test files:

```bash
cd mods/pcity_mapgen/tests
busted point_spec.lua
```

Or use patterns:

```bash
cd mods/pcity_mapgen/tests
busted --pattern=point_spec.lua
```

### Verbose Output

For more detailed output:

```bash
cd mods/pcity_mapgen/tests
busted --verbose
```

### Test Coverage

To see test coverage (requires luacov):

```bash
luarocks install luacov
cd mods/pcity_mapgen/tests
busted --coverage
luacov
cat luacov.report.out
```

## GitHub Actions / CI Integration

To run tests in CI/CD pipelines:

### GitHub Actions Example

Create `.github/workflows/test.yml`:

```yaml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y luajit libluajit-5.1-dev luarocks
        sudo luarocks install busted
    
    - name: Run tests
      run: |
        cd mods/pcity_mapgen/tests
        ./run_tests.sh
```

### Alternative: Using install script

```yaml
    - name: Install dependencies
      run: |
        cd mods/pcity_mapgen/tests
        sudo ./install_test_deps.sh
    
    - name: Run tests
      run: |
        cd mods/pcity_mapgen/tests
        ./run_tests.sh
```

## Writing New Tests

When adding new tests, follow the busted format:

```lua
local helper = require("test_helper")
local point = helper.point
local path = helper.path
local vector = helper.vector

describe("Feature name", function()
    describe("function_name", function()
        it("should do something specific", function()
            -- Arrange
            local p = point.new(vector.new(1, 2, 3))
            
            -- Act
            local result = p:some_method()
            
            -- Assert
            assert.are.equal(expected, result)
        end)
    end)
end)
```

### Common Assertions

- `assert.are.equal(expected, actual)` - Values are equal
- `assert.are_not.equal(expected, actual)` - Values are not equal
- `assert.is_true(value)` - Value is true
- `assert.is_false(value)` - Value is false
- `assert.is_nil(value)` - Value is nil
- `assert.is_not_nil(value)` - Value is not nil
- `assert.has_error(function)` - Function throws an error
- `assert.is_table(value)` - Value is a table

For more assertions, see: https://lunarmodules.github.io/busted/#asserts

## Troubleshooting

### "busted: command not found"

Make sure busted is installed and in your PATH. If you installed locally with `--local`, ensure the PATH environment variable is set correctly.

### "module 'test_helper' not found"

Make sure you're running busted from the `tests/` directory:

```bash
cd mods/pcity_mapgen/tests
busted
```

### Luanti repository not found

If you get an error about Luanti not being found, run the installation script:

```bash
cd mods/pcity_mapgen/tests
./install_test_deps.sh
```

This will clone the Luanti repository to get the built-in Lua modules.

### Tests fail with "attempt to index global 'core'"

This means test_helper.lua couldn't load properly. Verify that:
1. `test_helper.lua` exists
2. `luanti/builtin/common/vector.lua` exists (run `./install_test_deps.sh` if not)
3. You're running from the correct directory

### Permission denied when running scripts

Make the scripts executable:

```bash
chmod +x install_test_deps.sh run_tests.sh
```

### Using LuaJIT vs Lua 5.1

If you have both installed and want to ensure you're using LuaJIT:

```bash
# Check which Lua interpreter is being used
lua -v        # Standard Lua
luajit -v     # LuaJIT

# Configure LuaRocks to use LuaJIT
luarocks config lua_interpreter luajit
```

LuaJIT is preferred because it matches Luanti/Minetest's runtime environment.

## Comparison with Old Test System

### Old System (Minetest-dependent)

```lua
function tests.test_point_new()
    local pos = vector.new(5, 10, 15)
    local p = point.new(pos)
    assert(p.pos.x == 5, "Point x coordinate should be 5")
end

tests.run_all()
```

- Required Minetest to run
- Used plain assert() with messages
- Tests ran automatically when mod loaded
- Tests in global namespace

### New System (Standalone with busted + real Luanti code)

```lua
describe("point.new", function()
    it("creates a point with correct position", function()
        local pos = vector.new(5, 10, 15)
        local p = point.new(pos)
        assert.are.equal(5, p.pos.x)
    end)
end)
```

- Runs standalone without Minetest
- Uses the **actual** Luanti built-in modules (vector.lua, math.lua)
- Uses expressive busted assertions
- Tests run via command line tools
- Better test organization with describe/it blocks
- Works with CI/CD systems
- Ensures perfect compatibility with real Luanti code

## Resources

- [busted documentation](https://lunarmodules.github.io/busted/)
- [LuaJIT website](https://luajit.org/)
- [Lua 5.1 reference manual](https://www.lua.org/manual/5.1/)
- [LuaRocks package manager](https://luarocks.org/)
- [Luanti/Minetest Lua API](https://github.com/minetest/minetest/blob/master/doc/lua_api.md)
