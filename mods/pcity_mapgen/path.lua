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
local vector = vector
local pcmg = pcity_mapgen

pcmg.path = {}
local path = pcmg.path
path.__index = path

local point = {}
point.__index = point

-- Checks if arguments passed to 'point.new' are valid,
-- otherwise throws errors
local function point_new_checks(pos, pth)
    if not vector.check(pos) then
        error("Path: pos '"..dump(pos).."' is not a vector.")
    end
    if not path.check(pth) then
        error("Path: pth '"..dump(pth).."' is not a path.")
    end
end

-- Creates a new instance of the Point class. Points store absolute
-- world position, the previous and the next point in a sequence and
-- the path (see the Path class below) they belong to. Points can be
-- linked to create linked lists which should be helpful for
-- road/street generation algorithms.
function point.new(pos, pth)
    point_new_checks(pos, pth)
    local p = {}
    p.pos = vector.copy(pos)
    p.path = pth
    p.previous = false
    p.next = false
    p.attached = setmetatable({}, {__mode = "kv"})
    p.branches = {}
    return setmetatable(p, point)
end

-- Checks if the object is a point.
function point.check(p)
    return getmetatable(p) == point
end

-- Links points in order, accepts any number of points.
function point.link(...)
    local points = {...}
    for i = 1, #points - 1 do
        points[i].next = points[i + 1]
        points[i + 1].previous = points[i]
    end
end

-- Unlinks the point from both the previous and the next point.
function point:unlink()
    self.next = false
    self.previous = false
    if self.next and
        self.next.previous == self then
        self.next.previous = false
    end
    if self.previous and
        self.previous.next == self then
        self.previous.next = false
    end
    self.path.points[self] = nil
end

-- Unlinks the current point from the next point.
function point:unlink_from_next()
    self.next.previous = false
    self.next = false
end

-- Attaches the 'p' point to this point. Moves the 'p' point to the
-- position of this point. This means the points now share their
-- position (setting position of one point with 'point:set_position'
-- will also change the position of all attached points).
function point:attach(p)
    if not point.check(p) then
        error("Path: p '"..dump(p).."' is not a point.")
    end
    self.attached[p] = p -- attach 'p' to 'self'
    p.attached[self] = self -- attach self to 'p'
    self.path.attached_points[self] = self -- mark 'self' as attached in its path
    p.path.attached_points[p] = p -- mark 'p' as attached in its path
    p.pos = self.pos -- synch pos
end

-- Detaches this point from all points it is attached to (if no
-- aruments passed to the method) or points passed to the method.
-- '...' is any number of points.
function point:detach(...)
    local points = ... and {...} or self.attached
    for _, p in pairs(points) do
        p.attached[self] = nil -- detach 'self' from points attached to it
        if next(p.attached) == nil then
            -- if 'p' has no other attached points, unmark it from
            -- attached points in its path
            p.path.attached_points[p] = nil
        end
        self.attached[p] = nil -- detach 'p' from 'self'
    end
    if next(self.attached) == nil then
        -- if 'self' has no other attached points, unmark it from
        -- attached points in its path
        self.path.attached_points[self] = nil
    end
end

-- Sets position of the given point and all attached points to 'pos'.
function point:set_position(pos)
    if not vector.check(pos) then
        error("Path: pos '"..dump(pos).."' is not a vector.")
    end
    self.pos = pos
    for _, a in pairs(attached) do
        a.pos = pos
    end
end

-- Returns an iterator function for a point. The iterator function
-- lets you traverse the linked list of points and returns two values:
-- 'i' - the ordinal number of the next point starting from the
-- current point (so the number of points between the point the
-- iterator was created for) and 'current_point' - the next point in
-- the sequence (linked list/path). Use just like 'ipairs'.
-- Example: for i, p in my_point:iterator() do ... end
function point:iterator()
    local i = 0
    local current_point = self
    return function ()
        current_point = current_point.next
        i = i + 1
        if current_point then
            return i, current_point
        end
    end
end

-- Works just like 'point:iterator()', but instead it iterates in
-- reverse order - lets you traverse the path from a given point to
-- the start point.
-- Example: for i, p in my_point:reverse_iterator() do ... end
function point:reverse_iterator()
    local i = 0
    local current_point = self
    return function ()
        current_point = current_point.previous
        i = i + 1
        if current_point then
            return i, current_point
        end
    end
end

-- Starts a new path at the position of the point.
-- Uses the same position object for the point and the start point of
-- the new path so that these points remain attached when changing position.
-- Returns the new path (branch).
function point:branch(finish)
    self.path.branching_points[self] = self
    local pth = path.new(self.pos, finish, self)
    pth.start.pos = self.pos
    self.branches[pth] = pth
    return pth
end

-- Checks if arguments passed to 'path.new' are valid,
-- otherwise throws errors
local function path_new_checks(start, finish, trunk)
    if not vector.check(start) then
        error("Path: start '"..dump(start).."' is not a vector.")
    end
    if not vector.check(finish) then
        error("Path: finish '"..dump(finish).."' is not a vector.")
    end
    if trunk and not point.check(trunk) then
        error("Path: trunk '"..dump(trunk).."' is not a point.")
    end
end

-- Creates an instance of the Path class. Paths store a sequence of
-- points (have a direction). Each path has a start and a finish point
-- and optionally intermediate points. Each point is an instance of
-- the Point class, so the path is actually a linked list of points.
function path.new(start, finish, trunk)
    path_new_checks(start, finish, trunk)
    local pth = setmetatable({}, path)
    pth.start = point.new(start, pth)
    pth.finish = point.new(finish, pth)
    point.link(pth.start, pth.finish)
    pth.points = setmetatable({}, {__mode = "kv"})
    pth.point_nr = 0 -- nr of intermediate points
    pth.trunk = trunk -- optional trunk point
    pth.branching_points = setmetatable({}, {__mode = "kv"})
    pth.attached_points = setmetatable({}, {__mode = "kv"})
    return pth
end

-- Checks if an object is a path as created by path.new
function path.check(p)
    return getmetatable(p) == path
end

-- Returns an intermediate point given by 'nr' that is the ordinal
-- number of the point in the sequence starting the first intermediate
-- point and ending with the last. So 'nr' = 1 will give the first
-- intermediate point in the path, etc. Returns 'nil' if no point is
-- found at the position.  Returns 'nil' if 'nr' is lower than 1 or
-- bigger than the number of intermediate points.
function path:get_point(nr)
    if type(nr) ~= "number" or
        nr <= 0 or nr > self.point_nr then
        return
    end
    for i, p in self.start:iterator() do
        if i == nr then
            return p
        end
    end
end

-- Picks a random intermediate point in the path and returns it.
-- Returns 'nil' if there are no intermediate points.
function path:random_intermediate_point()
    if self.point_nr > 0 then
        return self:get_point(math.random(1, self.point_nr))
    end
end

-- Checks if arguments passed to 'path:insert' are valid,
-- otherwise throws errors
local function path_insert_checks(pos, nr)
    if not vector.check(pos) and not point.check(pos) then
        error("Path: pos '"..dump(pos).."' is not a vector nor a point.")
    end
    if nr and type(nr) ~= "number" then
        error("Path: nr '"..dump(nr).."' is not a number.")
    end
end

-- When 'pos' is a vector, creates a new point using 'pos' and
-- insesrts it before the finish point into the path. When 'nr' is
-- given, the point is inserted at the position with number 'nr' in
-- the sequence of intermediate points in the path.
-- When 'pos' is a point, the function does the same as above, but
-- uses the provided point instead of creating a new one.
-- Used when the destination (finish) point stays the
-- same but an intermediate point is added.
function path:insert(pos, nr)
    path_insert_checks(pos, nr)
    local next_point = self:get_point(nr) or self.finish
    local new_point = point.check(pos) and pos or point.new(pos, self)
    local previous_point = next_point.previous
    point.link(previous_point, new_point, next_point)
    self.points[new_point] = new_point
    self.point_nr = self.point_nr + 1
end

-- Checks if arguments passed to 'path:remove' are valid,
-- otherwise throws errors
local function path_remove_checks(self, nr)
    if not nr then
        return
    end
    if type(nr) ~= "number" and not point.check(nr) then
        error("Path: nr '"..dump(nr).."' is not a number nor a point.")
    end
    if point.check(nr) and not self.points[nr] then
        error("Path: point nr '"..dump(nr).."' does not belong to the path .")
    end
end

-- Removes the intermediate point before the finish point or, at the
-- position specified by 'nr' if provided. When 'nr' is a point
-- instead of a number, the point gets removed from the path.
-- Used when the destination (finish) point stays the same but an
-- intermediate point is removed.
function path:remove(nr)
    if self.point_nr <= 0 then
        return
    end
    --path_remove_checks(self, nr)
    local middle_point = self.points[nr] or
        self:get_point(nr) or self.finish.previous
    point.link(middle_point.previous, middle_point.next)
    middle_point:unlink()
    self.point_nr = self.point_nr - 1
end

-- Extends the path by adding a new finish point,
-- moves the old finish point down the table.
function path:extend(pos)
    if not vector.check(pos) and not point.check(pos) then
        error("Path: pos '"..dump(start).."' is not a vector nor a point.")
    end
    local new_point = point.check(pos) and pos or point.new(pos, self)
    point.link(self.finish, new_point)
    self.points[self.finish] = self.finish
    self.finish = new_point
    self.point_nr = self.point_nr + 1
end

-- Shortens the table by removing the finish point and
-- setting a new one using the last intermediate point.
function path:shorten(nr)
    for i = 1, nr or 1 do
        if next(self.points) == nil then
            return
        end
        local old_finish = self.finish
        self.finish = self.finish.previous
        self.finish:unlink_from_next()
        old_finish:unlink()
        self.point_nr = self.point_nr - 1
    end
end

-- Cuts off (removes from the path) all points that come after the
-- point specified by 'point'. Sets 'point' as the new finish.
function path:cut_off(point)
    if not self.points[point] and not
        self.finish == point then
        return
    end
    if self.finish == point then
        self:shorten()
        return
    end
    for _, p in self.finish:reverse_iterator() do
        if p == point then
            break
        end
        self:shorten()
    end
    self:shorten()
end

-- Returns all points of the path including start,
-- intermediate points and stop (in order).
function path:all_points()
    local points = {}
    table.insert(points, self.start)
    for _, p in self.start:iterator() do
        table.insert(points, p)
    end
    return points
end

-- Returns positions of all points of the path including start,
-- intermediate points and stop (in order).
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

-- Subdivides path into segments with max length specified by
-- 'segment_length', leaves segments shorter than that untouched.
function path:subdivide(segment_length)
    local i = 1
    local current_point = self.start
    while (current_point.next) do
        local v = current_point.next.pos - current_point.pos
        if vector.length(v) > segment_length then
            local new_segment = vector.normalize(v) * segment_length
            local current_pos = current_point.pos + new_segment
            self:insert(current_pos, i)
        end
        current_point = current_point.next
        i = i + 1
    end
end

-- Any three points in order in a path form an angle. This function
-- removes intermediate points that form an angle that doesn't diverge
-- from a straight line by at least 'angle' radians.
function path:unsubdivide(angle)
    if self.point_nr <= 0 then
        return
    end
    local prev = self.start
    local mid = prev.next
    local nxt = mid.next
    while (nxt) do
        local mid_prev = mid.pos - prev.pos
        local mid_nxt = nxt.pos - mid.pos
        if math.abs(vector.angle(mid_prev, mid_nxt)) < angle then
            self:remove(mid)
        else
            prev = mid
        end
        mid = prev and prev.next
        nxt = mid and mid.next
    end
end

-- Transfers points from p2 to p1. This action is destructive for p2 -
-- it changes point ownership of its points from p2 to p1. Therefore
-- p2 should be discarded after merging points into p1.
function path.merge(p1, p2)
    if vector.equals(p1.finish.pos, p2.start.pos) then
        for _, branch in pairs(p1.finish.branches) do
            p2.start.branches[branch] = branch
        end
        p1:shorten()
    end
    for _, bp in pairs(p2.branching_points) do
        p1.branching_points[bp] = bp
    end
    local points = p2:all_points()
    for _, pnt in ipairs(points) do
        pnt.path = p1
        p1:extend(pnt)
    end
end

-- Creates a straight path from 'self.start' to 'self.finish'
-- When 'segment_length' is given, the path will be subdivided
-- into segments with max length of 'segment_length'.
function path:make_straight(segment_length)
    if segment_length then
        self:subdivide(segment_length)
    end
end

function path:make_wave(segment_nr, amplitude, density)
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
end

-- Creates a path by connecting 'self.start' and 'self.finish'
-- so that there's only one break point that forms a 45 degree
-- angle. When 'segment_length' is given, the path will be further
-- subdivided into segments with max length of 'segment_length'.
function path:make_slanted(segment_length)
    local vec = self.finish.pos - self.start.pos
    local sign = vector.sign(vec)
    local abs = vector.abs(vec)
    local mid_point = self.start.pos + vector.new(abs.z * sign.x, 0, abs.z * sign.z)
    if abs.x < abs.z then
        mid_point = self.start.pos + vector.new(abs.x * sign.x, 0, abs.x * sign.z)
    end
    self:insert(mid_point)
    if segment_length then
        self:subdivide(segment_length)
    end
end
