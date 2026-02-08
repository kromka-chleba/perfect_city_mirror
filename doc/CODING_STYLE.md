# Perfect City - Coding Style Guidelines

This document describes the coding style used throughout the Perfect City game project. The guidelines are based on the `pcity_mapgen` module, which serves as the reference implementation for clean, maintainable code.

## Table of Contents

1. [General Principles](#general-principles)
2. [File Organization](#file-organization)
3. [Naming Conventions](#naming-conventions)
4. [Function Design](#function-design)
5. [Comments and Documentation](#comments-and-documentation)
6. [Code Structure](#code-structure)
7. [Error Handling](#error-handling)
8. [Module Organization](#module-organization)

---

## General Principles

### Clean Code Philosophy

Follow these clean code principles throughout the codebase:

1. **Single Responsibility**: Each function should do one thing and do it well
2. **Small Functions**: Keep functions focused and concise (typically under 30 lines)
3. **Clear Intent**: Code should be self-documenting through good naming
4. **DRY (Don't Repeat Yourself)**: Extract common patterns into reusable functions
5. **Separation of Concerns**: Separate validation, logic, and data manipulation

### Code Quality Goals

- **Readability**: Code should be easy to read and understand
- **Maintainability**: Changes should be localized and predictable
- **Testability**: Functions should be easy to test in isolation
- **Performance**: Optimize only when necessary; clarity first

---

## File Organization

### File Header

Every Lua file must start with the AGPL-3.0-or-later license header:

```lua
--[[
    This is a part of "Perfect City".
    Copyright (C) 2024-2025 Author Name <email@example.com>
    SPDX-License-Identifier: AGPL-3.0-or-later

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]
```

### File Structure

Files should follow this structure:

1. License header
2. Module documentation (if applicable)
3. Dependencies and imports
4. Constants and configuration
5. Local helper functions
6. Public API functions
7. Return statement (for modules)

Example:

```lua
--[[ License header ]]

-- Module documentation in block comments

-- Dependencies
local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local math = math
local vector = vector

-- Constants
local CONSTANT_NAME = 42

-- Module table
pcity_mapgen.my_module = {}
local my_module = pcity_mapgen.my_module

-- Helper functions
local function helper_function()
    -- ...
end

-- Public functions
function my_module.public_function()
    -- ...
end

return my_module
```

---

## Naming Conventions

### Variables and Functions

- **Local variables**: Use `snake_case`
  ```lua
  local map_size = 100
  local player_position = vector.new(0, 0, 0)
  ```

- **Global tables/modules**: Use `snake_case` with module prefix
  ```lua
  pcity_mapgen = {}
  pcity_nodes = {}
  ```

- **Functions**: Use `snake_case` with descriptive names
  ```lua
  function point.new(pos)
  function canvas:set_cursor(pos)
  function pcmg.citychunk_origin(pos)
  ```

- **Methods**: Use colon syntax (`:`) for object methods
  ```lua
  function point:copy()
  function canvas:draw_circle(radius, material_id)
  ```

- **Constants**: Use `UPPER_SNAKE_CASE` for true constants
  ```lua
  local CANVAS_MARGIN = 16
  local MAX_PATH_LENGTH = 1000
  ```

### Module Abbreviations

Use short, memorable abbreviations for frequently-used modules:

```lua
local pcmg = pcity_mapgen
local pth = path
local pt = point
```

---

## Function Design

### Keep Functions Small

Functions should typically be **under 30 lines**. If a function grows larger, consider breaking it into smaller helper functions.

**Good:**
```lua
function point.new(pos)
    checks.check_point_new_arguments(pos)
    local p = {}
    point_id_counter = point_id_counter + 1
    p.id = point_id_counter
    p.pos = vector.copy(pos)
    p.path = nil
    p.previous = nil
    p.next = nil
    p.attached = setmetatable({}, {__mode = "kv"})
    p.branches = setmetatable({}, {__mode = "kv"})
    return setmetatable(p, point)
end
```

**Bad:**
```lua
-- A 100-line function that does validation, creation, linking, and rendering
```

### Single Responsibility Principle

Each function should do one thing and do it well.

**Good:**
```lua
-- Unlinks the current point from the previous point.
function point:unlink_from_previous()
    if self.previous and self.previous.next == self then
        self.previous.next = nil
    end
    self.previous = nil
end

-- Unlinks the current point from the next point.
function point:unlink_from_next()
    if self.next and self.next.previous == self then
        self.next.previous = nil
    end
    self.next = nil
end

-- Unlinks the point from both the previous and the next point.
function point:unlink()
    self:unlink_from_previous()
    self:unlink_from_next()
end
```

**Bad:**
```lua
-- A single function that handles unlinking, reattaching, validation, and cleanup
```

### Clear Function Names

Function names should clearly indicate what they do. Use verbs for actions.

**Good:**
```lua
function canvas:set_cursor(pos)
function point:copy()
function path:has_intermediate()
function vector.comparator(v1, v2)
```

**Bad:**
```lua
function canvas:sc(p)  -- Unclear abbreviation
function point:do_stuff()  -- Vague name
function path:process()  -- What kind of processing?
```

### Function Parameters

- Keep parameter lists short (preferably 3 or fewer)
- Use descriptive parameter names
- Document expected types in comments if not obvious

```lua
-- Creates a new canvas object for the citychunk
-- specified by 'citychunk_origin'
-- (see pcmg.mapchunk_origin in utils.lua)
function canvas.new(citychunk_origin)
    -- ...
end
```

### Return Values

- Return early to reduce nesting
- Be consistent with return types

**Good:**
```lua
function point.check(p)
    return getmetatable(p) == point
end

function canvas:read_cell(x, z)
    local new_x, new_z = x + 1 + canvas_margin, z + 1 + canvas_margin
    if self.array[new_x] then
        return self.array[new_x][new_z] or blank_id
    end
    return blank_id
end
```

---

## Comments and Documentation

### When to Comment

- **Always**: Function documentation describing purpose and parameters
- **Always**: License headers at the top of files
- **Often**: Complex algorithms or non-obvious code
- **Sometimes**: Intent behind specific implementation choices
- **Rarely**: What the code does (the code should be self-explanatory)

### Function Documentation

Document functions with clear, concise comments describing:
- What the function does
- Parameters and their types
- Return values
- Any important side effects or caveats

```lua
-- Creates a new instance of the Point class. Points store absolute
-- world position, the previous and the next point in a sequence and
-- the path (see the Path class below) they belong to. Points can be
-- linked to create linked lists which should be helpful for
-- road/street generation algorithms.
function point.new(pos)
    -- ...
end
```

### Section Headers

Use section headers to organize related functions:

```lua
-- ============================================================
-- COMPARATORS
-- ============================================================

-- Comparator for vectors. Compares by x, y, z in order.
-- Returns false for equal vectors (strict weak ordering).
function vector.comparator(v1, v2)
    -- ...
end
```

### Inline Comments

Keep inline comments brief and focus on *why*, not *what*:

```lua
-- Counter for generating unique point IDs. Ensures deterministic
-- ordering for points at the same position, as long as points are
-- created in the same order across environments.
local point_id_counter = 0
```

### Block Comments for Complex Concepts

Use block comments to explain complex data structures or algorithms:

```lua
--[[
    ** Overview **
    Canvas is a data type for storing and processing 2D citychunk (node) data.
    Canvas is meant to be a blueprint that provides a layer of abstraction between
    map planning and actual mapgen. The main use case is generating complex map
    layouts, for example a layout of a city.
    
    canvas.array[x][z] is a 2D array that stores material IDs that correspond
    to nodes, node groups or more abstract concepts (like building placeholders).
--]]
```

---

## Code Structure

### Indentation and Spacing

- Use **4 spaces** for indentation (no tabs)
- Add blank lines between logical sections
- Limit line length to **80-100 characters** when reasonable

```lua
function canvas:draw_rectangle(x_side, z_side, material_id, centered)
    assert(x_side >= 1, "Canvas rectangle X side is smaller than 1: "..x_side)
    assert(z_side >= 1, "Canvas rectangle Z side is smaller than 1: "..z_side)
    if not self.cursor_inside then
        return
    end
    local shape =
        canvas_shapes.make_rectangle(x_side, z_side, material_id, centered)
    self:draw_shape(shape)
end
```

### Local Variables

- Declare local variables at the top of their scope
- Group related variable declarations
- Initialize variables when declared when possible

```lua
local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local math = math
local vector = vector
local pcmg = pcity_mapgen
```

### Control Flow

- Use early returns to reduce nesting
- Avoid deep nesting (max 3-4 levels)
- Use guard clauses at the beginning of functions

**Good:**
```lua
function canvas:draw_shape(shape)
    if not self.cursor_inside then
        return
    end
    local cursor_pos = vector.round(self.cursor)
    for _, cell in pairs(shape) do
        local point = cell.pos + cursor_pos
        self:read_write_cell(point.x, point.z, cell.material)
    end
end
```

**Bad:**
```lua
function canvas:draw_shape(shape)
    if self.cursor_inside then
        local cursor_pos = vector.round(self.cursor)
        for _, cell in pairs(shape) do
            local point = cell.pos + cursor_pos
            self:read_write_cell(point.x, point.z, cell.material)
        end
    end
end
```

### Iterators and Loops

Use appropriate loop constructs:

```lua
-- For sequential tables with indices
for i = 1, #points do
    points[i].next = points[i + 1]
end

-- For tables with arbitrary keys
for key, value in pairs(table) do
    -- ...
end

-- Custom iterators for linked structures
for i, p in my_point:iterator() do
    -- ...
end
```

---

## Error Handling

### Validation

- Validate inputs at the beginning of functions
- Use dedicated validation functions for complex checks
- Provide clear error messages

```lua
function checks.check_point_new_arguments(pos)
    if not vector.check(pos) then
        error("Path: pos '"..shallow_dump(pos).."' is not a vector.")
    end
end

function point.new(pos)
    checks.check_point_new_arguments(pos)
    -- ... rest of function
end
```

### Assertions

Use assertions for internal consistency checks:

```lua
assert(x_side >= 1, "Canvas rectangle X side is smaller than 1: "..x_side)
assert(radius >= 1, "Canvas circle radius is smaller than 1: "..radius)
```

### Error Messages

- Include context in error messages
- Use descriptive error messages
- Include variable values when helpful

```lua
if not vector.check(pos) then
    error("Canvas: pos '"..shallow_dump(pos).."' is not a vector.")
end

if not path.check(pth) then
    error("Path: pth '"..shallow_dump(pth).."' is not a path.")
end
```

---

## Module Organization

### Module Pattern

Use this pattern for creating modules:

```lua
-- Create or get existing module table
pcmg.my_module = pcmg.my_module or {}
local my_module = pcmg.my_module

-- Set up metatable for object-oriented modules
my_module.__index = my_module

-- Module functions
function my_module.new()
    local obj = {}
    return setmetatable(obj, my_module)
end

function my_module.check(obj)
    return getmetatable(obj) == my_module
end

-- Return the module
return pcmg.my_module
```

### Dependencies

- Load dependencies at the top of the file
- Use conditional loading for optional dependencies
- Cache frequently-used globals

```lua
local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local math = math
local vector = vector
local pcmg = pcity_mapgen

local point = pcmg.point or dofile(mod_path.."/point.lua")
local path = pcmg.path or dofile(mod_path.."/path.lua")
```

### Weak Tables

Use weak tables for caching and avoiding memory leaks:

```lua
-- Weak table: points are kept alive by the linked list,
-- not by this table.
pth.points = setmetatable({}, {__mode = "kv"})

-- Weak table: attached points are kept alive by their own paths,
-- not by the attachment relationship itself.
p.attached = setmetatable({}, {__mode = "kv"})
```

### File Separation

Organize code into focused files:

- **One class per file**: `point.lua`, `path.lua`, `canvas.lua`
- **Utilities**: `utils.lua`, `debug_helpers.lua`
- **Constants**: `sizes.lua`, `canvas_ids.lua`
- **Validation**: `point_checks.lua`
- **Tests**: `tests/tests_point.lua`, `tests/tests_path.lua`

---

## Testing

### Test Organization

- Keep tests in a dedicated `tests/` directory
- One test file per module: `tests_point.lua`, `tests_path.lua`
- Use descriptive test function names

```lua
function tests.test_point_new()
    -- Test implementation
end

function tests.test_point_check()
    -- Test implementation
end
```

### Test Structure

Follow the Arrange-Act-Assert pattern:

```lua
function tests.test_point_copy()
    -- Arrange
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(30, 40, 50))
    local pth = path.new(p1, p2)
    local p_mid = point.new(vector.new(15, 25, 35))
    pth:insert(p_mid)
    
    -- Act
    local p_copy = p_mid:copy()
    
    -- Assert
    assert(vector.equals(p_copy.pos, p_mid.pos), "Copy should have same position")
    assert(p_copy.id ~= p_mid.id, "Copy should have different ID")
    assert(p_copy.path == nil, "Copy should not belong to any path")
end
```

---

## Examples

### Good Code Example

From `point.lua`:

```lua
-- Creates a copy of point 'p' with the same position. The copy does
-- not inherit path, previous/next links, attachments, or branches -
-- it is a fresh, unlinked point. Use this when you need a new point
-- at the same location (e.g., when splitting a path).
function point:copy()
    return point.new(self.pos)
end

-- Unlinks the current point from the previous point.
function point:unlink_from_previous()
    if self.previous and self.previous.next == self then
        self.previous.next = nil
    end
    self.previous = nil
end

-- Unlinks the current point from the next point.
function point:unlink_from_next()
    if self.next and self.next.previous == self then
        self.next.previous = nil
    end
    self.next = nil
end

-- Unlinks the point from both the previous and the next point.
function point:unlink()
    self:unlink_from_previous()
    self:unlink_from_next()
end
```

**Why this is good:**
- Each function does one thing
- Clear, descriptive names
- Well-documented
- Functions are small and focused
- Reuse: `unlink()` composes two smaller functions

### Code to Improve

**Before:**
```lua
function do_everything(x, y, z, flag1, flag2, flag3)
    if flag1 then
        -- 50 lines of code
        if flag2 then
            -- 30 more lines
            if flag3 then
                -- 20 more lines
            end
        end
    end
    -- ... continues for 200 lines
end
```

**After:**
```lua
function validate_inputs(x, y, z)
    checks.check_coordinates(x, y, z)
end

function process_step_one(x, y)
    -- 10-15 lines focused on step one
end

function process_step_two(y, z)
    -- 10-15 lines focused on step two
end

function process_step_three(x, z)
    -- 10-15 lines focused on step three
end

function do_processing(x, y, z, options)
    validate_inputs(x, y, z)
    
    if options.step_one then
        process_step_one(x, y)
    end
    
    if options.step_two then
        process_step_two(y, z)
    end
    
    if options.step_three then
        process_step_three(x, z)
    end
end
```

---

## Summary

The key principles for Perfect City code:

1. **Functions should be small** (under 30 lines typically)
2. **Each function does one thing well** (Single Responsibility)
3. **Use clear, descriptive names** for variables and functions
4. **Document public APIs** with clear comments
5. **Validate inputs** at function boundaries
6. **Organize code into focused modules** (one class per file)
7. **Write testable code** with clear inputs and outputs
8. **Keep it simple** - clarity over cleverness

When in doubt, refer to the `pcity_mapgen` module for examples of good coding practices.

---

## Reference Files

For concrete examples of these principles in practice, study these files:

- `mods/pcity_mapgen/point.lua` - Object-oriented design, small methods
- `mods/pcity_mapgen/path.lua` - Complex data structures, clear API
- `mods/pcity_mapgen/canvas.lua` - Well-documented public interface
- `mods/pcity_mapgen/utils.lua` - Utility functions organization
- `mods/pcity_mapgen/point_checks.lua` - Validation patterns
- `mods/pcity_mapgen/tests/tests_point.lua` - Testing patterns
