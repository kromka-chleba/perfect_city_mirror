# Canvas IDs Module

## Overview

The canvas_ids module defines material IDs and their properties for the canvas system. Each material has a unique ID, name, and priority value that determines drawing precedence.

## Purpose

This module provides:
- Centralized material ID definitions
- Material priority system for layered drawing
- Bidirectional lookup (by ID or by name)
- Metadata for different node types

## Material System

### Material Structure

Each material has three properties:

```lua
{
    id = number,        -- Unique numeric identifier
    name = string,      -- Human-readable name
    priority = number,  -- Drawing priority (higher = more important)
}
```

### Priority System

When canvas writes a material to a cell:
- If new material priority ≥ current material priority: write succeeds
- If new material priority < current material priority: write is ignored

This allows layering: roads can be drawn first, then centers and margins can overwrite specific areas.

## Defined Materials

### Regular Materials

```lua
[1] = {id = 1, name = "blank", priority = 0}
```
Default/empty material. Lowest priority, can be overwritten by anything.

```lua
[2] = {id = 2, name = "road_asphalt", priority = 3}
```
Main road surface. High priority.

```lua
[3] = {id = 3, name = "road_pavement", priority = 2}
```
Pavement/sidewalk areas. Medium priority.

```lua
[4] = {id = 4, name = "road_margin", priority = 1}
```
Road edges and margins. Low priority, easily overwritten.

```lua
[5] = {id = 5, name = "road_center", priority = 4}
```
Road centerlines and markings. Highest priority among regular materials.

### Meta Materials

Meta materials have very high priorities (1000+) and are used for special purposes:

```lua
[1000] = {id = 1000, name = "road_midpoint", priority = 1000}
```
Marks midpoints of road segments. Used for algorithm purposes, not actual nodes.

```lua
[1001] = {id = 1001, name = "road_origin", priority = 1001}
```
Marks road origin points. Highest priority, never overwritten.

## Lookup Tables

The module returns two lookup tables:

### materials_by_id

Access materials by numeric ID:

```lua
local materials_by_id, _ = dofile(mod_path.."/canvas_ids.lua")
local material = materials_by_id[2]  -- Gets road_asphalt
print(material.name)      -- "road_asphalt"
print(material.priority)  -- 3
```

### materials_by_name

Access material IDs by name:

```lua
local _, materials_by_name = dofile(mod_path.."/canvas_ids.lua")
local road_id = materials_by_name["road_asphalt"]  -- Returns 2

-- Common usage pattern
canvas:draw_rectangle(10, 10, materials_by_name.road_asphalt, false)
```

## Usage Examples

### Drawing with Priorities

```lua
local _, materials_by_name = dofile(mod_path.."/canvas_ids.lua")

-- Draw base road (priority 3)
canvas:draw_rectangle(100, 20, materials_by_name.road_asphalt, false)

-- Draw margins (priority 1) - only writes to blank cells
canvas:draw_rectangle(100, 2, materials_by_name.road_margin, false)

-- Draw center line (priority 4) - overwrites asphalt
canvas:draw_rectangle(100, 2, materials_by_name.road_center, false)
```

### Checking Material Priority

```lua
local materials_by_id, _ = dofile(mod_path.."/canvas_ids.lua")

local cell_material_id = canvas:read_cell(x, z)
local priority = materials_by_id[cell_material_id].priority

if priority < 3 then
    -- Safe to draw road_asphalt here
end
```

### Adding New Materials

To add new materials, extend the `materials_by_id` table:

```lua
-- Add new building placeholder material
[6] = {id = 6, name = "building_foundation", priority = 5}
[7] = {id = 7, name = "building_wall", priority = 6}
```

**Important**: 
- Use IDs 1-999 for regular materials
- Reserve IDs 1000+ for meta/special materials
- Maintain consistent priority ordering

## Priority Guidelines

| Priority Range | Usage |
|---------------|-------|
| 0 | Blank/default |
| 1-4 | Regular terrain features |
| 5-9 | Buildings and structures |
| 10-99 | Special features |
| 100-999 | Reserved for future use |
| 1000+ | Meta/algorithm markers |

## Implementation Pattern

The module uses a simple pattern:

1. Define materials_by_id with all materials
2. Auto-generate materials_by_name by iterating materials_by_id
3. Return both tables

```lua
local materials_by_id = { --[[ definitions ]] }
local materials_by_name = {}

for id, material in pairs(materials_by_id) do
    materials_by_name[material.name] = id
end

return materials_by_id, materials_by_name
```

## Related Modules

- **canvas.lua** - Uses material IDs for cell storage
- **canvas_brushes.lua** - Uses material IDs in shape definitions
- **megacanvas.lua** - Inherits material ID system from canvas
- **roads_layout.lua** - Uses road material IDs extensively

## Best Practices

1. **Use names, not IDs** - Always use `materials_by_name` for readability
2. **Respect priorities** - Design drawing order based on priorities
3. **Document new materials** - Add comments when extending the material list
4. **Test priority interactions** - Verify that layering works as expected
5. **Keep IDs unique** - Never reuse or change existing material IDs
