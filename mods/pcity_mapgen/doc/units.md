# Units Module

## Overview

The units module is the **master module** for Perfect City's coordinate systems and size definitions. It provides both coordinate conversion functions and size constants in a single, cohesive module.

## Purpose

Perfect City uses a hierarchical coordinate system:
- **Nodes**: Individual block positions (1x1x1) - the base unit
- **Mapchunks**: Minetest's native chunks (can be non-cubic, specified in blocks)
- **Citychunks**: Perfect City's larger chunks (typically 10x10 mapchunks)

This module provides:
- **Conversion functions** between coordinate systems (top-level functions)
- **Size constants** via the `units.sizes` table (read-only)

## Module Structure

```lua
units = {
    -- Conversion functions (top-level)
    node_to_mapchunk = function(pos) ... end,
    mapchunk_to_node = function(mapchunk_pos) ... end,
    -- ... more conversion functions ...
    
    -- Size constants (read-only table)
    sizes = {
        node = { in_mapchunks = vector(...), in_citychunks = vector(...) },
        mapchunk = { in_nodes = vector(...), in_citychunks = vector(...) },
        citychunk = { in_nodes = vector(...), in_mapchunks = vector(...) },
        room_height = 7,
        ground_level = 8,
        -- ... more constants ...
    }
}
```

## Key Feature: Read-Only Sizes

The `units.sizes` table is **read-only** using LuaJIT metamethods. Any attempt to modify it will result in an error:

```lua
units.sizes.new_field = "value"  -- ERROR: Attempt to modify read-only sizes table
```

This prevents accidental modification of size constants, which could cause inconsistent behavior throughout the mapgen system.

## Usage

### Basic Usage

```lua
local mod_path = core.get_modpath("pcity_mapgen")
local units = dofile(mod_path.."/units.lua")

-- Use conversion functions
local mapchunk_pos = units.node_to_mapchunk(node_pos)

-- Access size constants (note: many are now vectors!)
local chunk_size = units.sizes.citychunk.in_nodes  -- This is a vector
```

## Non-Cubic Mapchunks

**Important:** Mapchunks can now be non-cubic! The chunksize is retrieved using `core.get_mapgen_chunksize()` which returns a vector.

This means:
- `mapchunk_size` is a vector (x, y, z can be different)
- Many size constants are now vectors instead of scalars
- Conversion functions handle per-axis calculations

## Configuration

The module reads configuration values directly:
- `chunksize` mapgen setting (default: 5 blocks)
- `pcity_citychunk_size` setting (default: 10 mapchunks)

These determine:
- `mapchunk_size` = 80 nodes (5 blocks * 16 nodes/block)
- `mapchunk_offset` = -32 nodes (offset for chunk alignment)
- `citychunk_size` = 10 mapchunks

## Conversion Functions

### Node ↔ Mapchunk

```lua
units.node_to_mapchunk(pos)
```
Converts a node position to mapchunk coordinates.

**Parameters:**
- `pos` - Node position vector

**Returns:** Mapchunk position (may have fractional parts)

```lua
units.mapchunk_to_node(mapchunk_pos)
```
Converts mapchunk coordinates to node position (returns origin corner).

**Parameters:**
- `mapchunk_pos` - Mapchunk position vector

**Returns:** Node position vector (origin of the mapchunk)

### Mapchunk ↔ Citychunk

```lua
units.mapchunk_to_citychunk(mapchunk_pos)
```
Converts mapchunk coordinates to citychunk coordinates.

**Parameters:**
- `mapchunk_pos` - Mapchunk position vector

**Returns:** Citychunk position (may have fractional parts)

```lua
units.citychunk_to_mapchunk(citychunk_pos)
```
Converts citychunk coordinates to mapchunk coordinates (returns origin corner).

**Parameters:**
- `citychunk_pos` - Citychunk position vector

**Returns:** Mapchunk position vector (origin of the citychunk)

## Configuration

The module reads configuration values directly:
- `chunksize` mapgen setting (default: 5 blocks)
- `pcity_citychunk_size` setting (default: 10 mapchunks)

These determine:
- `mapchunk_size` = 80 nodes (5 blocks * 16 nodes/block)
- `mapchunk_offset` = -32 nodes (offset for chunk alignment)
- `citychunk_size` = 10 mapchunks

## Conversion Functions

### Node ↔ Mapchunk

```lua
units.node_to_mapchunk(pos)
```
Converts a node position to mapchunk coordinates.

**Parameters:**
- `pos` - Node position vector

**Returns:** Mapchunk position (may have fractional parts)

```lua
units.mapchunk_to_node(mapchunk_pos)
```
Converts mapchunk coordinates to node position (returns origin corner).

**Parameters:**
- `mapchunk_pos` - Mapchunk position vector

**Returns:** Node position vector (origin of the mapchunk)

### Mapchunk ↔ Citychunk

```lua
units.mapchunk_to_citychunk(mapchunk_pos)
```
Converts mapchunk coordinates to citychunk coordinates.

**Parameters:**
- `mapchunk_pos` - Mapchunk position vector

**Returns:** Citychunk position (may have fractional parts)

```lua
units.citychunk_to_mapchunk(citychunk_pos)
```
Converts citychunk coordinates to mapchunk coordinates (returns origin corner).

**Parameters:**
- `citychunk_pos` - Citychunk position vector

**Returns:** Mapchunk position vector (origin of the citychunk)

### Citychunk ↔ Node (Combined)

```lua
units.citychunk_to_node(citychunk_pos)
```
Converts citychunk coordinates directly to node position (returns origin corner).

**Parameters:**
- `citychunk_pos` - Citychunk position vector

**Returns:** Node position vector (origin of the citychunk)

**Implementation:** Combines `citychunk_to_mapchunk` and `mapchunk_to_node`

## Size Constants (units.sizes)

The `units.sizes` table contains all size definitions and constants for the mapgen system. This table is **read-only** and cannot be modified.

**Important:** Many size values are now **vectors** rather than scalars to support non-cubic mapchunks.

### Size Definitions

```lua
-- Note: Many values are vectors to support non-cubic chunks
units.sizes.node = {
    in_mapchunks = vector(...),      -- Fraction of a mapchunk (per-axis)
    in_citychunks = vector(...),     -- Fraction of a citychunk (per-axis)
}

units.sizes.mapchunk = {
    in_nodes = vector(...),          -- Size in nodes (can be non-cubic!)
    in_citychunks = vector(...),     -- Fraction of a citychunk (per-axis)
    pos_min = (0, 0, 0),            -- Minimum corner (relative)
    pos_max = vector(...),          -- Maximum corner (relative, depends on chunksize)
}

units.sizes.citychunk = {
    in_nodes = vector(...),          -- Size in nodes (depends on mapchunk size)
    in_mapchunks = vector(...),      -- Size in mapchunks (can be non-cubic)
    pos_min = (0, 0, 0),            -- Minimum corner (relative)
    pos_max = vector(...),          -- Maximum corner (relative)
    overgen_margin = vector(...),    -- Margin for overgeneration (2x mapchunk size)
}
```

### Height Level Constants

```lua
units.sizes.room_height = 7          -- Standard room/floor height
units.sizes.ground_level = 8         -- Ground level Y coordinate (configurable)
units.sizes.city_max = 148           -- Maximum city height (ground + 20 floors)
units.sizes.city_min = 8             -- Minimum city height (ground level)
units.sizes.basement_max = -12       -- Maximum basement depth
units.sizes.hell_max_level = -13     -- Start of "hell" layer
```

## Usage Examples

### Get Mapchunk Origin

```lua
local units = dofile(mod_path.."/units.lua")
local world_pos = vector.new(1234, 8, 5678)
local mapchunk_coords = vector.floor(units.node_to_mapchunk(world_pos))
local mapchunk_origin = units.mapchunk_to_node(mapchunk_coords)
```

### Get Citychunk Origin

```lua
local units = dofile(mod_path.."/units.lua")
local world_pos = vector.new(1234, 8, 5678)
local mapchunk_pos = units.node_to_mapchunk(world_pos)
local citychunk_coords = vector.floor(units.mapchunk_to_citychunk(mapchunk_pos))
local citychunk_origin = units.citychunk_to_node(citychunk_coords)
```

### Using Size Constants

```lua
local units = dofile(mod_path.."/units.lua")

-- Get chunk dimensions (note: this is a vector!)
local chunk_size = units.sizes.citychunk.in_nodes  -- vector(...)

-- Check height levels
if pos.y >= units.sizes.ground_level then
    -- In city or above
elseif pos.y >= units.sizes.basement_max then
    -- In basement
else
    -- In hell layer
end
```

### Working with Non-Cubic Chunks

```lua
local units = dofile(mod_path.."/units.lua")

-- Mapchunk size is a vector
local mapchunk_size = units.sizes.mapchunk.in_nodes
print("Mapchunk dimensions:", mapchunk_size.x, mapchunk_size.y, mapchunk_size.z)

-- Access individual dimensions
local width = mapchunk_size.x
local height = mapchunk_size.y
local depth = mapchunk_size.z
```

### Read-Only Protection

```lua
local units = dofile(mod_path.."/units.lua")

-- This works fine
local size = units.sizes.citychunk.in_nodes

-- This will cause an error
units.sizes.new_field = "value"  -- ERROR!
units.sizes.citychunk = {}        -- ERROR!
```

## Important Notes

### Non-Cubic Mapchunks

**Critical:** Mapchunks can now be non-cubic! Always treat size values as vectors:
- `units.sizes.mapchunk.in_nodes` is a vector, not a number
- `units.sizes.citychunk.in_nodes` is a vector
- Access individual dimensions: `size.x`, `size.y`, `size.z`

### Coordinate Rounding

- Conversion TO higher-level units (node→mapchunk, mapchunk→citychunk) may produce fractional coordinates
- Use `vector.floor()` to get the coordinate of the chunk containing a position
- Conversion FROM higher-level units (mapchunk→node, citychunk→node) returns the **origin corner** (minimum position)

### Origin vs Position

All "to_node" functions return the **origin** (minimum corner) of the chunk:
- `mapchunk_to_node({1, 0, 0})` returns the southwest-bottom corner of mapchunk (1,0,0)
- To get other corners, add the chunk size to the origin

### Floating Point Precision

The module uses `vector.round()` in `mapchunk_to_node` to avoid floating-point precision issues.

### Read-Only Sizes

The sizes table is protected against modification:
- Attempts to set new fields will raise an error
- Attempts to modify existing fields will raise an error
- The metatable is hidden to prevent bypassing protection

### Constants Used

- `core.MAP_BLOCKSIZE` (=16) - Size of a mapblock in nodes
- `core.get_mapgen_chunksize()` - Returns chunksize as a vector in blocks

## Related Modules

- **utils.lua** - Uses units for higher-level coordinate operations
- **mapgen.lua** - Uses units for chunk-based generation
- **canvas.lua** - Uses size constants for canvas dimensions

## Related Modules

- **sizes.lua** - Loads units and defines size constants
- **utils.lua** - Uses units for higher-level coordinate operations
- **mapgen.lua** - Uses units for chunk-based generation

## See Also

For higher-level coordinate functions that use these units, see:
- `utils.lua` - Functions like `pcmg.citychunk_origin(pos)`
- `sizes.md` - Documentation on size definitions
