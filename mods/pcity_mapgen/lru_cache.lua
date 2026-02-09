--[[
    This is a part of "Perfect City".
    Copyright (C) 2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
    SPDX-License-Identifier: AGPL-3.0-or-later
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
    
    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

--[[
    ** LRU Cache Module **
    
    Generic LRU (Least Recently Used) cache implementation for Perfect City.
    
    This module provides a reusable LRU cache that automatically evicts
    the oldest entries when the cache exceeds its size limit. This prevents
    Out Of Memory (OOM) errors while keeping frequently accessed entries
    in memory.
    
    ** Usage **
    
    local lru = pcmg.lru_cache.new({
        max_entries = 100,
        on_evict = function(key, cache_data)
            -- Optional callback when an entry is evicted
            -- Use this to clean up additional data structures
        end
    })
    
    -- Store data in cache
    lru:set(key, value)
    
    -- Retrieve data from cache
    local value = lru:get(key)
    
    -- Check if key exists
    if lru:has(key) then ... end
    
    -- Mark a key as accessed (updates LRU order)
    lru:touch(key)
    
    ** Implementation **
    
    The LRU cache uses an array to track access order:
    - Oldest entries are at the beginning of the array (index 1)
    - Newest entries are at the end of the array
    - When an entry is accessed, it's moved to the end
    - When the cache is full, the oldest entry (index 1) is evicted
    
    Time Complexity:
    - get/set/touch: O(n) where n is cache size
    - has: O(1)
    
    Note: The O(n) linear search is acceptable for cache sizes < 1000.
    For larger caches, consider using a doubly-linked list with a hash
    table for O(1) updates.
--]]

local lru_cache = {}

-- Default maximum number of cache entries
local DEFAULT_MAX_ENTRIES = 100

-- ============================================================
-- LRU CACHE CLASS
-- ============================================================

-- Creates a new LRU cache instance. The cache automatically evicts
-- the oldest entries when it exceeds max_entries. Optional config
-- table accepts max_entries (default 100) and on_evict callback
-- function(key, cache_data) that is called when an entry is evicted.
function lru_cache.new(config)
    config = config or {}
    
    local cache = {
        -- Internal data storage (key -> value)
        _data = {},
        -- Access order tracking (array of keys, oldest first)
        _access_order = {},
        -- Maximum number of entries
        _max_entries = config.max_entries or DEFAULT_MAX_ENTRIES,
        -- Optional eviction callback
        _on_evict = config.on_evict,
    }
    
    setmetatable(cache, {__index = lru_cache})
    return cache
end

-- Removes the oldest entry from the cache.
local function evict_oldest(cache)
    if #cache._access_order == 0 then
        return
    end
    
    -- Remove the oldest key (first in the list)
    local oldest_key = table.remove(cache._access_order, 1)
    
    -- Get the data before removing it (for callback)
    local data = cache._data[oldest_key]
    
    -- Remove from data storage
    cache._data[oldest_key] = nil
    
    -- Call eviction callback if provided
    if cache._on_evict then
        cache._on_evict(oldest_key, data)
    end
end

-- Updates access order for a key (moves to end if exists, adds if new).
-- Note: Uses O(n) linear search for removal. This is acceptable for cache
-- sizes < 1000. For larger caches, consider using a doubly-linked list with
-- a hash table for O(1) updates.
local function update_access_order(cache, key)
    -- Remove key if it already exists in access_order
    for i, k in ipairs(cache._access_order) do
        if k == key then
            table.remove(cache._access_order, i)
            break
        end
    end
    
    -- Add key to the end (most recently used)
    table.insert(cache._access_order, key)
    
    -- Evict oldest entries if cache is too large
    while #cache._access_order > cache._max_entries do
        evict_oldest(cache)
    end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Stores a value in the cache. If the key already exists, it updates
-- the value and marks it as recently used.
function lru_cache:set(key, value)
    self._data[key] = value
    update_access_order(self, key)
end

-- Retrieves a value from the cache. Returns nil if not found.
-- Automatically updates the access order (marks as recently used).
function lru_cache:get(key)
    local value = self._data[key]
    if value ~= nil then
        update_access_order(self, key)
    end
    return value
end

-- Checks if a key exists in the cache without updating access order.
-- Returns true if key exists, false otherwise.
function lru_cache:has(key)
    return self._data[key] ~= nil
end

-- Marks a key as accessed (updates LRU order) without retrieving
-- the value. Does nothing if the key doesn't exist.
function lru_cache:touch(key)
    if self._data[key] ~= nil then
        update_access_order(self, key)
    end
end

-- Returns the current number of entries in the cache.
function lru_cache:size()
    return #self._access_order
end

-- Clears all entries from the cache.
function lru_cache:clear()
    self._data = {}
    self._access_order = {}
end

return lru_cache
