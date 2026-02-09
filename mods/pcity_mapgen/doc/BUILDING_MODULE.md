# Building Module System

## Overview

The Building Module system provides a modular building framework for Perfect City. Building modules are cuboid spaces that can be connected together via junction surfaces to create complex structures.

## Features

### 1. Cuboid Space Definition
- Modules are defined by `min_pos` and `max_pos` vectors
- Represents a 3D rectangular space in the game world

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
- Schematics can be stored by name or numeric index
- Allows for variations within the same module type

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

-- Create a module
local room = building_module.new(
    vector.new(0, 0, 0),
    vector.new(10, 5, 10)
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
room:add_schematic(schematic, "default_variant")

-- Rotate for variety
room:rotate_y(90)  -- Rotate 90 degrees around Y axis

-- Check if modules can connect
local hallway = building_module.new(...)
hallway:set_junction_surface("z+", "door_wall")

if room:can_connect(hallway, "z-", "z+") then
    -- These modules can be connected
end
```

## API Reference

### Constructor
- `building_module.new(min_pos, max_pos)` - Create a new module

### Type Checking
- `building_module.check(obj)` - Check if object is a building module

### Geometry
- `:get_size()` - Returns size as a vector
- `:get_center()` - Returns center position

### Junction Surfaces
- `:set_junction_surface(face, surface_id)` - Set a junction surface
- `:get_junction_surface(face)` - Get a junction surface ID
- `:remove_junction_surface(face)` - Remove a junction surface
- `:can_connect(other, this_face, other_face)` - Check connection compatibility

### Schematics
- `:add_schematic(schematic, name)` - Add a schematic
- `:get_schematic(identifier)` - Get a schematic by name or index
- `:get_all_schematics()` - Get all schematics
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
