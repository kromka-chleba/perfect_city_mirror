# GitHub Copilot Instructions for Perfect City

## Project Overview

Perfect City is a game built for Luanti (formerly Minetest) 5.12+ using Lua. The project implements procedural map generation, custom nodes, and game mechanics using the Luanti API.

## Folder Structure

- `/mods/` - Game modules
  - `pcity_mapgen/` - Map generation system (roads, buildings, city layout)
  - `pcity_nodes/` - Game blocks/nodes (walls, streets, furniture, lights)
  - `pcity_environment/` - Sky, lighting, atmosphere
  - `pcity_seba/` - Player character
  - `player_api/` - Player model and animation API
- `/doc/` - Documentation
  - `CODING_STYLE.md` - Complete coding standards
  - `Perfect_City_Design_Guide.md` - Game design philosophy
- `/utils/` - Development tools and test scripts
- `.github/` - GitHub configuration and workflows

## Libraries and Frameworks

- **Luanti 5.12+** - Game engine (required minimum version)
- **Lua** - Programming language
- **Luanti Lua API** - Core game APIs for nodes, mapgen, entities
  - Reference: [Luanti Lua API](https://github.com/luanti-org/luanti/blob/master/doc/lua_api.md)
- **CPML** (Cirno's Perfect Math Library) - Math utilities in `mods/pcity_cpml/`

## Coding Standards

### Documentation Format
- Use **LuaDoc/LDoc format** for function documentation
- Triple-dash `---` for brief description, double-dash `--` for details
- Use `@param name type description` for parameters
- Use `@return type description` for return values

### Naming Conventions
- Use `snake_case` for variables and functions
- Use `UPPER_SNAKE_CASE` for constants
- Prefix private fields/methods with `_` (e.g., `_internal_state`)
- Use colon syntax (`:`) for object methods

### File Structure (Required Order)
1. AGPL-3.0-or-later license header
2. Module documentation
3. Dependencies and imports
4. Constants
5. Local helper functions
6. Public API functions
7. Return statement

### Function Design
- Keep functions under 30 lines
- One function = one responsibility
- Use early returns to reduce nesting
- Validate inputs at function start
- Provide clear error messages with context

### Code Formatting
- Use 4 spaces for indentation (no tabs)
- Limit lines to 80-100 characters
- Add blank lines between logical sections

### Vector Operations
- **Always prefer operators over verbose methods** for Luanti vectors
- Use `v1 + v2` instead of `vector.add(v1, v2)`
- Use `v1 - v2` instead of `vector.subtract(v1, v2)`
- Use `v * scalar` instead of `vector.multiply(v, scalar)`
- Use `v / scalar` instead of `vector.divide(v, scalar)`
- Use `-v` instead of negation methods
- Use `v1 == v2` instead of verbose equality checks
- Note: Continue using function form for operations without operator equivalents (e.g., `vector.length()`, `vector.dot()`, `vector.normalize()`)

### Testing
- Test infrastructure uses Luanti engine (not standard Lua)
- Tests run with `.util/run_tests.sh` from repository root
- See `mods/pcity_mapgen/tests/` for examples

## Reference
See `doc/CODING_STYLE.md` for complete coding guidelines.
See `mods/pcity_mapgen/` for reference implementations of clean code patterns.
