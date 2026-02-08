# Megacanvas Module

## Overview

Megacanvas is a class that manages overgeneration across multiple canvas objects. It provides a unified interface for drawing operations that automatically span across citychunk boundaries.

## Purpose

Megacanvas solves the overgeneration problem by:
- Managing a central citychunk canvas and its 8 neighboring canvases
- Providing a single cursor that applies to all managed canvases
- Automatically drawing to all canvases that intersect with the drawing area
- Implementing smart caching for partially and fully generated canvases

## Key Concepts

### Overgeneration

When generating features that cross citychunk boundaries (like roads or buildings), each citychunk needs to know about features in neighboring chunks. Megacanvas handles this by:

1. Creating canvases for the central chunk and all 8 neighbors
2. Setting the same absolute cursor position on all canvases
3. Calling drawing operations on all canvases simultaneously
4. Each canvas only draws within its valid area (chunk + margin)

### Method Delegation

Megacanvas implements `__index` to automatically delegate Canvas methods. When you call a Canvas method on a Megacanvas:

1. The method is called on the central canvas
2. The method is called on all 8 neighbor canvases
3. Results are collected and returned

For boolean results, Megacanvas returns the logical OR of all results.

## Main Functions

### Creation

```lua
megacanvas.new(citychunk_origin)
```
Creates a new megacanvas centered on the specified citychunk. Automatically creates canvases for all 9 citychunks (center + 8 neighbors).

### Cursor Operations

All Canvas cursor operations work on Megacanvas:

```lua
megacanvas:set_cursor(pos)           -- Set to relative position
megacanvas:set_cursor_absolute(pos)  -- Set to absolute world position
megacanvas:move_cursor(vec)          -- Move cursor by offset
```

The cursor position is replicated across all managed canvases.

### Drawing Operations

All Canvas drawing operations work on Megacanvas:

```lua
megacanvas:draw_shape(shape)
megacanvas:draw_rectangle(x_side, z_side, material_id, centered)
megacanvas:draw_circle(radius, material_id)
-- ... and all other Canvas drawing methods
```

Each operation is executed on all 9 canvases. Individual canvases only modify cells within their valid area.

### Search Operations

Search operations return combined results:

```lua
local found = megacanvas:search_in_circle(radius, material_id)
-- Returns true if material found in ANY of the canvases
```

## Caching System

Megacanvas provides smart caching to avoid regenerating canvases:

- **Partial generation**: Canvases are generated on-demand
- **Full generation**: Once a citychunk is fully generated, it's cached
- **Memory efficiency**: Uses weak tables to allow garbage collection

## Usage Example

```lua
-- Create megacanvas for citychunk
local mcanvas = pcmg.megacanvas.new(citychunk_origin)

-- Set cursor to absolute world position
mcanvas:set_cursor_absolute(vector.new(1234, 8, 5678))

-- Draw a large road that crosses chunk boundaries
-- This automatically draws to all affected chunks
mcanvas:draw_rectangle(150, 20, materials_by_name.road_asphalt, false)

-- Draw intersection circle
mcanvas:draw_circle(10, materials_by_name.road_center)

-- Search across all chunks
local has_road = mcanvas:search_in_circle(50, materials_by_name.road_asphalt)
```

## Comparison: Canvas vs Megacanvas

| Feature | Canvas | Megacanvas |
|---------|--------|------------|
| **Scope** | Single citychunk | 9 citychunks (3x3 grid) |
| **Overgeneration** | Limited (margin only) | Full (automatic) |
| **Drawing** | Draws to one chunk | Draws to all affected chunks |
| **Use case** | Simple, contained features | Features crossing boundaries |
| **Performance** | Faster | Slower (manages 9 canvases) |

## When to Use

**Use Canvas when:**
- Features are contained within a single citychunk
- Performance is critical
- You don't need cross-boundary generation

**Use Megacanvas when:**
- Features can cross citychunk boundaries
- You need consistent generation across boundaries
- You need to search across neighboring chunks

## Implementation Details

### Method Creation

The `make_method` function wraps Canvas methods for Megacanvas use:

```lua
local function make_method(method)
    return function (self, ...)
        local products = {}
        -- Call on central canvas
        products[central_hash] = method(self.central, ...)
        -- Call on all neighbors
        for _, neighbor in pairs(self.neighbors) do
            products[hash] = method(neighbor, ...)
        end
        -- Return combined results
        return products
    end
end
```

### Automatic Canvas Method Access

The `__index` metamethod provides transparent access to Canvas methods:

```lua
megacanvas.__index = function(object, key)
    if megacanvas[key] then
        return megacanvas[key]
    elseif pcmg.canvas[key] then
        return make_method(pcmg.canvas[key])
    end
end
```

## Important Notes

1. **Performance**: Megacanvas is slower than Canvas due to managing multiple canvases
2. **Memory**: Uses more memory (9x canvases), but implements caching
3. **Consistency**: Ensures consistent generation across chunk boundaries
4. **Automatic**: Canvas methods work automatically without modification

## Related Modules

- **canvas.lua** - The underlying canvas implementation
- **sizes.lua** - Defines citychunk sizes and margins
- **utils.lua** - Provides neighbor calculation functions
