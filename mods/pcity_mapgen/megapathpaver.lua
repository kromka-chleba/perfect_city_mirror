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

--- Create a new megapathpaver cache
-- Initializes an LRU cache for pathpavers if not already present.
-- @param c table Optional existing cache to initialize
-- @return table Initialized cache with pathpavers and lru tables
function megapathpaver.cache.new(c)
    local cache = c or {}
    if not cache.pathpavers then
        cache.pathpavers = {}
    end
    
    -- Initialize LRU cache if not already present
    if not cache.lru then
        -- Get cache size limit from settings or use default
        local setting = core.settings:get("pcity_pathpaver_cache_size")
        local max_entries = tonumber(setting) or DEFAULT_MAX_CACHE_ENTRIES
        
        -- Create LRU cache with eviction callback
        cache.lru = pcmg.lru_cache.new({
            max_entries = max_entries,
            on_evict = function(hash, data)
                -- Clean up data associated with this hash
                cache.pathpavers[hash] = nil
            end
        })
    end
    
    return cache
end

--- Update cache access for a given hash
-- Public function to update cache access (exported for external use).
-- @param cache table The cache object
-- @param hash string Hash key to mark as recently used
function megapathpaver.cache.update_access(cache, hash)
    if cache.lru then
        cache.lru:touch(hash)
    end
end

--- Create a method wrapper that calls a pathpaver method on all neighbors
-- @param method function The pathpaver method to wrap
-- @return function Wrapper function that applies method to central and all neighbor pathpavers
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

--- Get or create pathpavers for all neighboring citychunks
-- @param citychunk_origin vector Origin position of the citychunk
-- @param cache table Cache object containing pathpavers and LRU cache
-- @return table Array of pathpaver objects for neighboring citychunks
local function neighboring_pathpavers(citychunk_origin, cache)
    local neighbors = pcmg.citychunk_neighbors(citychunk_origin)
    local pathpavers = {}
    for _, origin in pairs(neighbors) do
        local hash = pcmg.citychunk_hash(origin)
        local pathpav = cache.pathpavers[hash] or pcmg.pathpaver.new(origin)
        cache.pathpavers[hash] = pathpav
        cache.lru:touch(hash)
        table.insert(pathpavers, pathpav)
    end
    return pathpavers
end

--- Create a new megapathpaver
-- Manages pathpavers for a citychunk and its neighbors.
-- @param citychunk_origin vector Origin position of the citychunk
-- @param cache table Cache object for storing pathpavers
-- @return table Megapathpaver object
function megapathpaver.new(citychunk_origin, cache)
    local mpp = {}
    mpp.origin = vector.copy(citychunk_origin)
    mpp.cache = megapathpaver.cache.new(cache)
    local hash = pcmg.citychunk_hash(citychunk_origin)
    mpp.central = cache.pathpavers[hash] or pcmg.pathpaver.new(citychunk_origin)
    cache.lru:touch(hash)
    mpp.neighbors = neighboring_pathpavers(mpp.origin, cache)
    mpp.paths = mpp.central.paths
    return setmetatable(mpp, megapathpaver)
end

--- Save a path to the central pathpaver and all its points
-- @param pth table Path object to save
function megapathpaver:save_path(pth)
    self.central.paths[pth] = pth
    for _, pnt in pairs(pth:all_points()) do
        self:save_point(pnt)
    end
end

--- Check if an object is a megapathpaver
-- @param p table Object to check
-- @return boolean True if object is a megapathpaver
function megapathpaver.check(p)
    return getmetatable(p) == megapathpaver
end
