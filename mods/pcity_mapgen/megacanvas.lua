--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

local mod_name = minetest.get_current_modname()
local mod_path = minetest.get_modpath("pcity_mapgen")
local math = math
local mlib = dofile(mod_path.."/mlib.lua")
local vector = vector
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units

local materials_by_id, materials_by_name = dofile(mod_path.."/canvas_ids.lua")

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

pcmg.megacanvas = {}
local megacanvas = pcmg.megacanvas

local function make_method(method)
    return function (self, ...)
        -- products are stuff returned by each function
        local products = {}
        local central_hash = pcmg.citychunk_hash(self.central.origin)
        products[central_hash] = method(self.central, ...)
        for _, neighbor in pairs(self.neighbors) do
            local hash = pcmg.citychunk_hash(neighbor.origin)
            if not self.cache.complete[hash] then
                products[hash] = method(neighbor, ...)
            end
        end
        local product_type
        for _, product in pairs(products) do
            if type(product) ~= nil then
                product_type = type(product)
                break
            end
        end
        -- For functions that return a boolean, the returned
        -- value is a logical OR of products from all canvases
        if product_type == "boolean" then
            local r
            for _, product in pairs(products) do
                r = product or r
            end
            return r
        end
        return products
    end
end

megacanvas.__index = function(object, key)
    if megacanvas[key] then
        object[key] = megacanvas[key]
        return megacanvas[key]
    elseif pcmg.canvas[key] then
        local method = make_method(pcmg.canvas[key])
        object[key] = method
        return method
    end
end

local blank_id = 1

--[[
    Cache for canvas data.
    Each table in 'cache' is keyed by citychunk hash.
    * 'citychunks': contains canvases
    * 'partially_complete': bool values, true means the citychunk
    was overgenerated from other citychunks, but was not itself fully generated
    * 'complete': bool values, true means the citychunk was both overgenerated
    and generated.
    * 'citychunk_meta': arbitrary user-provided data
--]]

pcmg.canvas_cache = {}
local canvas_cache = pcmg.canvas_cache

function canvas_cache.new()
    local cache = {}
    if not cache.citychunks then
        cache.citychunks = {}
    end
    if not cache.partially_complete then
        cache.partially_complete = {}
    end
    if not cache.complete then
        cache.complete = {}
    end
    if not cache.citychunk_meta then
        cache.citychunk_meta = {}
    end
    return cache
end

local function neighboring_canvases(citychunk_origin, cache)
    local neighbors = pcmg.citychunk_neighbors(citychunk_origin)
    local canvases = {}
    for _, origin in pairs(neighbors) do
        local hash = pcmg.citychunk_hash(origin)
        local canv = cache.citychunks[hash] or pcmg.canvas.new(origin)
        cache.citychunks[hash] = canv
        table.insert(canvases, canv)
    end
    return canvases
end

function megacanvas.new(citychunk_origin, cache)
    local megacanv = {}
    canvas_cache.new()
    megacanv.cache = cache
    megacanv.origin = vector.copy(citychunk_origin)
    megacanv.cursor = vector.new(0, 0, 0) -- abs pos only
    local hash = pcmg.citychunk_hash(citychunk_origin)
    megacanv.central = cache.citychunks[hash] or pcmg.canvas.new(citychunk_origin)
    cache.citychunks[hash] = megacanv.central
    megacanv.neighbors = neighboring_canvases(citychunk_origin, cache)
    return setmetatable(megacanv, megacanvas)
end

-- Sets cursors of the central citychunk and neighbors
-- to 'pos' which is absolute position
function megacanvas:set_all_cursors(pos)
    self.cursor = vector.copy(pos)
    self:set_cursor_absolute(pos)
end

-- Moves cursors of the central citychunk and neighbors
-- by 'vec' which is vector
function megacanvas:move_all_cursors(vec)
    local v = vector.round(vec) -- only integer moves allowed
    self:set_all_cursors(self.cursor + v)
end

-- Marks the central citychunk as complete in the citychunk cache
function megacanvas:mark_complete()
    local hash = pcmg.citychunk_hash(self.central.origin)
    self.cache.complete[hash] = true
    self.cache.partially_complete[hash] = nil
end

function megacanvas:mark_partially_complete()
    local hash = pcmg.citychunk_hash(self.central.origin)
    self.cache.partially_complete[hash] = true
end

local function neighbor_recurse(megacanv, generator_function, recursion_level)
    local central_hash = pcmg.citychunk_hash(megacanv.origin)
    if not megacanv.cache.partially_complete[central_hash] then
        generator_function(megacanv)
        megacanv:mark_partially_complete()
    end
    if recursion_level <= 0 then
        return
    end
    recursion_level = recursion_level - 1
    for _, neighbor in pairs(megacanv.neighbors) do
        local hash = pcmg.citychunk_hash(neighbor.origin)
        if not megacanv.cache.complete[hash] then
            local new_megacanv = pcmg.megacanvas.new(neighbor.origin, megacanv.cache)
            neighbor_recurse(new_megacanv, generator_function, recursion_level)
        end
    end
    megacanv:mark_complete()
end

--[[
    Generates a citychunk using the 'generator_function'
    which takes a megacanvas as its argument.
    'recursion_level' is a number of neighbor layers to process,
    for example 'recursion_level' = 1 means 'generator_function'
    will also be applied to neighbors of the central citychunk,
    'recursion_level' = 2 means also neighbors of the neighbors
    will be generated.
    'generator_function' MUST use reproducible randomness, otherwise
    overgeneration won't work.
--]]
function megacanvas:generate(generator_function, recursion_level)
    local rlevel = recursion_level or 1
    neighbor_recurse(self, generator_function, rlevel)
end
