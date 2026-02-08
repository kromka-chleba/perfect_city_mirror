# Metastore Module

## Overview

Metastore is a class for storing metadata associated with objects without modifying the objects directly. It uses weak-keyed tables to ensure proper garbage collection when objects are destroyed.

## Purpose

Metastore allows you to:
- Attach arbitrary metadata to any table object
- Store data without modifying the original object
- Automatically clean up metadata when objects are garbage collected
- Separate mutable and immutable (constant) metadata

## Design

### Weak Key Tables

Metastore uses tables with weak keys (`{__mode = "k"}`), which means:
- The metastore doesn't prevent objects from being garbage collected
- When an object has no other references, its metadata is automatically cleaned up
- Memory leaks are prevented

### Private Storage

Metadata is stored in private tables that are not directly accessible:
- `private` - stores mutable metadata
- `private_const` - stores immutable (constant) metadata

## Main Functions

### Creation

```lua
metastore.new()
```
Creates a new metastore instance.

### Type Checking

```lua
metastore.check(m)
```
Returns true if `m` is a metastore instance.

### Initialization

```lua
metastore:init_store(object)
```
Initializes storage for an object. Called automatically by `set`, `constant`, and `get`.

**Parameters:**
- `object` - Must be a table

**Error Handling:**
- Throws error if object is not a table

### Setting Values

```lua
metastore:set(object, key, value)
```
Sets a mutable value for the given object and key.

```lua
metastore:constant(object, key, value)
```
Sets an immutable value for the given object and key. Constants override mutable values.

### Getting Values

```lua
metastore:get(object, key)
```
Gets a value for the given object and key.

**Priority:**
1. Returns constant value if set
2. Returns mutable value if no constant exists
3. Returns nil if neither exists

## Usage Example

```lua
local store = pcmg.metastore.new()

local my_object = {}

-- Set mutable metadata
store:set(my_object, "color", "red")
store:set(my_object, "size", 10)

-- Set constant metadata
store:constant(my_object, "type", "building")

-- Retrieve values
local color = store:get(my_object, "color")  -- "red"
local type = store:get(my_object, "type")    -- "building"

-- Try to change constant (will be ignored in favor of constant)
store:set(my_object, "type", "road")
local type = store:get(my_object, "type")    -- still "building"

-- When my_object is garbage collected, its metadata is automatically cleaned up
```

## Best Practices

1. **Use for temporary metadata** - Ideal for associating temporary data with objects
2. **Use constants for immutable properties** - Mark unchangeable properties as constants
3. **Let garbage collection work** - Don't hold extra references to objects if you want cleanup
4. **Initialize explicitly if needed** - Though auto-initialized, you can call `init_store` manually

## Implementation Details

### Protection Against Direct Assignment

The metastore class uses `__newindex` to prevent direct assignment:

```lua
function metastore:__newindex(key, value)
    core.log("error", "Metastore: Don't set values directly, use 'metastore:set', etc. instead.")
end
```

This ensures all metadata goes through the proper API.

## Use Cases

- Associating canvas metadata with paths
- Storing temporary processing state
- Attaching debug information to objects
- Caching computed properties without modifying original objects
