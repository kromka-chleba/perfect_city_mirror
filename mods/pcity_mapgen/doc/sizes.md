# Sizes Module

## Overview

The sizes module defines the size constants and unit conversion functions for Perfect City's coordinate system hierarchy: nodes, mapchunks, and citychunks.

## Purpose

This module provides:
- Size definitions for all map division units
- Conversion functions between coordinate systems
- Height level constants for city layers
- Configuration-dependent size calculations

## Map Division Hierarchy

```
Node (1x1x1)
  ↓ (grouped by mapchunk_size, default 80)
Mapchunk (80x80x80 nodes, default)
  ↓ (grouped by citychunk_size, default 10)
Citychunk (800x800x800 nodes, default)
```

## Configuration

The module reads these settings:

- `chunksize` - Minetest mapgen setting (default: 5 blocks)
  - Determines mapchunk size: `5 * 16 = 80 nodes`
- `pcity_citychunk_size` - Perfect City setting (default: 10 mapchunks)
  - Determines citychunk size: `10 * 80 = 800 nodes`
- `mgflat_ground_level` - Ground level Y coordinate (default: 8)

## Unit Conversion Functions

### sizes.units

The `units` table contains all conversion functions:

#### Node ↔ Mapchunk

```lua
units.node_to_mapchunk(pos)
```
Converts node position to mapchunk coordinates.

```lua
units.mapchunk_to_node(mapchunk_pos)
```
Converts mapchunk coordinates to node position (returns origin of mapchunk).

#### Mapchunk ↔ Citychunk

```lua
units.mapchunk_to_citychunk(mapchunk_pos)
```
Converts mapchunk coordinates to citychunk coordinates.

```lua
units.citychunk_to_mapchunk(citychunk_pos)
```
Converts citychunk coordinates to mapchunk coordinates (returns origin).

#### Citychunk ↔ Node

```lua
units.citychunk_to_node(citychunk_pos)
```
Converts citychunk coordinates to node position (returns origin of citychunk).

## Size Definitions

### sizes.node

```lua
{
    in_mapchunks = 1/80,      -- Fraction of a mapchunk
    in_citychunks = 1/8000,   -- Fraction of a citychunk
}
```

### sizes.mapchunk

```lua
{
    in_nodes = 80,            -- Size in nodes
    in_citychunks = 1/10,     -- Fraction of a citychunk
    pos_min = (0, 0, 0),      -- Minimum corner (relative)
    pos_max = (79, 79, 79),   -- Maximum corner (relative)
}
```

### sizes.citychunk

```lua
{
    in_nodes = 800,           -- Size in nodes (default)
    in_mapchunks = 10,        -- Size in mapchunks (default)
    pos_min = (0, 0, 0),      -- Minimum corner (relative)
    pos_max = (799, 799, 799),-- Maximum corner (relative)
    overgen_margin = 160,     -- Margin for overgeneration (2 mapchunks)
}
```

**Note:** The overgen_margin is at least 2 mapchunks, or 1 mapchunk if citychunk_size < 3.

## Height Level Constants

These define the vertical layers of the city:

```lua
sizes.room_height = 7          -- Standard room/floor height
sizes.ground_level = 8         -- Ground level Y coordinate (configurable)
sizes.city_max = 148           -- Maximum city height (ground + 20 floors)
sizes.city_min = 8             -- Minimum city height (ground level)
sizes.basement_max = -12       -- Maximum basement depth
sizes.hell_max_level = -13     -- Start of "hell" layer
```

### Layer Structure

```
Y = 148   : Top of city (20 floors above ground)
Y = 8     : Ground level (configurable)
Y = 7     : Top of basement
Y = -12   : Bottom of basement
Y = -13   : Start of hell layer
```

## Usage Examples

### Converting Coordinates

```lua
-- Node to citychunk
local node_pos = vector.new(1234, 8, 5678)
local citychunk_pos = sizes.units.node_to_mapchunk(node_pos)
citychunk_pos = sizes.units.mapchunk_to_citychunk(citychunk_pos)

-- Or directly (via utils.lua)
local citychunk_origin = pcmg.citychunk_origin(node_pos)
```

### Using Size Constants

```lua
-- Check if position is within a citychunk (relative coordinates)
local relative_pos = node_pos - citychunk_origin
if vector.in_area(relative_pos, sizes.citychunk.pos_min, sizes.citychunk.pos_max) then
    -- Position is inside citychunk
end

-- Generate building with standard room height
local floors = 5
local building_height = floors * sizes.room_height  -- 35 nodes
```

### Height Checks

```lua
-- Check if position is above ground
if pos.y >= sizes.ground_level then
    -- In city or above
elseif pos.y >= sizes.basement_max then
    -- In basement
else
    -- In hell layer
end
```

## Important Notes

1. **Configuration Dependency**: Sizes change based on Minetest settings
2. **Default Values**: Defaults are provided but can be overridden
3. **Relative Coordinates**: pos_min and pos_max are relative to chunk origins
4. **Overgeneration**: The margin determines how far canvas can draw outside its citychunk

## Related Modules

- **utils.lua** - Uses these sizes for coordinate conversion functions
- **canvas.lua** - Uses citychunk sizes and margins
- **mapgen.lua** - Uses all size constants for generation
