# Path Utils Module

## Overview

The path_utils module provides utilities for 2D spatial-vector geometry in the XZ plane and path-related geometric calculations. All operations ignore the Y coordinate, focusing on horizontal plane geometry.

## Purpose

This module handles:
- 2D vector operations (XZ plane only)
- Angle calculations between vectors
- Distance calculations from points to line segments
- Parallel/perpendicular checks for segments
- Geometric queries for path generation

## Key Concept: XZ Plane

All operations work in the **XZ plane** (horizontal plane):
- X and Z coordinates are used
- Y coordinate is ignored or set to 0
- Useful for road and path layout (which are primarily 2D)

## Vector Operations

### Flattening and Length

```lua
path_utils.xz_length(v)
```
Returns the length of vector in XZ plane (ignoring Y).

```lua
path_utils.xz_length_sq(v)
```
Returns the squared length in XZ plane (faster, avoids sqrt).

```lua
path_utils.xz_dot(v1, v2)
```
Returns the dot product of two vectors in XZ plane.

## Angle Calculations

### Angle Between Directions

```lua
path_utils.angle_between_2d(dir1, dir2)
```
Calculates the angle (in radians) between two direction vectors in the XZ plane.

**Returns:** Angle in radians (0 to π)

**Example:**
```lua
local dir1 = vector.new(1, 0, 0)   -- East
local dir2 = vector.new(0, 0, 1)   -- North
local angle = path_utils.angle_between_2d(dir1, dir2)  -- π/2 (90 degrees)
```

## Parallel Checks

### Segment Parallelism

```lua
path_utils.segments_are_parallel(seg1_start, seg1_end, seg2_start, seg2_end, threshold)
```
Checks if two line segments are parallel within a threshold angle.

**Parameters:**
- `seg1_start`, `seg1_end` - Endpoints of first segment
- `seg2_start`, `seg2_end` - Endpoints of second segment
- `threshold` - Angle threshold in radians (default: π/6 or 30 degrees)

**Returns:** `true` if segments are parallel (angle < threshold or > π - threshold)

**Example:**
```lua
-- Check if two road segments are parallel
local seg1_start = vector.new(0, 8, 0)
local seg1_end = vector.new(100, 8, 0)
local seg2_start = vector.new(0, 8, 10)
local seg2_end = vector.new(100, 8, 10)

if path_utils.segments_are_parallel(seg1_start, seg1_end, seg2_start, seg2_end) then
    -- Segments are parallel (both going east)
end
```

### Direction to Segment Parallelism

```lua
path_utils.direction_parallel_to_segment(direction, seg_start, seg_end, threshold)
```
Checks if a direction vector is parallel to a line segment.

**Parameters:**
- `direction` - Direction vector to check
- `seg_start`, `seg_end` - Endpoints of segment
- `threshold` - Angle threshold in radians (default: π/6)

**Returns:** `true` if direction is parallel to segment

## Distance Calculations

### Point to Segment Distance

```lua
path_utils.point_to_segment_distance(pos, seg_start, seg_end)
```
Calculates the shortest distance from a point to a line segment in 2D (XZ plane).

**Returns:** Two values:
1. `distance` - Shortest distance to the segment
2. `closest_point` - The closest point on the segment

**Example:**
```lua
local point = vector.new(50, 8, 50)
local seg_start = vector.new(0, 8, 0)
local seg_end = vector.new(100, 8, 0)

local dist, closest = path_utils.point_to_segment_distance(point, seg_start, seg_end)
-- dist = 50 (perpendicular distance)
-- closest = (50, 0, 0) approximately
```

**Algorithm:**
1. Projects point onto infinite line through segment
2. Clamps projection to segment endpoints
3. Returns distance to clamped point

## Use Cases

### Road Layout

```lua
-- Check if new road is parallel to existing road
local existing_start = road.start.pos
local existing_end = road.finish.pos
local new_start = new_point.pos
local new_end = new_endpoint.pos

if path_utils.segments_are_parallel(existing_start, existing_end, 
                                     new_start, new_end, math.pi / 12) then
    -- Roads are parallel, adjust spacing
end
```

### Collision Detection

```lua
-- Check if point is too close to a road segment
local min_distance = 20  -- nodes

for _, road in pairs(existing_roads) do
    local dist = path_utils.point_to_segment_distance(
        new_point.pos, 
        road.start.pos, 
        road.finish.pos
    )
    
    if dist < min_distance then
        -- Too close, move point or reject
    end
end
```

### Grid Alignment

```lua
-- Check if direction aligns with grid axes
local north = vector.new(0, 0, 1)
local east = vector.new(1, 0, 0)

if path_utils.direction_parallel_to_segment(my_direction, 
                                             vector.zero(), north) then
    -- Direction is roughly north-south
elseif path_utils.direction_parallel_to_segment(my_direction, 
                                                  vector.zero(), east) then
    -- Direction is roughly east-west
end
```

## Implementation Notes

### Threshold Angles

Default threshold is π/6 (30 degrees):
- Conservative enough to avoid false positives
- Loose enough to handle minor variations
- Can be adjusted for stricter/looser checks

### Numerical Stability

The module includes numerical stability checks:
- Checks for near-zero lengths (`< 1e-6`)
- Clamps dot products to valid range `[-1, 1]`
- Uses squared lengths where possible to avoid sqrt

### XZ-Only Operations

All operations flatten vectors to XZ plane:
```lua
local function vector_flatten_xz(v)
    return vector.new(v.x, 0, v.z)
end
```

This ensures consistent 2D behavior regardless of Y coordinate.

## Performance Considerations

- `xz_length_sq` is faster than `xz_length` (no square root)
- Use when comparing distances (squared comparison is valid)
- Segment distance calculation is relatively expensive (use sparingly in loops)

## Related Modules

- **path.lua** - Uses these utilities for path operations
- **roads_layout.lua** - Uses for road placement and alignment
- **point.lua** - Points are positioned using these geometric calculations
