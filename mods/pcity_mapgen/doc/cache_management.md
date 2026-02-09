# Cache Management in PCity Mapgen

## Overview

The Perfect City mapgen uses caching to avoid regenerating citychunks that have already been processed. This improves performance but can lead to unbounded memory growth (OOM - Out Of Memory errors) if caches grow indefinitely.

To prevent OOM issues, both **megacanvas** and **megapathpaver** caches implement an **LRU (Least Recently Used)** eviction policy with configurable size limits.

## Problem

Previously, the cache would store generated citychunks indefinitely:
- Canvas objects (2D grid data for roads, buildings, etc.)
- Pathpaver objects (path and point data)

As players explore more of the world, more citychunks are generated and cached. Without expiration, this could eventually consume all available memory.

## Solution: LRU Cache

### What is LRU?

LRU (Least Recently Used) is a cache eviction policy that removes the oldest/least recently accessed entries when the cache reaches its size limit.

### How It Works

1. **Access Tracking**: Every time a citychunk is accessed (read or written), it's marked as "recently used"
2. **Ordering**: The cache maintains an ordered list with oldest entries first
3. **Eviction**: When the cache exceeds `max_entries`, the oldest entries are removed
4. **Smart Cleanup**: When an entry is evicted, ALL associated data is removed (canvas/pathpaver, completion status, metadata)

### Benefits

- **Bounded Memory**: Memory usage stays under control
- **Performance**: Frequently used citychunks stay in cache (near player activity)
- **Automatic**: No manual cache management needed
- **Fair**: Distant, unused citychunks are removed first

## Configuration

Cache size limits can be configured in `minetest.conf`:

### Canvas Cache Size

```
# Maximum number of canvas objects to cache (default: 100)
pcity_canvas_cache_size = 100
```

### Pathpaver Cache Size

```
# Maximum number of pathpaver objects to cache (default: 100)
pcity_pathpaver_cache_size = 100
```

### Choosing Cache Size

**Factors to consider:**

- **Available RAM**: More RAM → larger cache possible
- **Player behavior**: More exploration → benefit from larger cache
- **World size**: Larger worlds → more citychunks generated
- **Server vs. Client**: Dedicated servers may have more RAM

**Recommendations:**

- **Low RAM (< 4GB)**: 50-100 entries
- **Medium RAM (4-8GB)**: 100-200 entries
- **High RAM (> 8GB)**: 200-500 entries
- **Dedicated Server**: 500-1000 entries

**Memory estimation:**

Each cached citychunk consumes approximately:
- Canvas: ~50-100 KB (depends on citychunk size)
- Pathpaver: ~10-50 KB (depends on path complexity)

Example: 100 citychunks × 100 KB = ~10 MB

## Implementation Details

### Data Structures

Each cache maintains:

```lua
cache = {
    -- Main data
    citychunks = {},          -- [hash] = canvas object
    pathpavers = {},          -- [hash] = pathpaver object
    partially_complete = {},  -- [hash] = bool
    complete = {},            -- [hash] = bool
    citychunk_meta = {},      -- [hash] = metadata
    
    -- LRU tracking
    access_order = {},        -- Array of hashes (oldest first)
    max_entries = 100,        -- Size limit
}
```

### Access Tracking

Citychunks are marked as accessed when:
- A new canvas/pathpaver is created
- An existing canvas/pathpaver is retrieved
- A citychunk is marked complete or partially complete
- A neighbor canvas/pathpaver is loaded

### Eviction Process

When cache exceeds limit:

1. Remove oldest hash from `access_order` array
2. Delete all associated data:
   - Canvas/pathpaver object
   - Completion status flags
   - User metadata
3. Repeat until cache size is within limit

### Access Update

When a citychunk is accessed:

1. Remove hash from current position in `access_order` (if present)
2. Add hash to end of `access_order` (most recent)
3. Check if cache exceeds limit and evict if needed

## Code Examples

### Using Default Cache Size

```lua
-- Creates cache with default size (100 entries)
local canvas_cache = pcmg.megacanvas.cache.new()
local pathpaver_cache = pcmg.megapathpaver.cache.new()
```

### Custom Cache Size

```lua
-- Create cache with custom size
local canvas_cache = pcmg.megacanvas.cache.new({
    max_entries = 200
})
```

### Manual Access Tracking (Advanced)

Normally, access tracking is automatic. However, if you need to manually update access:

```lua
-- Update access for a specific citychunk
local hash = pcmg.citychunk_hash(citychunk_origin)
pcmg.megacanvas.cache.update_access(canvas_cache, hash)
pcmg.megapathpaver.cache.update_access(pathpaver_cache, hash)
```

## Performance Characteristics

### Time Complexity

- **Cache hit**: O(n) where n is cache size (for access tracking)
- **Cache miss**: O(1) for creation + O(n) for access tracking
- **Eviction**: O(1) per evicted entry

### Space Complexity

- **Per citychunk**: O(1) for tracking data
- **Total cache**: O(max_entries)

### Optimization Notes

The current implementation uses a simple array for `access_order`, which requires O(n) search time to remove an existing hash. This is acceptable for cache sizes < 1000.

For larger caches, consider:
- Using a doubly-linked list with hash table for O(1) updates
- Implementing approximate LRU with batched updates
- Using a second-chance FIFO algorithm

## Testing

### Manual Testing

1. Set a small cache size (e.g., 10)
2. Explore the world to generate > 10 citychunks
3. Check memory usage doesn't grow unbounded
4. Return to previously generated areas - should regenerate if evicted

### Monitoring Cache Behavior

Add debug logging to track cache statistics:

```lua
-- At eviction time
core.log("info", string.format("Cache evicted: %s (size: %d/%d)", 
    oldest_hash, #cache.access_order, cache.max_entries))
```

## Migration Notes

### Backward Compatibility

The cache changes are **fully backward compatible**:

- Existing worlds work without changes
- No configuration required (uses sensible defaults)
- Old cache objects are automatically upgraded
- Performance impact is minimal

### Upgrading

No special steps needed:
1. Update the mod files
2. Optionally set cache size in `minetest.conf`
3. Restart the server/game

## Troubleshooting

### Memory Still Growing

If memory continues to grow:

1. **Check cache size**: Verify settings are being applied
2. **Monitor other mods**: Other mods may have memory leaks
3. **Reduce cache size**: Try smaller values
4. **Check for memory leaks**: Use Lua profiler

### Performance Degradation

If performance decreases:

1. **Increase cache size**: More entries = fewer regenerations
2. **Check access patterns**: Are citychunks being accessed efficiently?
3. **Profile the code**: Use Lua profiler to find bottlenecks

### Citychunks Regenerating Too Often

If citychunks regenerate when revisiting areas:

1. **Increase cache size**: Larger cache holds more citychunks
2. **Check player movement**: Rapid exploration evicts more entries
3. **Consider game design**: Maybe regeneration is acceptable?

## Future Improvements

Potential enhancements:

1. **Persistent cache**: Save completed citychunks to disk
2. **Smarter eviction**: Use 2Q or ARC algorithms
3. **Priority-based**: Keep important citychunks (e.g., spawn area)
4. **Statistics**: Track hit/miss rates, eviction counts
5. **Dynamic sizing**: Adjust cache size based on available memory

## Related Documentation

- [megacanvas.md](megacanvas.md) - Megacanvas system
- [pathpaver.md](pathpaver.md) - Pathpaver system
- [README.md](README.md) - Main mapgen documentation

## References

- [LRU Cache - Wikipedia](https://en.wikipedia.org/wiki/Cache_replacement_policies#Least_recently_used_(LRU))
- [Lua Performance Tips](https://www.lua.org/gems/sample.pdf)
- [Minetest Modding Book](https://rubenwardy.com/minetest_modding_book/)
