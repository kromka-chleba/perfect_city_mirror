# GitHub Copilot Instructions for Perfect City

## Project Type
Minetest/Luanti game written in Lua (AGPL-3.0-or-later license)

## Key Principles
1. **Functions should be small** (under 30 lines)
2. **Single Responsibility** - each function does one thing well
3. **Clear, descriptive names** (snake_case for variables/functions)
4. **Document public APIs** with comments
5. **Validate inputs** at function boundaries
6. **Keep it simple** - clarity over cleverness

## Code Style

### Naming
- Variables/functions: `snake_case`
- Constants: `UPPER_SNAKE_CASE`
- Private fields/methods: `_prefix` (internal use only)
- Methods: use colon syntax (`:`) for object methods

### File Structure
1. AGPL-3.0-or-later license header
2. Module documentation
3. Dependencies and imports
4. Constants
5. Local helper functions
6. Public API functions
7. Return statement

### Functions
- Keep under 30 lines
- Use early returns to reduce nesting
- Validate inputs at the beginning
- Clear error messages with context

### Indentation
- 4 spaces (no tabs)
- Limit lines to 80-100 characters when reasonable
- Blank lines between logical sections

### Error Handling
- Validate inputs with dedicated functions
- Use assertions for internal checks
- Include context in error messages

### Module Pattern
```lua
pcmg.my_module = pcmg.my_module or {}
local my_module = pcmg.my_module
my_module.__index = my_module

function my_module.new()
    local obj = {}
    return setmetatable(obj, my_module)
end

return pcmg.my_module
```

## License Header Template
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

## Reference
See `doc/CODING_STYLE.md` for complete guidelines and `mods/pcity_mapgen/` for reference implementations.
