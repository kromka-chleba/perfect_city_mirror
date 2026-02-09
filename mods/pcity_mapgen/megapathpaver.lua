--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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
local math = math
local vector = vector
local pcmg = pcity_mapgen
local units = dofile(mod_path.."/units.lua")

pcmg.megapathpaver = {}
local megapathpaver = pcmg.megapathpaver
megapathpaver.__index = megapathpaver
megapathpaver.cache = {}

-- Default maximum number of cached pathpavers
-- Can be overridden by setting pcity_pathpaver_cache_size in minetest.conf
local DEFAULT_MAX_CACHE_ENTRIES = 100

function megapathpaver.cache.new(c)
    local cache = c or {}
    if not cache.pathpavers then
        cache.pathpavers = {}
    end
    -- LRU tracking
    if not cache.access_order then
        cache.access_order = {}
    end
    -- Get cache size limit from settings or use default
    if not cache.max_entries then
        local setting = core.settings:get("pcity_pathpaver_cache_size")
        cache.max_entries = tonumber(setting) or DEFAULT_MAX_CACHE_ENTRIES
    end
    return cache
end

-- Remove the oldest entry from the cache
local function evict_oldest_entry(cache)
    if #cache.access_order == 0 then
        return
    end
    
    -- Remove the oldest hash (first in the list)
    local oldest_hash = table.remove(cache.access_order, 1)
    
    -- Clean up data associated with this hash
    cache.pathpavers[oldest_hash] = nil
end

-- Update access order for a hash (move to end if exists, add if new)
-- Note: Uses O(n) linear search for removal. This is acceptable for cache
-- sizes < 1000. For larger caches, consider using a doubly-linked list with
-- a hash table for O(1) updates.
local function update_access_order(cache, hash)
    -- Remove hash if it already exists in access_order
    for i, h in ipairs(cache.access_order) do
        if h == hash then
            table.remove(cache.access_order, i)
            break
        end
    end
    
    -- Add hash to the end (most recently used)
    table.insert(cache.access_order, hash)
    
    -- Evict oldest entries if cache is too large
    while #cache.access_order > cache.max_entries do
        evict_oldest_entry(cache)
    end
end

-- Public function to update cache access (exported for external use)
function megapathpaver.cache.update_access(cache, hash)
    update_access_order(cache, hash)
end

local function make_method(method)
    return function (self, ...)
        local products = {}
        local central_hash = pcmg.citychunk_hash(self.central.origin)
        products[central_hash] = method(self.central, ...)
        for _, neighbor in pairs(self.neighbors) do
            local hash = pcmg.citychunk_hash(neighbor.origin)
            products[hash] = method(neighbor, ...)
        end
        return products
    end
end

megapathpaver.__index = function(object, key)
    if megapathpaver[key] then
        object[key] = megapathpaver[key]
        return megapathpaver[key]
    elseif pcmg.pathpaver[key] then
        local method = make_method(pcmg.pathpaver[key])
        object[key] = method
        return method
    end
end

local function neighboring_pathpavers(citychunk_origin, cache)
    local neighbors = pcmg.citychunk_neighbors(citychunk_origin)
    local pathpavers = {}
    for _, origin in pairs(neighbors) do
        local hash = pcmg.citychunk_hash(origin)
        local pathpav = cache.pathpavers[hash] or pcmg.pathpaver.new(origin)
        cache.pathpavers[hash] = pathpav
        update_access_order(cache, hash)
        table.insert(pathpavers, pathpav)
    end
    return pathpavers
end

-- Rename to path store?
function megapathpaver.new(citychunk_origin, cache)
    local mpp = {}
    mpp.origin = vector.copy(citychunk_origin)
    mpp.cache = megapathpaver.cache.new(cache)
    local hash = pcmg.citychunk_hash(citychunk_origin)
    mpp.central = cache.pathpavers[hash] or pcmg.pathpaver.new(citychunk_origin)
    update_access_order(cache, hash)
    mpp.neighbors = neighboring_pathpavers(mpp.origin, cache)
    mpp.paths = mpp.central.paths
    return setmetatable(mpp, megapathpaver)
end

function megapathpaver:save_path(pth)
    self.central.paths[pth] = pth
    for _, pnt in pairs(pth:all_points()) do
        self:save_point(pnt)
    end
end

function megapathpaver.check(p)
    return getmetatable(p) == megapathpaver
end
