# Building Module System

## Overview

The Building Module system provides a modular building framework for Perfect City. Building modules are cuboid spaces that can be connected together via junction surfaces to create complex structures.

## Features

### 1. Cuboid Space Definition
- Modules are defined by `pos` (absolute world position) and `size` (dimensions vector)
- `pos` represents the origin point of the module (0,0,0 in module-local coordinates)
- `size` represents the dimensions (x, y, z) of the module
- Simple representation for positioning and sizing

### 2. Junction Surfaces
- Each module can have junction surfaces on any of its 6 faces:
  - `y+` - positive Y direction (up)
  - `y-` - negative Y direction (down)
  - `z-` - negative Z direction
  - `z+` - positive Z direction
  - `x+` - positive X direction
  - `x-` - negative X direction
- Junction surfaces have identifiers that must match for modules to connect
- Allows for flexible building composition

### 3. Schematic Storage
- Modules can store multiple Luanti schematics
- Each schematic has a position relative to the module's origin (0,0,0 in module-local space)
- Module origin (0,0,0 local) corresponds to `pos` in world coordinates
- Schematics can be stored by name or numeric index
- Allows for variations within the same module type
- Position enables proper placement within the module bounds

### 4. Rotation Support
- **Y-axis rotation** (primary): Rotate modules around the vertical axis
  - Supports 90, 180, 270 degree rotations
  - Junction surfaces rotate accordingly
  - Uses Luanti's `vector.rotate` internally
- **Axis-aligned rotation**: Rotate around X, Y, or Z axes
  - Supports rotation around any axis-aligned vector
  - Restricted to 90-degree multiples (voxel game requirement)
  - Enables creative building orientations

## Usage Example

```lua
local building_module = pcity_mapgen.building_module

-- Create a module with position and size
local room = building_module.new(
    vector.new(0, 0, 0),  -- position in world
    vector.new(11, 6, 11)  -- size (dimensions)
)

-- Set junction surfaces for connection
room:set_junction_surface("y+", "standard_ceiling")
room:set_junction_surface("y-", "standard_floor")
room:set_junction_surface("z-", "door_wall")

-- Add schematics
local schematic = {
    size = {x = 11, y = 6, z = 11},
    data = {...}
}
-- Position relative to module's origin (0,0,0 in module-local space)
room:add_schematic(schematic, vector.new(0, 0, 0), "default_variant")

-- Rotate for variety (size updates automatically)
room:rotate_y(90)  -- Rotate 90 degrees around Y axis

-- Check if modules can connect
local hallway = building_module.new(vector.new(0, 0, 11), vector.new(11, 6, 5))
hallway:set_junction_surface("z+", "door_wall")

if room:can_connect(hallway, "z-", "z+") then
    -- These modules can be connected
end
```

## API Reference

### Constructor
- `building_module.new(pos, size)` - Create a new module
  - `pos`: vector - absolute world position (module origin)
  - `size`: vector - dimensions (x, y, z)

### Type Checking
- `building_module.check(obj)` - Check if object is a building module

### Geometry
- `:get_size()` - Returns size vector (copy)
- `:get_center()` - Returns center position in world coordinates
- `:get_min_pos()` - Returns minimum corner position
- `:get_max_pos()` - Returns maximum corner position

### Junction Surfaces
- `:set_junction_surface(face, surface_id)` - Set a junction surface
- `:get_junction_surface(face)` - Get a junction surface ID
- `:remove_junction_surface(face)` - Remove a junction surface
- `:can_connect(other, this_face, other_face)` - Check connection compatibility

### Schematics
- `:add_schematic(schematic, relative_pos, name)` - Add a schematic with position relative to min_pos
- `:get_schematic(identifier)` - Get a schematic entry by name or index (returns {schematic, relative_pos})
- `:get_all_schematics()` - Get all schematic entries
- `:remove_schematic(identifier)` - Remove a schematic

### Rotation
- `:rotate_y(angle_degrees)` - Rotate around Y axis (must be multiple of 90)
- `:rotate_axis(axis, angle_degrees)` - Rotate around axis-aligned vector (x/y/z, multiple of 90)

## Design Principles

Following Perfect City coding guidelines:
- Small, focused functions (under 30 lines)
- Clear naming conventions (snake_case)
- Comprehensive input validation
- Well-documented public API
- Separation of concerns (checks in separate file)
- Comprehensive unit tests
