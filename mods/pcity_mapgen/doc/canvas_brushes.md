# Canvas Brushes Module

## Overview

The canvas_brushes module provides tools for creating reusable drawing shapes and brush objects for the canvas system. It includes shape generation, caching, and animation capabilities.

## Purpose

This module handles:
- Creating geometric shapes (rectangles, circles, lines)
- Caching generated shapes for performance
- Combining multiple shapes
- Animated brush patterns
- Shape transformations

## Canvas Shapes (cs)

The `pcmg.canvas_shapes` table provides shape generation functions.

### Shape Structure

All shapes are tables of cells, where each cell contains:
```lua
{
    pos = vector,      -- Position relative to cursor
    material = id      -- Material ID from canvas_ids
}
```

### Shape Caching

Shapes are automatically cached using a hash of their parameters:
- Prevents regenerating identical shapes
- Improves performance for repeated use
- Cache persists for the lifetime of the module

## Shape Generation Functions

### Rectangle

```lua
canvas_shapes.make_rectangle(x_side, z_side, material_id, centered)
```
Creates a rectangular shape.

**Parameters:**
- `x_side` - Width in X direction (nodes)
- `z_side` - Width in Z direction (nodes)
- `material_id` - Material to use for all cells
- `centered` - If true, center is at (0,0); if false, corner is at (0,0)

**Example:**
```lua
-- 10x20 rectangle centered at origin
local rect = canvas_shapes.make_rectangle(10, 20, materials_by_name.road_asphalt, true)
canvas:draw_shape(rect)
```

### Circle

```lua
canvas_shapes.make_circle(radius, material_id)
```
Creates a circular shape with specified radius.

**Parameters:**
- `radius` - Radius in nodes
- `material_id` - Material to use for all cells

**Details:**
- Diameter = 2 * radius + 1
- Centered at (0, 0)
- Uses distance formula to determine inclusion

**Example:**
```lua
-- Circle with radius 5
local circle = canvas_shapes.make_circle(5, materials_by_name.road_center)
canvas:draw_shape(circle)
```

### Line

```lua
canvas_shapes.make_line(vec, material_id)
```
Creates a line shape from origin to the specified vector.

**Parameters:**
- `vec` - Direction and length vector
- `material_id` - Material to use for line

**Algorithm:**
- Samples vector at 3x length for smooth line
- Uses floor to snap to grid
- Removes duplicate positions with hashing

**Example:**
```lua
-- Line 50 nodes in X direction
local line = canvas_shapes.make_line(vector.new(50, 0, 0), materials_by_name.road_asphalt)
canvas:draw_shape(line)
```

### Combining Shapes

```lua
canvas_shapes.combine_shapes(shape1, shape2)
```
Combines two shapes into one. If shapes overlap, shape2 cells override shape1 cells.

**Example:**
```lua
local road = canvas_shapes.make_rectangle(100, 10, materials_by_name.road_asphalt, false)
local center = canvas_shapes.make_line(vector.new(100, 0, 0), materials_by_name.road_center)
local complete = canvas_shapes.combine_shapes(road, center)
canvas:draw_shape(complete)
```

## Canvas Brush

The `pcmg.canvas_brush` class provides animated and multi-frame brushes.

### Creation

```lua
canvas_brush.new(shape1, shape2, ...)
```
Creates a brush from one or more shapes.

**Parameters:**
- Variable number of shape arguments
- Each shape is a shape table from canvas_shapes

### Brush Properties

```lua
brush.shapes        -- Array of shapes
brush.current       -- Current shape index (1-based)
brush.animate       -- Boolean: enable animation
brush.random_order  -- Boolean: use random shape selection
```

### Getting Shapes

```lua
brush:get_shape()
```
Returns the current shape and optionally advances to next.

**Behavior:**
- If `animate == false`: Always returns first shape
- If `animate == true` and `random_order == false`: Cycles through shapes
- If `animate == true` and `random_order == true`: Returns random shape

## Usage Examples

### Static Brush

```lua
local road_shape = canvas_shapes.make_rectangle(10, 100, materials_by_name.road_asphalt, false)
local brush = canvas_brush.new(road_shape)

-- Draw at multiple positions
canvas:set_cursor(vector.new(0, 0, 0))
canvas:draw_brush(brush)  -- Always draws same shape

canvas:set_cursor(vector.new(200, 0, 0))
canvas:draw_brush(brush)  -- Same shape again
```

### Animated Brush (Sequential)

```lua
-- Create frames for animated pattern
local frame1 = canvas_shapes.make_circle(3, materials_by_name.road_center)
local frame2 = canvas_shapes.make_circle(4, materials_by_name.road_center)
local frame3 = canvas_shapes.make_circle(5, materials_by_name.road_center)

local brush = canvas_brush.new(frame1, frame2, frame3)
brush.animate = true

-- Each call draws next frame
canvas:draw_brush(brush)  -- Draws frame1
canvas:move_cursor(vector.new(10, 0, 0))
canvas:draw_brush(brush)  -- Draws frame2
canvas:move_cursor(vector.new(10, 0, 0))
canvas:draw_brush(brush)  -- Draws frame3
canvas:move_cursor(vector.new(10, 0, 0))
canvas:draw_brush(brush)  -- Cycles back to frame1
```

### Random Animated Brush

```lua
local shapes = {
    canvas_shapes.make_circle(3, materials_by_name.road_pavement),
    canvas_shapes.make_circle(4, materials_by_name.road_pavement),
    canvas_shapes.make_circle(5, materials_by_name.road_pavement),
}

local brush = canvas_brush.new(unpack(shapes))
brush.animate = true
brush.random_order = true

-- Each call draws random shape
for i = 1, 10 do
    canvas:set_cursor(vector.new(i * 10, 0, 0))
    canvas:draw_brush(brush)  -- Random shape each time
end
```

## Performance Considerations

### Caching

- Shapes are cached by parameter hash
- Reusing same parameters returns cached shape (fast)
- Cache is never cleared (shapes are small)
- Different parameters generate new shapes

### Hash Function

The `cheap_hash` function uses:
- Serialization of parameters
- Base64 encoding
- Fast but not cryptographically secure
- Sufficient for shape caching

## Implementation Details

### Position Hashing

Internal functions use position hashing for deduplication:
```lua
hash_shape_positions(shape)   -- Converts array to hash table
unhash_shape_positions(hashed) -- Converts back to array
```

This allows:
- Efficient shape combination (no duplicates)
- Fast line generation (removes repeated positions)
- Consistent cell ordering

## Related Modules

- **canvas.lua** - Uses shapes via draw_shape and draw_brush
- **canvas_ids.lua** - Provides material IDs for shapes
- **megacanvas.lua** - Inherits shape drawing from canvas
