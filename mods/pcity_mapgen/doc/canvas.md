# Canvas Module

## Overview

Canvas is a data structure for storing and processing 2D citychunk (node) data. It provides a layer of abstraction between map planning and actual mapgen, serving as a blueprint for generating complex map layouts like city structures.

## Purpose

Canvas is designed to:
- Store material IDs for each node position in a citychunk
- Provide a cursor-based interface for reading and writing cells
- Support overgeneration through a margin area
- Enable priority-based material placement

## Data Structure

### Canvas Array

`canvas.array[x][z]` is a 2D array that stores material IDs (see `canvas_ids.lua`) corresponding to:
- Nodes (concrete blocks)
- Node groups (collections of related blocks)
- Abstract concepts (like building placeholders)

Each element is called a "cell" and stores data for one node. The canvas array is sized to a citychunk.

### Canvas Margin

The canvas margin is an area around the citychunk where reading/writing operations remain active. This allows drawing shapes that extend beyond citychunk boundaries, enabling limited overgeneration.

**Note**: Canvas only overwrites its own cells within the citychunk. Full overgeneration is provided by Megacanvas (see `megacanvas.lua`).

## Key Concepts

### Cursor System

Canvas uses a built-in cursor that:
- Points to a position where data can be read/written
- Can be moved to any position in the citychunk
- Can be positioned in the margin area for partial overgeneration
- Has an `inside` flag indicating whether it's within valid bounds

### Material Priority

Materials have priorities (see `canvas_ids.lua`). When writing:
- New material is only written if its priority ≥ current cell's material priority
- Higher priority materials can overwrite lower priority ones
- Equal priority can overwrite

## Main Functions

### Creation

```lua
canvas.new(citychunk_origin)
```
Creates a new canvas for the specified citychunk origin point.

### Cursor Operations

```lua
canvas:set_cursor(pos)
canvas:set_cursor_absolute(pos)
canvas:move_cursor(vec)
```
Position the cursor for read/write operations.

### Cell Operations

```lua
canvas:read_cell(x, z)
canvas:write_cell(x, z, material_id)
canvas:read_write_cell(x, z, material_id)
```
Read from and write to individual cells.

### Drawing Operations

```lua
canvas:draw_shape(shape)
canvas:draw_brush(brush)
canvas:draw_rectangle(x_side, z_side, material_id, centered)
canvas:draw_square(side, material_id, centered)
canvas:draw_circle(radius, material_id)
```
Draw various shapes at the cursor position.

### Search Operations

```lua
canvas:search_for_material(shape, material_id)
canvas:search_in_circle(radius, material_id)
```
Search for materials within specific areas.

## Usage Example

```lua
local canvas = pcmg.canvas.new(citychunk_origin)

-- Position cursor
canvas:set_cursor(vector.new(40, 0, 40))

-- Draw a road
canvas:draw_rectangle(10, 80, materials_by_name.road_asphalt, false)

-- Draw a circle at intersection
canvas:draw_circle(5, materials_by_name.road_center)
```

## Important Notes

- Canvas doesn't provide full overgeneration by itself
- Randomness must be reproducible and independent of citychunk for proper overgeneration
- Use Megacanvas for functions requiring non-reproducible randomness
- See bottom of `canvas.lua` for additional design considerations

## Related Modules

- **megacanvas.lua** - Provides full overgeneration capabilities
- **canvas_ids.lua** - Defines material IDs and priorities
- **canvas_brushes.lua** - Defines reusable drawing shapes
- **sizes.lua** - Defines citychunk dimensions and constants
