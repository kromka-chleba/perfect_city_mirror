# Canvas 3D and 3D Roads

This document describes the Canvas 3D feature and the test implementation of 3D roads.

## Overview

Canvas 3D extends the original 2D canvas system to support 3D map generation. While the original canvas stores and processes data in a 2D array (x, z), Canvas 3D uses a 3D array (x, y, z) to allow for map features at different y levels.

## Files

### Core Canvas 3D System
- **canvas3d.lua**: The 3D canvas class that stores a 3D array of material IDs
- **megacanvas3d.lua**: Manages overgeneration across multiple canvas3d objects, including vertical neighbors

### 3D Roads (Test Implementation)
- **roads_layout_3d.lua**: Road layout generator that creates roads with varying y levels
- **roads_mapgen_3d.lua**: Writes 3D roads from canvas3d to the voxel manipulator

## Canvas 3D vs Canvas 2D

### Canvas 2D
- Uses `canvas.array[x][z]` to store material IDs
- Cursor has x, y, z but y is always set to 0
- Drawing methods operate on the x-z plane
- Used for features at a single y level (e.g., flat roads)

### Canvas 3D
- Uses `canvas3d.array[x][y][z]` to store material IDs
- Cursor uses all three dimensions (x, y, z)
- Drawing methods work in 3D space
- Allows features at different y levels (e.g., elevated roads, ramps)

## Key Methods

### Canvas 3D
```lua
canvas3d.new(citychunk_origin)           -- Create new 3D canvas
canvas3d:set_cursor(pos)                 -- Set cursor to position (uses y)
canvas3d:read_cell(x, y, z)              -- Read cell at 3D position
canvas3d:write_cell(x, y, z, material)   -- Write cell at 3D position
canvas3d:draw_box(x, y, z, material)     -- Draw a 3D box
canvas3d:draw_rectangle(x, z, material)  -- Draw rectangle at current y level
canvas3d:draw_circle(radius, material)   -- Draw circle at current y level
```

### Megacanvas 3D
```lua
megacanvas3d.new(origin, cache)          -- Create new megacanvas with 26 neighbors
megacanvas3d:set_all_cursors(pos)       -- Set cursors for all canvases
megacanvas3d:draw_path(shape, path)      -- Draw path in 3D
megacanvas3d:generate(func, level)       -- Generate with overgeneration
```

## 3D Roads

The 3D road system is a test implementation that demonstrates Canvas 3D capabilities.

### How It Works

1. **Road Origins**: Road connection points are generated with varying y levels
2. **Path Building**: Roads connect these points using paths that can change elevation
3. **Drawing**: The megacanvas3d draws roads at their specified y levels
4. **Writing**: `write_roads_3d` iterates through the 3D canvas array and writes nodes to the voxel area

### Enabling 3D Roads

Add to `minetest.conf`:
```
pcity_use_3d_roads = true
```

When enabled, the mapgen will use 3D roads instead of the flat 2D roads.

### Differences from 2D Roads

- Road origins have varying y levels (ground_level + offset)
- Roads can ramp up and down between connection points
- The canvas stores road data at multiple y levels
- Writing roads checks all y levels in the canvas, not just ground level

## Overgeneration in 3D

Canvas 3D supports overgeneration just like Canvas 2D:
- Megacanvas3D manages 27 canvases (central + 26 neighbors including vertical)
- Each canvas has a margin area where overgeneration can write
- The generate() function ensures proper recursive generation of neighbors
- Caching prevents regenerating the same citychunk

## Testing

Tests for Canvas 3D are in `tests/tests_canvas3d.lua` and include:
- Canvas 3D creation and structure
- Cursor positioning in 3D
- Reading and writing cells in 3D
- Drawing boxes and rectangles
- Megacanvas 3D functionality
- Caching behavior

Run tests with:
```bash
./.util/run_tests.sh
```

## Future Work

Canvas 3D and the 3D road implementation provide the foundation for:
- Multi-level city generation (ground level, elevated highways, underground tunnels)
- Buildings with multiple floors
- Terrain-following roads that adapt to elevation
- Bridges and overpasses
- Complex 3D structures

## Notes

- The 3D road implementation is meant as test/demo code
- Canvas 3D uses more memory than Canvas 2D due to the extra dimension
- Performance should be monitored when using 3D canvases for large areas
- The y dimension respects the citychunk_size_y setting from units.lua
