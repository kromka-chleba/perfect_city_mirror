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

pcmg.path = {}
local path = pcmg.path
path.__index = path

local point = {}
point.__index = point

function point.new(pos, pth)
    if not vector.check(pos) then
        error("Path: pos '"..dump(pos).."' is not a vector.")
    end
    if not path.check(pth) then
        error("Path: pth '"..dump(pth).."' is not a path.")
    end
    local p = {}
    p.pos = vector.copy(pos)
    p.path = pth
    p.previous = false
    p.next = false
    return setmetatable(p, point)
end

function point.check(p)
    return getmetatable(p) == point
end

function point.link(...)
    local points = {...}
    for i = 1, #points - 1 do
        points[i].next = points[i + 1]
        points[i + 1].previous = points[i]
    end
end

function point:unlink()
    self.next = false
    self.previous = false
end

function point:unlink_next()
    self.next = false
end

function path.new(start, finish)
    if not vector.check(start) then
        error("Path: start '"..dump(start).."' is not a vector.")
    end
    if not vector.check(finish) then
        error("Path: finish '"..dump(finish).."' is not a vector.")
    end
    local pth = setmetatable({}, path)
    pth.start = point.new(start, pth)
    pth.finish = point.new(finish, pth)
    point.link(pth.start, pth.finish)
    pth.locked = false
    pth.points = {}
    return pth
end

function path.check(p)
    return getmetatable(p) == path
end

function path:lock()
    self.locked = true
end

function path:unlock()
    self.locked = false
end

-- Inserts a point into the path before the finish point
-- or at the position specified by 'tab_pos' which is the index
-- in the table of intermediate points (path.points).
-- Used when the destination (finish) point stays the same
-- but an intermediate point is added.
function path:insert(pos, tab_pos)
    if not vector.check(pos) then
        error("Path: pos '"..dump(pos).."' is not a vector.")
    end
    if tab_pos and tab_pos > #self.points and tab_pos <= 0 then
        error("Path: tab_pos '"..dump(tab_pos).."' is not a valid index (out of bounds or not a number).")
    end
    if self.locked then
        return
    end
    local tab_pos = tab_pos or #self.points + 1
    local previous_point = self.points[tab_pos - 1] or self.start
    local new_point = point.new(pos, self)
    local next_point = self.points[tab_pos] or self.finish
    point.link(previous_point, new_point, next_point)
    table.insert(self.points, tab_pos, new_point)
end

-- Removes the intermediate point that's before the finish
-- or, if specified, the point at position specified by 'tab_pos'
-- Used when the destination (finish) point stays the same
-- but an intermediate point is removed.
function path:remove(tab_pos)
    if tab_pos and tab_pos > #self.points and tab_pos <= 0 then
        error("Path: tab_pos '"..dump(tab_pos).."' is not a valid index (out of bounds or not a number).")
    end
    if self.locked then
        return
    end
    local middle_point = self.points[tab_pos]
    middle_point:unlink()
    local tab_pos = tab_pos or #self.points
    local previous_point = self.points[tab_pos - 1] or self.start
    local next_point = self.points[tab_pos + 1] or self.finish
    point.link(previous_point, next_point)
    table.remove(self.points, tab_pos or #self.points)
end

-- Extends the path by adding a new finish point,
-- moves the old finish point down the table.
function path:extend(pos)
    if not vector.check(pos) then
        error("Path: pos '"..dump(start).."' is not a vector.")
    end
    if self.locked then
        return
    end
    local new_point = point.new(pos, self)
    point.link(self.finish, new_point)
    table.insert(self.points, self.finish)
    self.finish = new_point
end

-- Shortens the table by removing the finish point and
-- setting a new one using the last intermediate point.
function path:shorten()
    if #self.points <= 0 or self.locked then
        return
    end
    self.finish:unlink()
    self.finish = table.remove(self.points)
    self.finish:unlink_next()
end

-- Returns positions of all points of the path
-- including start, intermediate points and stop.
function path:all_points()
    local points = {}
    table.insert(points, self.start)
    for _, p in ipairs(self.points) do
        table.insert(points, p)
    end
    table.insert(points, self.finish)
    return points
end

function path:all_positions()
    local positions = {}
    for _, p in ipairs(self:all_points()) do
        table.insert(positions, p.pos)
    end
    return positions
end

-- Returns the length of the path
function path:length()
    local points = self:all_points()
    local length = 0
    for i = 2, #points do
        local v = points[i].pos - points[i - 1].pos
        length = length + vector.length(v)
    end
    return length
end

-- Splits path into segments with max length specified by
-- 'segment_length', leaves segments shorter than that untouched.
function path:split(segment_length)
    local points = self:all_points()
    local i = 2
    while (#points >= i) do
        local v = points[i].pos - points[i - 1].pos
        if vector.length(v) > segment_length then
            local new_segment = vector.normalize(v) * segment_length
            local current_pos = points[i - 1].pos + new_segment.pos
            path:insert(current_pos, i - 1)
        end
        i = i + 1
    end
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
    local v = (self.finish.pos - self.start.pos) / segment_nr
    local total_distance = vector.distance(self.start.pos, self.finish.pos)
    local direction = vector.normalize(v)
    local perpendicular = vector.rotate(direction, vector.new(0, math.pi / 2, 0))
    local current_pos = self.start.pos
    for i = 1, segment_nr - 1 do
        current_pos = current_pos + v
        local distance = vector.distance(self.start.pos, current_pos)
        local distance_cofactor = math.sin(distance / total_distance * math.pi)
        local wave = math.sin(distance / total_distance * 2 * math.pi * density)
        local pos = current_pos + perpendicular * distance_cofactor * wave * amplitude
        self:insert(pos)
    end
    self:lock()
end

function path:make_slanted(segment_length)
    if self.locked then
        return
    end
    local vec = self.finish.pos - self.start.pos
    local sign = vector.sign(vec)
    local abs_x, abs_z = math.abs(vec.x), math.abs(vec.z)
    local mid_point = self.start.pos + vector.new(abs_z * sign.x, 0, abs_z * sign.z)
    if abs_x < abs_z then
        mid_point = self.start.pos + vector.new(abs_x * sign.x, 0, abs_x * sign.z)
    end
    self:insert(mid_point)
    if segment_length then
        self:split(segment_length)
    end
    self:lock()
end
