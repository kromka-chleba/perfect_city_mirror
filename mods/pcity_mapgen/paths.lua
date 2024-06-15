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

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

pcmg.path = {}
local path = pcmg.path
path.__index = path

function path.new(start, finish)
    assert(vector.check(start), "Path: start '"..dump(start).."' is not a vector.")
    assert(vector.check(finish), "Path: finish '"..dump(finish).."' is not a vector.")
    local pth = {}
    pth.start = vector.floor(start)
    pth.finish = vector.floor(finish)
    pth.locked = false
    pth.points = {}
    return setmetatable(pth, path)
end

function path:lock()
    self.locked = true
end

function path:unlock()
    self.locked = false
end

function path:add_point(pos)
    assert(vector.check(pos), "Path: pos '"..dump(pos).."' is not a vector.")
    if not self.locked then
        table.insert(self.points, pos)
    end
end

function path:remove_point()
    if not self.locked then
        table.remove(self.points)
    end
end

function path:all_points()
    local all_points = {}
    table.insert(all_points, self.start)
    for _, point in ipairs(self.points) do
        table.insert(all_points, point)
    end
    table.insert(all_points, self.finish)
    return all_points
end

function path:make_straight(segment_nr)
    if self.locked then
        return
    end
    local v = (self.finish - self.start) / segment_nr
    local current_pos = self.start
    for i = 1, segment_nr - 1 do
        current_pos = current_pos + v
        self:add_point(vector.floor(current_pos))
    end
    self:lock()
end

function path:make_wave(segment_nr)
    if self.locked then
        return
    end
    local v = (self.finish - self.start) / segment_nr
    local total_distance = vector.distance(self.start, self.finish)
    local direction = vector.normalize(v)
    local perpendicular = vector.rotate(direction, vector.new(0, math.pi / 2, 0))
    local current_pos = self.start
    for i = 1, segment_nr - 1 do
        current_pos = current_pos + v
        local distance = vector.distance(self.start, current_pos)
        local distance_cofactor = math.sin(distance / total_distance * math.pi)
        local wave = math.sin(distance / total_distance * math.pi * 10)
        local pos = current_pos + perpendicular * distance_cofactor * wave * 40
        self:add_point(vector.floor(pos))
    end
    self:lock()
end
