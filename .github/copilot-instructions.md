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

## Planning
For complex changes tell me your plan first, for simple changes you may proceed without showing your plan.

## Reference
See `doc/CODING_STYLE.md` for complete guidelines and `mods/pcity_mapgen/` for reference implementations.
