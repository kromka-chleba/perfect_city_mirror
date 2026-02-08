# Utils Module

## Overview

The utils module provides utility functions for coordinate system conversions and various helper functions used throughout the mapgen system.

## Purpose

This module handles:
- Coordinate conversions between node, mapchunk, and citychunk spaces
- Hashing functions for position-based random generation
- Vector operations and extensions
- Random number generation utilities
- Debugging helpers

## Coordinate Systems

Perfect City uses three coordinate systems:

1. **Node coordinates** - Individual block positions in the world
2. **Mapchunk coordinates** - Minetest's native chunk system (typically 80x80x80 nodes)
3. **Citychunk coordinates** - Perfect City's larger chunks (typically 10x10 mapchunks)

## Main Functions

### Mapchunk Coordinate Functions

```lua
pcmg.mapchunk_coords(pos)
```
Returns mapchunk coordinates for a given node position.

```lua
pcmg.mapchunk_origin(pos)
```
Returns the origin point (minimum corner) of a mapchunk as an absolute node position.

```lua
pcmg.mapchunk_terminus(pos)
```
Returns the terminus point (maximum corner) of a mapchunk as an absolute node position.

```lua
pcmg.mapchunk_hash(pos)
```
Returns a hash value for the mapchunk containing the given position. Useful for deterministic random generation.

### Citychunk Coordinate Functions

```lua
pcmg.citychunk_coords(pos)
```
Returns citychunk coordinates for a given node position.

```lua
pcmg.citychunk_origin(pos)
```
Returns the origin point of a citychunk as an absolute node position.

```lua
pcmg.citychunk_terminus(pos)
```
Returns the terminus point of a citychunk as an absolute node position.

```lua
pcmg.citychunk_hash(pos)
```
Returns a hash value for the citychunk containing the given position.

```lua
pcmg.citychunk_neighbors(pos)
```
Returns the citychunk origins of all 8 neighboring citychunks.

### Random Number Generation

```lua
pcmg.set_randomseed(citychunk_origin)
```
Sets a deterministic random seed based on the citychunk position and mapgen seed. This ensures the same citychunk always generates the same random values.

```lua
pcmg.random_pos_in_citychunk(citychunk_origin)
```
Returns a random node position within the specified citychunk.

## Vector Extensions

### vector.split(v, nr)

Splits a vector into `nr` smaller vectors of equal length.

**Example:**
```lua
local segments = vector.split(vector.new(100, 0, 0), 4)
-- Returns 4 vectors: {(25,0,0), (25,0,0), (25,0,0), (25,0,0)}
```

### vector.modf(v)

Returns integer and fractional parts of a vector.

**Returns:** Two vectors - integer part and fractional part

### vector.sign(v)

Returns a vector with the sign of each component (-1, 0, or 1).

### vector.ceil(v)

Returns a vector with ceiling applied to each component.

### vector.abs(v)

Returns a vector with absolute value of each component.

### vector.create(f, ...)

Creates a vector by calling function `f` for each component.

**Example:**
```lua
local random_vec = vector.create(math.random, 1, 10)
-- Returns vector with random x, y, z between 1 and 10
```

### vector.random(...)

Convenience function for creating random vectors.

### vector.average(...)

Calculates the average of multiple vectors.

## Utility Functions

### table.better_length(t)

Returns the count of elements in a table (works with non-sequential keys).

### shallow_dump(obj)

Dumps information about an object as a formatted string. Safe for objects with circular references.

**Features:**
- Shows type of object
- Lists keys and value types (not values themselves)
- Shows metatable information
- Never follows references (prevents infinite loops)

**Use case:** Debugging complex objects without risk of crashes.

## Constants

The module uses these mapgen-derived constants:

- `blocks_per_chunk` - Number of blocks per mapchunk (default: 5)
- `mapchunk_size` - Size of mapchunk in nodes (default: 80)
- `mapchunk_offset` - Offset for mapchunk positioning (default: -32)

## Usage Examples

### Coordinate Conversion

```lua
-- Get citychunk origin for a node position
local node_pos = vector.new(1234, 8, 5678)
local citychunk_origin = pcmg.citychunk_origin(node_pos)

-- Get all neighbors
local neighbors = pcmg.citychunk_neighbors(node_pos)
for _, neighbor_origin in ipairs(neighbors) do
    -- Process each neighbor
end
```

### Deterministic Random Generation

```lua
-- Always generates same result for same citychunk
pcmg.set_randomseed(citychunk_origin)
local random_value = math.random(1, 100)
```

### Vector Operations

```lua
-- Split path into segments
local path_vector = vector.new(800, 0, 0)
local segments = vector.split(path_vector, 10)

-- Get random position in chunk
local pos = pcmg.random_pos_in_citychunk(citychunk_origin)
```

## Related Modules

- **sizes.lua** - Defines the size constants used by coordinate functions
- **mapgen.lua** - Uses these utilities for world generation
