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

function pathpaver.check(p)
    return getmetatable(p) == pathpaver
end

function pathpaver:save_point(pnt)
    if vector.in_area(pnt.pos, self.margin_min, self.margin_max) then
        self.points[pnt] = pnt
    end
end
