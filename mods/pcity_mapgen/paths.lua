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
    pth.start = vector.copy(start)
    pth.finish = vector.copy(finish)
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

function path:add_point(pos, tab_pos)
    assert(vector.check(pos), "Path: pos '"..dump(pos).."' is not a vector.")
    if self.locked then
        return
    end
    if tab_pos then
        table.insert(self.points, tab_pos, pos)
    end
    table.insert(self.points, pos)
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

function path:length()
    local points = self:all_points()
    local length = 0
    for i = 2, #points do
        local v = points[i] - points[i - 1]
        length = length + vector.length(v)
    end
    return length
end

function path:split(segment_length)
    local points = self:all_points()
    local i = 2
    while (#points >= i) do
        local v = points[i] - points[i - 1]
        if vector.length(v) > segment_length then
            local new_segment = vector.normalize(v) * segment_length
            local current_pos = points[i - 1] + new_segment
            table.insert(points, i, current_pos)
        end
        i = i + 1
    end
    table.remove(points, 1)
    table.remove(points)
    self.points = points
end

function path:make_straight(segment_length)
    if self.locked then
        return
    end
    if segment_length then
        self:split(segment_length)
    end
    self:lock()
end

function path:make_wave(segment_nr, amplitude, density)
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
        local wave = math.sin(distance / total_distance * 2 * math.pi * density)
        local pos = current_pos + perpendicular * distance_cofactor * wave * amplitude
        self:add_point(pos)
    end
    self:lock()
end

function path:make_slanted(segment_length)
    if self.locked then
        return
    end
    local vec = self.finish - self.start
    local mid_point = self.start + vector.new(vec.z, 0, vec.z)
    if math.abs(vec.x) < math.abs(vec.z) then
        mid_point = self.start + vector.new(vec.x, 0, vec.x)
    end
    self:add_point(mid_point)
    if segment_length then
        self:split(segment_length)
    end
    self:lock()
end
