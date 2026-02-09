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

local materials_by_id, materials_by_name = dofile(mod_path.."/canvas_ids.lua")

-- Sizes of map division units
local node = units.sizes.node
local mapchunk = units.sizes.mapchunk
local citychunk = units.sizes.citychunk

-------------------------------------------------------------------------
-- Megacanvas 3D
-------------------------------------------------------------------------

--[[
    ** Overview **
    Megacanvas3D is a class for managing overgeneration across
    multiple canvas3d objects. It has a cursor pointing to an
    absolute position and replicates that cursor setting for
    each canvas3d it manages (every canvas points to the same
    absolute position). By default a megacanvas3d manages the
    central chunk and all its 26 neighbors (including vertical neighbors).
    Overgeneration is provided by calling canvas3d methods for each
    canvas3d at the absolute cursor position. Writing to each canvas
    happens only if cursor of each canvas is in the overgeneration
    margin area (see canvas3d.lua for details). Megacanvas3D also
    provides smart caching of partially generated and already
    fully generated canvases.
--]]

pcmg.megacanvas3d = {}
local megacanvas3d = pcmg.megacanvas3d

-- Allows calling methods of the Canvas3D class from Megacanvas3D.
-- Calls the method for the central citychunk and all neighbors,
-- returns a table with returned values of each citychunk canvas3d. When
-- the returned value is a boolean, it returns a logical OR of the
-- returned values.
local function make_method(method)
    return function (self, ...)
        -- products are stuff returned by each function
        local products = {}
        local central_hash = pcmg.citychunk_hash(self.central.origin)
        products[central_hash] = method(self.central, ...)
        for _, neighbor in pairs(self.neighbors) do
            local hash = pcmg.citychunk_hash(neighbor.origin)
            products[hash] = method(neighbor, ...)
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

-- Allows Megacanvas3D objects to call Megacanvas3D or Canvas3D methods.
-- If there's no method with 'key' name in the Megacanvas3D class, it
-- looks for the method in the Canvas3D class.
-- When using methods from the Canvas3D class, a method created by
-- 'make_method' is used (see above).
megacanvas3d.__index = function(object, key)
    if megacanvas3d[key] then
        object[key] = megacanvas3d[key]
        return megacanvas3d[key]
    elseif pcmg.canvas3d[key] then
        local method = make_method(pcmg.canvas3d[key])
        object[key] = method
        return method
    end
end

local blank_id = 1

--[[
    Cache for canvas3d data.
    Each table in 'cache' is keyed by citychunk hash.
    * 'citychunks': contains canvas3d objects
    * 'partially_complete': bool values, true means the citychunk
    was overgenerated from other citychunks, but was not itself fully generated
    * 'complete': bool values, true means the citychunk was both overgenerated
    and generated.
    * 'citychunk_meta': arbitrary user-provided data
--]]

megacanvas3d.cache = {}

function megacanvas3d.cache.new(c)
    local cache = c or {}
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
        local canv = cache.citychunks[hash] or pcmg.canvas3d.new(origin)
        cache.citychunks[hash] = canv
        table.insert(canvases, canv)
    end
    return canvases
end

function megacanvas3d.new(citychunk_origin, cache)
    local megacanv = {}
    megacanv.cache = megacanvas3d.cache.new(cache)
    megacanv.origin = vector.copy(citychunk_origin)
    megacanv.cursor = vector.new(0, 0, 0) -- abs pos only
    local hash = pcmg.citychunk_hash(citychunk_origin)
    megacanv.central = cache.citychunks[hash] or pcmg.canvas3d.new(citychunk_origin)
    cache.citychunks[hash] = megacanv.central
    megacanv.neighbors = neighboring_canvases(megacanv.origin, cache)
    megacanv.metastore = pcmg.metastore.new()
    setmetatable(megacanv, megacanvas3d)
    megacanv:set_metastore(megacanv.metastore)
    return megacanv
end

function megacanvas3d:set_metastore(mt)
    self.metastore = pcmg.metastore.check(mt) and mt
    local set_metastore = make_method(pcmg.canvas3d["set_metastore"])
    set_metastore(self, mt)
end

-- Sets cursors of the central citychunk and neighbors
-- to 'pos' which is absolute position
function megacanvas3d:set_all_cursors(pos)
    self.cursor = vector.copy(pos)
    self:set_cursor_absolute(pos)
end

-- Moves cursors of the central citychunk and neighbors
-- by 'vec' which is vector
function megacanvas3d:move_all_cursors(vec)
    self:set_all_cursors(self.cursor + vec)
end


-- Marks the central citychunk as complete in the citychunk cache
function megacanvas3d:mark_complete()
    local hash = pcmg.citychunk_hash(self.central.origin)
    self.cache.complete[hash] = true
    self.cache.partially_complete[hash] = nil
end

function megacanvas3d:mark_partially_complete()
    local hash = pcmg.citychunk_hash(self.central.origin)
    self.cache.partially_complete[hash] = true
end

--[[
    Generates a citychunk using the 'generator_function'
    which takes a megacanvas3d as its argument.
    'recursion_level' is a number of neighbor layers to process,
    for example 'recursion_level' = 1 means 'generator_function'
    will also be applied to neighbors of the central citychunk,
    'recursion_level' = 2 means also neighbors of the neighbors
    will be generated.
    'generator_function' MUST use reproducible randomness, otherwise
    overgeneration won't work.
    'generator_function' is only ran once for a citychunk that's not
    marked as 'complete ' or 'partially_complete', so for fresh
    citychunks only.

    XXX: Replace with a canvas-independent (over)generator?
--]]
function megacanvas3d:generate(generator_function, recursion_level, ...)
    local recursion_level = recursion_level or 1
    local central_hash = pcmg.citychunk_hash(self.origin)
    if not self.cache.partially_complete[central_hash] and
        not self.cache.complete[central_hash]
    then
        generator_function(self, ...)
        self:mark_partially_complete()
    end
    if recursion_level <= 0 then
        return
    end
    recursion_level = recursion_level - 1
    for _, neighbor in pairs(self.neighbors) do
        local hash = pcmg.citychunk_hash(neighbor.origin)
        if not self.cache.complete[hash] then
            local new_megacanv = pcmg.megacanvas3d.new(neighbor.origin, self.cache)
            new_megacanv:generate(generator_function, recursion_level, ...)
        end
    end
    self:mark_complete()
end

function megacanvas3d:draw_straight(shape, start, finish)
    self:set_all_cursors(start)
    self:draw_shape(shape)
    while (vector.distance(self.cursor, finish) >= 1) do
        local gravity = vector.direction(self.cursor, finish)
        self:move_all_cursors(vector.round(gravity))
        self:draw_shape(shape)
    end
end

function megacanvas3d:draw_wobbly(shape, start, finish)
    self:set_all_cursors(start)
    self:draw_shape(shape)
    while (vector.distance(self.cursor, finish) >= 1) do
        local gravity = vector.direction(self.cursor, finish)
        local random_move = vector.random(-1, 1) + gravity
        self:move_all_cursors(random_move)
        self:draw_shape(shape)
    end
end

-- Line drawstyle
local line_styles = {
    straight = megacanvas3d.draw_straight,
    wobbly = megacanvas3d.draw_wobbly,
}

function megacanvas3d:register_drawstyle(name, func)
    if type(name) ~= "string" then
        error("Megacanvas3D: drawstyle 'name' has to be a string but is: "..shallow_dump(name))
    end
    if type(func) ~= "function" then
        error("Megacanvas3D: drawstyle 'func' has to be a function but is: "..shallow_dump(func))
    end
    line_styles[name] = func
end

function megacanvas3d:draw_path(shape, path, style)
    local current_point = path.start
    local path_style = self.metastore:get(path, "style")
    while (current_point.next) do
        local point_style = self.metastore:get(current_point, "style")
        local draw_function = line_styles[point_style or path_style or style]
        local start = current_point.pos
        local finish = current_point.next.pos
        draw_function(self, shape, start, finish)
        current_point = current_point.next
    end
    for _, bp in pairs(path.branching_points) do
        for _, branch in pairs(bp.branches) do
            self:draw_path(shape, branch, style)
        end
    end
end

function megacanvas3d:draw_path_points(shape, path)
    local all_pos = path:all_positions()
    for _, pos in pairs(all_pos) do
        self:set_all_cursors(pos)
        self:draw_shape(shape)
    end
    for _, bp in pairs(path.branching_points) do
        for _, branch in pairs(bp.branches) do
            self:draw_path_points(shape, branch)
        end
    end
end

function megacanvas3d:draw_random(shape, nr)
    for x = 1, nr do
        local point = pcmg.random_pos_in_citychunk(self.origin)
        self:set_all_cursors(point)
        self:draw_shape(shape)
    end
end
