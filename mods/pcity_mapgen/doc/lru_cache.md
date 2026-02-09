# LRU Cache Module

## Overview

The `lru_cache.lua` module provides a generic, reusable LRU (Least Recently Used) cache implementation for Perfect City. This module is used by both `megacanvas` and `megapathpaver` to manage memory efficiently.

## Purpose

The LRU cache prevents Out Of Memory (OOM) errors by:
- Automatically evicting the oldest entries when the cache reaches its size limit
- Keeping frequently accessed entries in memory
- Providing a simple, generic API that can be used by any module

## API Reference

### Creating a Cache

```lua
local lru = pcmg.lru_cache.new(config)
```

**Parameters:**
- `config` (optional): Configuration table with:
  - `max_entries` (number): Maximum number of entries (default: 100)
  - `on_evict` (function): Callback function `(key, data)` called when an entry is evicted

**Returns:**
- A new LRU cache instance

**Example:**
```lua
local lru = pcmg.lru_cache.new({
    max_entries = 200,
    on_evict = function(key, data)
        -- Cleanup associated resources
        print("Evicting:", key)
    end
})
```

### Storing Data

```lua
lru:set(key, value)
```

Stores a value in the cache and marks it as recently used.

**Parameters:**
- `key`: Cache key (any hashable value)
- `value`: Value to store

**Example:**
```lua
lru:set("chunk_0_0", canvas_object)
```

### Retrieving Data

```lua
local value = lru:get(key)
```

Retrieves a value from the cache and automatically updates the LRU order (marks as recently used).

**Parameters:**
- `key`: Cache key

**Returns:**
- The cached value, or `nil` if not found

**Example:**
```lua
local canvas = lru:get("chunk_0_0")
if canvas then
    -- Use the canvas
end
```

### Checking Existence

```lua
local exists = lru:has(key)
```

Check if a key exists in the cache **without** updating the access order.

**Parameters:**
- `key`: Cache key

**Returns:**
- `true` if key exists, `false` otherwise

**Example:**
```lua
if lru:has("chunk_0_0") then
    print("Chunk is cached")
end
```

### Marking as Accessed

```lua
lru:touch(key)
```

Marks a key as accessed (updates LRU order) without retrieving the value. Useful when you've accessed the data through another means but still want to update the LRU order.

**Parameters:**
- `key`: Cache key

**Example:**
```lua
-- Access data directly
local canvas = cache.citychunks[hash]
-- Update LRU order
cache.lru:touch(hash)
```

### Getting Cache Size

```lua
local count = lru:size()
```

Returns the current number of entries in the cache.

**Returns:**
- Number of cached entries

**Example:**
```lua
print("Cache contains", lru:size(), "entries")
```

### Clearing the Cache

```lua
lru:clear()
```

Removes all entries from the cache.

**Example:**
```lua
lru:clear()
print("Cache cleared")
```

## Implementation Details

### Data Structure

The LRU cache internally maintains:

```lua
{
    _data = {},            -- Key-value storage
    _access_order = {},    -- Array of keys (oldest first)
    _max_entries = 100,    -- Size limit
    _on_evict = nil,       -- Optional callback
}
```

### LRU Algorithm

1. **Set/Get**: When a key is accessed, it's moved to the end of `_access_order`
2. **Eviction**: When cache exceeds `_max_entries`, the first key in `_access_order` is removed
3. **Callback**: The `on_evict` callback is called before removing data

### Time Complexity

- `set(key, value)`: O(n) where n is cache size
- `get(key)`: O(n) where n is cache size  
- `has(key)`: O(1)
- `touch(key)`: O(n) where n is cache size
- `size()`: O(1)
- `clear()`: O(1)

**Note:** The O(n) operations use a linear search through `_access_order`. This is acceptable for cache sizes < 1000. For larger caches, consider using a doubly-linked list with a hash table for O(1) updates.

## Usage Examples

### Simple Cache

```lua
-- Create a simple cache
local cache = pcmg.lru_cache.new({max_entries = 10})

-- Store some data
for i = 1, 15 do
    cache:set("key" .. i, {data = i})
end

-- Cache now has 10 entries (oldest 5 were evicted)
print("Size:", cache:size())  -- Output: Size: 10

-- Keys 6-15 are in cache, 1-5 were evicted
print(cache:get("key1"))   -- nil (evicted)
print(cache:get("key10"))  -- {data = 10}
```

### Cache with Cleanup

```lua
-- Create cache with eviction callback
local resource_cache = pcmg.lru_cache.new({
    max_entries = 50,
    on_evict = function(key, resource)
        -- Clean up the resource
        if resource.cleanup then
            resource:cleanup()
        end
        print("Evicted resource:", key)
    end
})

-- Store resources
resource_cache:set("texture1", texture_object)
resource_cache:set("model1", model_object)

-- Resources are automatically cleaned up when evicted
```

### Access Pattern Optimization

```lua
-- Frequently accessed items stay in cache
local cache = pcmg.lru_cache.new({max_entries = 3})

cache:set("a", 1)
cache:set("b", 2)
cache:set("c", 3)
-- Cache: [a, b, c] (oldest to newest)

cache:get("a")  -- Access 'a'
-- Cache: [b, c, a] (a moved to end)

cache:set("d", 4)  -- Add new entry, 'b' evicted
-- Cache: [c, a, d]

print(cache:has("b"))  -- false (evicted)
print(cache:has("a"))  -- true (still in cache)
```

## Integration with Megacanvas/Megapathpaver

Both `megacanvas` and `megapathpaver` use the LRU cache module:

```lua
-- megacanvas.cache.new creates an LRU cache
function megacanvas.cache.new(c)
    local cache = c or {}
    -- ... initialize data structures ...
    
    cache.lru = pcmg.lru_cache.new({
        max_entries = max_entries,
        on_evict = function(hash, data)
            -- Clean up associated data
            cache.citychunks[hash] = nil
            cache.complete[hash] = nil
            -- ...
        end
    })
    
    return cache
end
```

## Performance Considerations

### When to Use

✅ **Good for:**
- Caches with < 1000 entries
- Scenarios where simplicity is important
- When eviction callbacks are needed

❌ **Not ideal for:**
- Very large caches (> 1000 entries)
- Extremely high-frequency access patterns
- Cases requiring O(1) guaranteed performance

### Optimization Tips

1. **Choose appropriate cache size**: Larger isn't always better. Find the sweet spot for your use case.
2. **Use `touch()` sparingly**: Only when necessary to avoid O(n) overhead
3. **Consider `has()` first**: If you just need to check existence, use `has()` (O(1))
4. **Batch operations**: If possible, batch cache operations to reduce overhead

## Testing

To test the LRU cache module:

```lua
-- Test basic functionality
local lru = pcmg.lru_cache.new({max_entries = 3})

-- Add entries up to limit
lru:set(1, "a")
lru:set(2, "b")
lru:set(3, "c")
assert(lru:size() == 3, "Size should be 3")

-- Add one more, oldest should be evicted
lru:set(4, "d")
assert(lru:size() == 3, "Size should still be 3")
assert(not lru:has(1), "Oldest entry should be evicted")
assert(lru:has(4), "Newest entry should exist")

-- Access middle entry, then add another
lru:get(2)  -- Touch entry 2
lru:set(5, "e")
assert(lru:has(2), "Accessed entry should remain")
assert(not lru:has(3), "Entry 3 should be evicted")
```

## Related Documentation

- [cache_management.md](cache_management.md) - Overview of cache management in PCity Mapgen
- [megacanvas.md](megacanvas.md) - Megacanvas system that uses LRU cache
- [pathpaver.md](pathpaver.md) - Pathpaver system that uses LRU cache

## Future Improvements

Potential enhancements:

1. **O(1) Implementation**: Use doubly-linked list with hash table for O(1) operations
2. **TTL Support**: Add time-to-live expiration
3. **Statistics**: Track hits, misses, eviction counts
4. **Multi-tier Cache**: Implement a two-level cache (L1/L2)
5. **Adaptive Sizing**: Dynamically adjust cache size based on hit rate

## References

- [LRU Cache - Wikipedia](https://en.wikipedia.org/wiki/Cache_replacement_policies#Least_recently_used_(LRU))
- [Lua Performance Tips](http://www.lua.org/gems/sample.pdf)
