# Pathpaver Module

## Overview

Pathpaver is a class for managing and storing point and path data within a citychunk. It provides collision detection and spatial querying capabilities for path-based map generation.

## Purpose

Pathpaver serves to:
- Store all points and paths for a citychunk
- Track points within the citychunk and its overgeneration margin
- Provide collision detection between paths
- Enable spatial queries for nearby points

## Data Structure

A pathpaver instance manages:
- `origin` - The citychunk origin position
- `margin_min` / `margin_max` - Bounds including overgeneration margin
- `paths` - Table of all paths in this citychunk
- `points` - Weak-keyed table of all points (from all paths)

### Overgeneration Margin

The pathpaver tracks points within:
- The citychunk itself (800x800 nodes by default)
- The overgeneration margin (160 nodes on each side by default)

This allows paths to extend beyond citychunk boundaries for seamless generation.

## Main Functions

### Creation

```lua
pathpaver.new(citychunk_origin)
```
Creates a new pathpaver for the specified citychunk origin.

### Type Checking

```lua
pathpaver.check(p)
```
Returns true if `p` is a pathpaver instance.

### Position Queries

```lua
pathpaver:pos_in_margin(pos)
```
Returns true if position is within citychunk + overgeneration margin.

```lua
pathpaver:pos_in_citychunk(pos)
```
Returns true if position is within citychunk boundaries (excluding margin).

### Storing Data

```lua
pathpaver:save_point(pnt)
```
Saves a point if it's within the margin area.

```lua
pathpaver:save_path(pth)
```
Saves a path and all its points. Only saves points within the margin area.

### Retrieving Data

```lua
pathpaver:path_points()
```
Returns all points that belong to saved paths.

## Usage Example

```lua
-- Create pathpaver for citychunk
local paver = pcmg.pathpaver.new(citychunk_origin)

-- Create and save a path
local start_point = pcmg.point.new(vector.new(100, 8, 100))
local end_point = pcmg.point.new(vector.new(200, 8, 200))
local path = pcmg.path.new(start_point, end_point)

-- Save path (and all its points)
paver:save_path(path)

-- Check if position is in valid area
local pos = vector.new(150, 8, 150)
if paver:pos_in_citychunk(pos) then
    -- Position is in main citychunk
end

-- Get all points from all saved paths
local all_points = paver:path_points()
for point, _ in pairs(all_points) do
    -- Process each point
end
```

## Memory Management

Pathpaver uses weak-keyed tables for points:

```lua
p.points = setmetatable({}, {__mode = "kv"})
```

This means:
- Points are kept alive by their paths, not by the pathpaver
- When a path is removed, its points can be garbage collected
- No manual cleanup required

## Use Cases

1. **Collision Detection**: Check if new paths intersect with existing paths
2. **Spatial Queries**: Find nearby points for connection
3. **Overgeneration**: Track points that extend into neighboring chunks
4. **Path Management**: Organize all paths in a citychunk

## Design Considerations

### Why Weak Tables?

Using weak tables for points prevents memory leaks:
- Paths own their points
- Pathpaver just indexes them
- When paths are removed, points are automatically cleaned up

### Margin System

The margin system allows:
- Paths to extend beyond citychunk boundaries
- Seamless generation across chunks
- Consistent overgeneration behavior

The margin is typically 2 mapchunks (160 nodes) to allow sufficient overlap for road generation.

## Related Modules

- **path.lua** - Defines the Path class used by pathpaver
- **point.lua** - Defines the Point class stored by pathpaver
- **megapathpaver.lua** - Manages multiple pathpavers for overgeneration
- **sizes.lua** - Defines margin sizes and citychunk dimensions
