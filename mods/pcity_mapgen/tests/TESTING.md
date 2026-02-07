# Testing Documentation for Perfect City

This document describes how to run unit tests for the `pcity_mapgen` module using the busted testing framework.

## Overview

The unit tests for Perfect City have been migrated to use [busted](https://lunarmodules.github.io/busted/), a popular Lua testing framework. The tests can now run standalone without requiring Minetest/Luanti to be installed.

## Test Structure

The tests are organized as follows:

```
mods/pcity_mapgen/tests/
├── install_test_deps.sh  # Script to install testing dependencies
├── run_tests.sh          # Script to run all tests
├── test_helper.lua       # Test bootstrap and module loading
├── mocks/
│   └── minetest_mocks.lua  # Mock implementations of Minetest API
├── point_spec.lua        # Point class unit tests
└── path_spec.lua         # Path class unit tests
```

### Key Components

- **minetest_mocks.lua**: Provides mock implementations of Minetest/Luanti APIs (core, vector) so tests can run without Minetest
- **test_helper.lua**: Bootstrap file that sets up the test environment and loads the modules under test
- **point_spec.lua**: Tests for the Point class (26 test cases)
- **path_spec.lua**: Tests for the Path class (38 test cases)

## Installation

### Prerequisites

You need to install:
- Lua 5.1 (or LuaJIT)
- LuaRocks (Lua package manager)
- busted (testing framework)

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

#### 1. Install Lua 5.1

**Ubuntu/Debian:**
```bash
sudo apt-get install lua5.1 liblua5.1-0-dev
```

**macOS:**
```bash
brew install lua@5.1
```

**Fedora/RHEL:**
```bash
sudo dnf install lua
```

**Other systems:**
Download from https://www.lua.org/download.html

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
        sudo apt-get install -y lua5.1 liblua5.1-0-dev luarocks
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

### Tests fail with "attempt to index global 'core'"

This means the mocks aren't being loaded correctly. Verify that:
1. `test_helper.lua` exists
2. `mocks/minetest_mocks.lua` exists
3. You're running from the correct directory

### Permission denied when running scripts

Make the scripts executable:

```bash
chmod +x install_test_deps.sh run_tests.sh
```

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

### New System (Standalone with busted)

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
- Uses expressive busted assertions
- Tests run via command line tools
- Better test organization with describe/it blocks
- Works with CI/CD systems

## Resources

- [busted documentation](https://lunarmodules.github.io/busted/)
- [Lua 5.1 reference manual](https://www.lua.org/manual/5.1/)
- [LuaRocks package manager](https://luarocks.org/)
