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

local pathpaver_margin = sizes.citychunk.overgen_margin
local margin_vector = vector.new(1, 1, 1) * pathpaver_margin
local margin_min = sizes.citychunk.pos_min - margin_vector
local margin_max = sizes.citychunk.pos_max + margin_vector

--[[
    Pathpaver
    1. stores point data for a given citychunk
    2. stores path data for a given citychunk
    3. helps check for colisions
--]]

pcmg.pathpaver = {}
local pathpaver = pcmg.pathpaver
pathpaver.__index = pathpaver

-- Rename to path store?
function pathpaver.new(citychunk_origin)
    local p = {}
    p.origin = vector.copy(citychunk_origin)
    p.margin_min = p.origin + margin_min
    p.margin_max = p.origin + margin_max
    p.paths = {}
    p.points = setmetatable({}, {__mode = "kv"})
    return setmetatable(p, pathpaver)
end

-- Checks if position 'pos' is inside the citychunk and its
-- overgeneration area. Returns a boolean.
function pathpaver:pos_in_margin(pos)
    return vector.in_area(pos, self.margin_min, self.margin_max)
end

-- Checks if position 'pos' is inside the citychunk (NOT including its
-- overgeneration area. Returns a boolean.
function pathpaver:pos_in_citychunk(pos)
    return vector.in_area(pos, self.origin, self.origin +
                          sizes.citychunk.pos_max)
end

function pathpaver.check(p)
    return getmetatable(p) == pathpaver
end

-- Saves the 'pnt' point in the pathpaver.
function pathpaver:save_point(pnt)
    if self:pos_in_margin(pnt.pos) then
        self.points[pnt] = pnt
    end
end

function pathpaver:path_points()
    local all = {}
    for _, path in pairs(self.paths) do
        local points = path:all_points()
        for _, p in pairs(points) do
            all[p] = p
        end
    end
    return all
end

-- Checks if a position given by 'pos' is contained in the radius of
-- a point given by 'radius'. Returns all points that contain the
-- position within the radius. Returns false if no colliding points
-- were found for the position. When 'only_paths' is 'true', the
-- function will only search in points that belong to paths saved in
-- the current pathpaver and won't include overgenerated points from
-- neighboring citychunks. When 'only_paths' is 'false' (the default),
-- the function will check all points in the pathpaver.
function pathpaver:colliding_points(pos, radius, only_paths)
    local colliding = {}
    local points = only_paths and self:path_points() or self.points
    for _, point in pairs(points) do
        local distance = vector.distance(pos, point.pos)
        if distance <= radius then
            table.insert(colliding, point)
        end
    end
    return colliding
end
