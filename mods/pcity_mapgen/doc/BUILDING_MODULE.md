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
- Junctions are defined as areas on module faces with specific types and positions
- Each module can have junctions on any of its 6 faces:
  - `y+` - positive Y direction (up)
  - `y-` - negative Y direction (down)
  - `z-` - negative Z direction
  - `z+` - positive Z direction
  - `x+` - positive X direction
  - `x-` - negative X direction
- Junctions have:
  - **Type**: e.g., "corridor", "hall", "staircase"
  - **Position bounds**: `pos_min` and `pos_max` (relative to module origin)
  - **Face**: which face the junction is on
- Junctions must lie on a face plane (one coordinate constant)
- Modules can connect if their junctions have matching types and compatible dimensions
- Allows for precise, position-aware building composition

### 3. Schematic Storage
- Modules can store multiple Luanti schematics
- Each schematic has a position relative to the module's origin (0,0,0 in module-local space)
- Module origin (0,0,0 local) corresponds to `pos` in world coordinates
- Schematics can be stored by name or numeric index
- Allows for variations within the same module type
- Position enables proper placement within the module bounds

### 4. Rotation Support
- **Y-axis rotation**: Rotate modules around the vertical axis
  - Supports 90, 180, 270 degree rotations
  - Junction positions and faces rotate accordingly
  - Module dimensions swap for 90/270 degree rotations
  - Uses Luanti's `vector.rotate` internally

## Usage Example

### Basic Usage with Legacy API

```lua
local building_module = pcity_mapgen.building_module

-- Create a module with position and size
local room = building_module.new(
    vector.new(0, 0, 0),  -- position in world
    vector.new(11, 6, 11)  -- size (dimensions)
)

-- Set junction surfaces for connection (legacy API)
room:set_junction_surface("y+", "standard_ceiling")
room:set_junction_surface("y-", "standard_floor")
room:set_junction_surface("z-", "door_wall")

-- Check if modules can connect
local hallway = building_module.new(vector.new(0, 0, 11), vector.new(11, 6, 5))
hallway:set_junction_surface("z+", "door_wall")

if room:can_connect(hallway, "z-", "z+") then
    -- These modules can be connected
end
```

### Advanced Usage with Junction Objects

```lua
local building_module = pcity_mapgen.building_module
local junction = pcity_mapgen.junction

-- Create a module
local room = building_module.new(
    vector.new(0, 0, 0),
    vector.new(11, 6, 11)
)

-- Create a junction with specific position bounds
-- This corridor junction is a 3x3 area on the north (z-) face
local corridor_junction = junction.new(
    "corridor",                    -- type
    vector.new(4, 0, 0),          -- pos_min (relative to module origin)
    vector.new(6, 2, 0),          -- pos_max
    "z-"                          -- face
)

room:add_junction(corridor_junction)

-- Create another module with matching junction
local hallway = building_module.new(vector.new(0, 0, 11), vector.new(11, 6, 5))
local hallway_junction = junction.new(
    "corridor",
    vector.new(4, 0, 4),          -- matching dimensions
    vector.new(6, 2, 4),
    "z+"
)

hallway:add_junction(hallway_junction)

-- Modules can connect because junctions match
if room:can_connect(hallway, "z-", "z+") then
    -- Junctions are compatible!
end

-- Add schematics
local schematic = {
    size = {x = 11, y = 6, z = 11},
    data = {...}
}
-- Position relative to module's origin (0,0,0 in module-local space)
room:add_schematic(schematic, vector.new(0, 0, 0), "default_variant")

-- Rotate for variety (size and junctions update automatically)
room:rotate_y(90)  -- Rotate 90 degrees around Y axis
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

### Junction Management (New API)
- `:add_junction(junction)` - Add a Junction object to the module
- `:get_junction(face)` - Get Junction object for specified face
- `:remove_junction(face)` - Remove junction from specified face
- `:get_all_junctions()` - Get all Junction objects on this module
- `:can_connect(other, this_face, other_face)` - Check if junctions are compatible

### Junction Surfaces (Legacy API - Deprecated)
- `:set_junction_surface(face, surface_type)` - Creates simple junction covering entire face
- `:get_junction_surface(face)` - Returns junction type (for backward compatibility)
- `:remove_junction_surface(face)` - Remove junction surface

**Note**: Legacy API is maintained for backward compatibility but new code should use Junction objects for position-aware junctions.

## Junction Class

### Constructor
- `junction.new(junction_type, pos_min, pos_max, face)` - Create a new junction
  - `junction_type`: string - e.g., "corridor", "hall", "staircase"
  - `pos_min`: vector - minimum corner (relative to module origin)
  - `pos_max`: vector - maximum corner (relative to module origin)
  - `face`: string - which face this junction is on

### Type Checking
- `junction.check(obj)` - Check if object is a Junction

### Methods
- `:get_size()` - Returns size vector of the junction area
- `:get_center()` - Returns center position of the junction
- `:get_area()` - Returns area in voxels
- `:can_connect_with(other)` - Check if this junction can connect with another

### Validation
- Positions must lie on the specified face (one coordinate constant)
- pos_min must be <= pos_max for all coordinates
- Throws error if positions define a volume instead of an area

### Schematics
- `:add_schematic(schematic, relative_pos, name)` - Add a schematic with position relative to min_pos
- `:get_schematic(identifier)` - Get a schematic entry by name or index (returns {schematic, relative_pos})
- `:get_all_schematics()` - Get all schematic entries
- `:remove_schematic(identifier)` - Remove a schematic

### Rotation
- `:rotate_y(angle_degrees)` - Rotate around Y axis (must be multiple of 90 degrees)

## Design Principles

Following Perfect City coding guidelines:
- Small, focused functions (under 30 lines)
- Clear naming conventions (snake_case)
- Comprehensive input validation
- Well-documented public API
- Separation of concerns (checks in separate file)
- Comprehensive unit tests
