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

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local pcmg = pcity_mapgen
local lru_cache = pcmg.lru_cache or dofile(mod_path.."/lru_cache.lua")

pcmg.tests = pcmg.tests or {}
pcmg.tests.lru_cache = {}
local tests = pcmg.tests.lru_cache

-- ============================================================
-- LRU CACHE CLASS UNIT TESTS
-- ============================================================

-- Tests that lru_cache.new creates a cache with default configuration
function tests.test_lru_cache_new_default()
    local cache = lru_cache.new()
    
    assert(cache ~= nil, "Cache should be created")
    assert(cache:size() == 0, "New cache should be empty")
    assert(cache._max_entries == 100, "Default max_entries should be 100")
end

-- Tests that lru_cache.new creates a cache with custom configuration
function tests.test_lru_cache_new_custom()
    local cache = lru_cache.new({max_entries = 50})
    
    assert(cache ~= nil, "Cache should be created")
    assert(cache:size() == 0, "New cache should be empty")
    assert(cache._max_entries == 50, "Custom max_entries should be 50")
end

-- Tests that set stores a value in the cache
function tests.test_lru_cache_set()
    local cache = lru_cache.new()
    
    cache:set("key1", "value1")
    assert(cache:size() == 1, "Cache should have 1 entry")
    assert(cache:has("key1"), "Cache should have key1")
end

-- Tests that get retrieves a value from the cache
function tests.test_lru_cache_get()
    local cache = lru_cache.new()
    
    cache:set("key1", "value1")
    local value = cache:get("key1")
    
    assert(value == "value1", "Retrieved value should match stored value")
end

-- Tests that get returns nil for non-existent keys
function tests.test_lru_cache_get_nonexistent()
    local cache = lru_cache.new()
    
    local value = cache:get("nonexistent")
    assert(value == nil, "Get should return nil for non-existent key")
end

-- Tests that has checks existence without retrieving value
function tests.test_lru_cache_has()
    local cache = lru_cache.new()
    
    assert(cache:has("key1") == false, "Cache should not have key1 initially")
    
    cache:set("key1", "value1")
    assert(cache:has("key1") == true, "Cache should have key1 after set")
end

-- Tests that size returns the correct number of entries
function tests.test_lru_cache_size()
    local cache = lru_cache.new()
    
    assert(cache:size() == 0, "Empty cache should have size 0")
    
    cache:set("key1", "value1")
    assert(cache:size() == 1, "Cache should have size 1 after one set")
    
    cache:set("key2", "value2")
    assert(cache:size() == 2, "Cache should have size 2 after two sets")
    
    cache:set("key3", "value3")
    assert(cache:size() == 3, "Cache should have size 3 after three sets")
end

-- Tests that clear removes all entries
function tests.test_lru_cache_clear()
    local cache = lru_cache.new()
    
    cache:set("key1", "value1")
    cache:set("key2", "value2")
    cache:set("key3", "value3")
    assert(cache:size() == 3, "Cache should have 3 entries")
    
    cache:clear()
    assert(cache:size() == 0, "Cache should be empty after clear")
    assert(cache:has("key1") == false, "key1 should not exist after clear")
    assert(cache:has("key2") == false, "key2 should not exist after clear")
    assert(cache:has("key3") == false, "key3 should not exist after clear")
end

-- Tests that cache evicts oldest entry when limit is exceeded
function tests.test_lru_cache_eviction()
    local cache = lru_cache.new({max_entries = 3})
    
    cache:set("key1", "value1")
    cache:set("key2", "value2")
    cache:set("key3", "value3")
    assert(cache:size() == 3, "Cache should have 3 entries")
    
    -- Add 4th entry, should evict key1 (oldest)
    cache:set("key4", "value4")
    assert(cache:size() == 3, "Cache should still have 3 entries after eviction")
    assert(cache:has("key1") == false, "key1 (oldest) should be evicted")
    assert(cache:has("key2") == true, "key2 should still exist")
    assert(cache:has("key3") == true, "key3 should still exist")
    assert(cache:has("key4") == true, "key4 should exist")
end

-- Tests that accessing a key moves it to the end (most recent)
function tests.test_lru_cache_access_order()
    local cache = lru_cache.new({max_entries = 3})
    
    cache:set("key1", "value1")
    cache:set("key2", "value2")
    cache:set("key3", "value3")
    
    -- Access key1 to make it most recent
    cache:get("key1")
    
    -- Add key4, should evict key2 (now oldest)
    cache:set("key4", "value4")
    
    assert(cache:has("key1") == true, "key1 should still exist (was accessed)")
    assert(cache:has("key2") == false, "key2 should be evicted (was oldest)")
    assert(cache:has("key3") == true, "key3 should still exist")
    assert(cache:has("key4") == true, "key4 should exist")
end

-- Tests that touch updates access order without retrieving value
function tests.test_lru_cache_touch()
    local cache = lru_cache.new({max_entries = 3})
    
    cache:set("key1", "value1")
    cache:set("key2", "value2")
    cache:set("key3", "value3")
    
    -- Touch key1 to make it most recent (without calling get)
    cache:touch("key1")
    
    -- Add key4, should evict key2 (now oldest)
    cache:set("key4", "value4")
    
    assert(cache:has("key1") == true, "key1 should still exist (was touched)")
    assert(cache:has("key2") == false, "key2 should be evicted (was oldest)")
    assert(cache:has("key3") == true, "key3 should still exist")
    assert(cache:has("key4") == true, "key4 should exist")
end

-- Tests that touch does nothing for non-existent keys
function tests.test_lru_cache_touch_nonexistent()
    local cache = lru_cache.new()
    
    cache:set("key1", "value1")
    local size_before = cache:size()
    
    -- Touch non-existent key should not affect cache
    cache:touch("nonexistent")
    
    assert(cache:size() == size_before, "Size should not change when touching non-existent key")
end

-- Tests that has does not update access order
function tests.test_lru_cache_has_no_update()
    local cache = lru_cache.new({max_entries = 3})
    
    cache:set("key1", "value1")
    cache:set("key2", "value2")
    cache:set("key3", "value3")
    
    -- Use has to check key1 (should not update access order)
    cache:has("key1")
    
    -- Add key4, should still evict key1 (oldest)
    cache:set("key4", "value4")
    
    assert(cache:has("key1") == false, "key1 should be evicted (has doesn't update access)")
    assert(cache:has("key2") == true, "key2 should still exist")
    assert(cache:has("key3") == true, "key3 should still exist")
    assert(cache:has("key4") == true, "key4 should exist")
end

-- Tests that on_evict callback is called when entry is evicted
function tests.test_lru_cache_eviction_callback()
    local evicted_keys = {}
    local evicted_values = {}
    
    local cache = lru_cache.new({
        max_entries = 3,
        on_evict = function(key, value)
            table.insert(evicted_keys, key)
            table.insert(evicted_values, value)
        end
    })
    
    cache:set("key1", "value1")
    cache:set("key2", "value2")
    cache:set("key3", "value3")
    
    -- Add key4, should trigger eviction callback for key1
    cache:set("key4", "value4")
    
    assert(#evicted_keys == 1, "Should have evicted 1 key")
    assert(evicted_keys[1] == "key1", "Evicted key should be key1")
    assert(evicted_values[1] == "value1", "Evicted value should be value1")
end

-- Tests that updating an existing key's value works correctly
function tests.test_lru_cache_update_value()
    local cache = lru_cache.new()
    
    cache:set("key1", "value1")
    assert(cache:get("key1") == "value1", "Initial value should be value1")
    
    -- Update value
    cache:set("key1", "updated_value")
    assert(cache:get("key1") == "updated_value", "Updated value should be updated_value")
    assert(cache:size() == 1, "Size should still be 1 after update")
end

-- Tests that cache works with different value types
function tests.test_lru_cache_various_value_types()
    local cache = lru_cache.new()
    
    -- String value
    cache:set("string_key", "string_value")
    assert(cache:get("string_key") == "string_value", "String value should work")
    
    -- Number value
    cache:set("number_key", 42)
    assert(cache:get("number_key") == 42, "Number value should work")
    
    -- Table value
    local table_value = {a = 1, b = 2}
    cache:set("table_key", table_value)
    local retrieved = cache:get("table_key")
    assert(retrieved == table_value, "Table value should work")
    assert(retrieved.a == 1, "Table content should be preserved")
    
    -- Boolean value
    cache:set("bool_key", true)
    assert(cache:get("bool_key") == true, "Boolean value should work")
end

-- Tests cache behavior with single entry limit
function tests.test_lru_cache_single_entry()
    local cache = lru_cache.new({max_entries = 1})
    
    cache:set("key1", "value1")
    assert(cache:has("key1") == true, "key1 should exist")
    
    cache:set("key2", "value2")
    assert(cache:has("key1") == false, "key1 should be evicted")
    assert(cache:has("key2") == true, "key2 should exist")
    assert(cache:size() == 1, "Cache should have exactly 1 entry")
end

-- Tests multiple evictions in one operation
function tests.test_lru_cache_multiple_evictions()
    local eviction_count = 0
    
    local cache = lru_cache.new({
        max_entries = 2,
        on_evict = function(key, value)
            eviction_count = eviction_count + 1
        end
    })
    
    cache:set("key1", "value1")
    cache:set("key2", "value2")
    
    -- Reduce max_entries artificially by setting many entries
    -- This simulates what would happen if max_entries was changed
    cache:set("key3", "value3")
    assert(eviction_count == 1, "Should have 1 eviction")
    
    cache:set("key4", "value4")
    assert(eviction_count == 2, "Should have 2 evictions total")
end

-- Tests that setting same key multiple times maintains correct size
function tests.test_lru_cache_set_same_key()
    local cache = lru_cache.new()
    
    cache:set("key1", "value1")
    cache:set("key1", "value2")
    cache:set("key1", "value3")
    
    assert(cache:size() == 1, "Size should be 1 when setting same key multiple times")
    assert(cache:get("key1") == "value3", "Value should be the latest set value")
end

-- Register all tests
local register_test = pcmg.register_test

register_test("LRU Cache class")
register_test("lru_cache.new (default)", tests.test_lru_cache_new_default)
register_test("lru_cache.new (custom)", tests.test_lru_cache_new_custom)
register_test("lru_cache:set", tests.test_lru_cache_set)
register_test("lru_cache:get", tests.test_lru_cache_get)
register_test("lru_cache:get (nonexistent)", tests.test_lru_cache_get_nonexistent)
register_test("lru_cache:has", tests.test_lru_cache_has)
register_test("lru_cache:size", tests.test_lru_cache_size)
register_test("lru_cache:clear", tests.test_lru_cache_clear)
register_test("lru_cache eviction", tests.test_lru_cache_eviction)
register_test("lru_cache access order", tests.test_lru_cache_access_order)
register_test("lru_cache:touch", tests.test_lru_cache_touch)
register_test("lru_cache:touch (nonexistent)", tests.test_lru_cache_touch_nonexistent)
register_test("lru_cache:has (no update)", tests.test_lru_cache_has_no_update)
register_test("lru_cache eviction callback", tests.test_lru_cache_eviction_callback)
register_test("lru_cache update value", tests.test_lru_cache_update_value)
register_test("lru_cache various types", tests.test_lru_cache_various_value_types)
register_test("lru_cache single entry", tests.test_lru_cache_single_entry)
register_test("lru_cache multiple evictions", tests.test_lru_cache_multiple_evictions)
register_test("lru_cache set same key", tests.test_lru_cache_set_same_key)
