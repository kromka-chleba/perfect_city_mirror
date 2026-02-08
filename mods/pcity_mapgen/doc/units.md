# Units Module

## Overview

The units module provides coordinate conversion functions between Perfect City's three coordinate systems. This module is standalone and contains all the logic for translating positions between different scales.

## Purpose

Perfect City uses a hierarchical coordinate system:
- **Nodes**: Individual block positions (1x1x1) - the base unit
- **Mapchunks**: Minetest's native chunks (typically 80x80x80 nodes)
- **Citychunks**: Perfect City's larger chunks (typically 10x10 mapchunks = 800x800x800 nodes)

This module handles all conversions between these coordinate systems.

## Design Pattern

This module follows the pattern from the Mapchunk Shepherd mod, organizing unit conversions in a dedicated file separate from size definitions. This provides:
- Clear separation of concerns
- Easy to find conversion functions
- No circular dependencies
- Consistent interface

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

## Usage Examples

### Get Mapchunk Origin

```lua
local units = sizes.units
local world_pos = vector.new(1234, 8, 5678)
local mapchunk_origin = units.mapchunk_to_node(units.node_to_mapchunk(world_pos))
```

### Get Citychunk Origin

```lua
local units = sizes.units
local world_pos = vector.new(1234, 8, 5678)
local citychunk_coords = units.mapchunk_to_citychunk(units.node_to_mapchunk(world_pos))
local citychunk_origin = units.citychunk_to_node(vector.floor(citychunk_coords))
```

### Convert Between Coordinate Systems

```lua
-- Node -> Mapchunk -> Citychunk
local node_pos = vector.new(800, 0, 800)
local mapchunk_pos = units.node_to_mapchunk(node_pos)
local citychunk_pos = units.mapchunk_to_citychunk(mapchunk_pos)

-- Citychunk -> Mapchunk -> Node
local citychunk_coords = vector.new(1, 0, 1)
local mapchunk_coords = units.citychunk_to_mapchunk(citychunk_coords)
local origin = units.mapchunk_to_node(mapchunk_coords)
```

## Important Notes

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

## Integration with sizes.lua

The units module is loaded by sizes.lua:

```lua
-- In sizes.lua
sizes.units = dofile(mod_path.."/units.lua")
```

This makes unit functions available through the sizes table:
```lua
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units
local origin = units.citychunk_to_node(coords)
```

## Comparison with Shepherd Mod

This implementation follows the same pattern as Mapchunk Shepherd:
- Dedicated units.lua file
- Separation from size definitions
- Consistent function naming
- Direct reading of configuration

Differences:
- Perfect City has 3 levels (node/mapchunk/citychunk) vs Shepherd's 2 levels
- Perfect City uses mapchunk offsets for alignment
- Citychunk is configurable in Perfect City

## Related Modules

- **sizes.lua** - Loads units and defines size constants
- **utils.lua** - Uses units for higher-level coordinate operations
- **mapgen.lua** - Uses units for chunk-based generation

## See Also

For higher-level coordinate functions that use these units, see:
- `utils.lua` - Functions like `pcmg.citychunk_origin(pos)`
- `sizes.md` - Documentation on size definitions
