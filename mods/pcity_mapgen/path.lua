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

-- Validates arguments passed to 'point.new'.
local function check_point_new_arguments(pos)
    if not vector.check(pos) then
        error("Path: pos '"..shallow_dump(pos).."' is not a vector.")
    end
end

local private = setmetatable({}, {__mode = "k"})

-- Creates a new instance of the Point class. Points store absolute
-- world position, the previous and the next point in a sequence and
-- the path (see the Path class below) they belong to. Points can be
-- linked to create linked lists which should be helpful for
-- road/street generation algorithms.
function point.new(pos)
    check_point_new_arguments(pos)
    local p = {}
    p.pos = vector.copy(pos)
    p.path = false
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

-- Check if points belong to the same path. '...' is any number of points.
function point.same_path(...)
    local points = {...}
    local first_path = points[1].path
    for _, p in ipairs(points) do
        if p.path ~= first_path then
            return false
        end
    end
    return true
end

-- Asserts that all points belong to the same path, otherwise throws an error.
local function check_same_path(points)
    if not point.same_path(table.unpack(points)) then
        error("Path: Cannot link points that belong to different paths.")
    end
end

-- Links points in order, accepts any number of points. '...' is any number of points.
-- Only points belonging to the same path can be linked.
function point.link(...)
    local points = {...}
    check_same_path(points)
    for i = 1, #points - 1 do
        points[i].next = points[i + 1]
        points[i + 1].previous = points[i]
    end
end

-- Unlinks the current point from the previous point.
function point:unlink_from_previous()
    if self.previous.next == self then
        self.previous.next = false
    end
    self.previous = false
end


-- Unlinks the current point from the next point.
function point:unlink_from_next()
    if self.next.previous == self then
        self.next.previous = false
    end
    self.next = false
end

-- Unlinks the point from both the previous and the next point.
function point:unlink()
    self:unlink_from_previous()
    self:unlink_from_next()
end

-- Ensures that 'point' is a point instance. If 'point' is already
-- a point, it is returned as is. If 'point' is a vector, a new point
-- instance is created with that position and returned.
local function ensure_point(point)
    local p
    if vector.check(point) then
        p = point.new(point)
    end
    if not point.check(point) then
        error("Path: point '"..shallow_dump(point).."' is not a point.")
    end
    return p or point
end

-- Attaches this point to any number of other points passed as
-- arguments. '...' is any number of points. Attached points share
-- the same position as this point. When the position of this point
-- changes, the positions of all attached points change as well.
function point:attach(...)
    local points = {...}
    for _, p in ipairs(points) do
        p = ensure_point(p)
        p.pos = self.pos
        self.attached[p] = p
        p.attached[self] = self
    end
end

-- Detaches this point from any number of other points passed as
-- arguments. '...' is any number of points.
function point:detach(...)
    local points = {...}
    for _, p in ipairs(points) do
        p = ensure_point(p)
        p.attached[self] = nil -- detach 'self' from points attached to it
        self.attached[p] = nil -- detach 'p' from 'self'
    end
end

-- Detaches this point from all points it is attached to.
function point:detach_all()
    for _, p in pairs(self.attached) do
        p.attached[self] = nil
    end
    self.attached = setmetatable({}, {__mode = "kv"})
end

-- Sets position of the given point and all attached points to 'pos'.
function point:set_position(pos)
    if not vector.check(pos) then
        error("Path: pos '"..shallow_dump(pos).."' is not a vector.")
    end
    self.pos = pos
    for _, a in pairs(self.attached) do
        a.pos = pos
    end
end

-- Comparator function for vectors. Compares vectors by their x, y, z
-- coordinates in that order. Returns true if v1 has more negative
-- coordinates than v2.
function vector.comparator(v1, v2)
    if v1.x ~= v2.x then
        return v1.x < v2.x
    end
    if v1.y ~= v2.y then
        return v1.y < v2.y
    end
    if v1.z ~= v2.z then
        return v1.z < v2.z
    end
    return true
end

-- Comparator function for points. Compares points by ALL their
-- fields: position (using vector.comparator), path (by reference),
-- previous point (by reference), next point (by reference).
function point.comparator(p1, p2)
    if not vector.equals(p1.pos, p2.pos) then
        return vector.comparator(p1.pos, p2.pos)
    end
    if p1.path ~= p2.path then
        return tostring(p1.path) < tostring(p2.path)
    end
    if p1.previous ~= p2.previous then
        return tostring(p1.previous) < tostring(p2.previous)
    end
    if p1.next ~= p2.next then
        return tostring(p1.next) < tostring(p2.next)
    end
    return true
end

-- Returns an iterator function for a point. The iterator function
-- lets you traverse the linked list of points and returns two values:
-- 'i' - the ordinal number of the next point starting from the
-- current point (so the number of points between the point the
-- iterator was created for) and 'current_point' - the next point in
-- the sequence (linked list/path). Use just like 'ipairs'.
-- Example usage: for i, p in my_point:iterator() do ... end
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

-- Sets 'pth' as the path for the point.
function point:set_path(pth)
    if not path.check(pth) then
        error("Path: pth '"..shallow_dump(pth).."' is not a path.")
    end
    self.path = pth
end

-- Creates a new branch path starting from this point to the 'finish'
-- point. The start point of the branch (path) is lineked to this point.
-- Returns the newly created branch path.
function point:branch(finish)
    self.path.branching_points[self] = self
    local pth = path.new(self.pos, finish)
    self:attach(pth.start)
    self.branches[pth] = pth
    return pth
end

-- Checks if the point has any branches.
function point:has_branches()
    return next(self.branches) ~= nil
end

-- Removes the branch 'pth' from the point.
function point:remove_branch(pth)
    self.branches[pth] = nil
    -- if there are no more branches, unmark this point
    if next(self.branches) == nil then
        self.path.branching_points[self] = nil
    end
end


function point:remove()
    if self.path then
        self.path:remove(self, true)
        self.path = nil
    end
    self:unlink()
    self:detach()
    for _, branch in pairs(self.branches) do
        branch.start:remove_branch(branch)
    end
end

-- Validates arguments passed to 'path.new'.
local function check_path_new_arguments(start, finish)
    if not vector.check(start) then
        error("Path: start '"..shallow_dump(start).."' is not a vector.")
    end
    if not vector.check(finish) then
        error("Path: finish '"..shallow_dump(finish).."' is not a vector.")
    end
end

-- Creates an instance of the Path class. Paths store a sequence of
-- points (have a direction). Each path has a 'start' and a 'finish'
-- point and optionally intermediate points. Each point is an instance
-- of the Point class, so the path is actually a linked list of points.
function path.new(start, finish)
    check_path_new_arguments(start, finish)
    local pth = setmetatable({}, path)
    pth:set_start(start)
    pth:set_finish(finish)
    pth.points = setmetatable({}, {__mode = "kv"})
    pth.intermediate_nr = 0 -- nr of intermediate points
    pth.branching_points = setmetatable({}, {__mode = "kv"})
    return pth
end

-- Checks if an object is a path as created by path.new
function path.check(p)
    return getmetatable(p) == path
end

function path:set_start(point)
    point = ensure_point(point)
    self.start = point
    self.start:set_path(self)
    self.start:unlink()
    point.link(self.start, self.finish)
end

function path:set_finish(point)
    point = ensure_point(point)
    self.finish = point
    self.finish:set_path(self)
    self.finish:unlink()
    point.link(self.start, self.finish)
end

-- Returns an intermediate point given by 'nr' that is the ordinal
-- number of the point in the sequence starting the first intermediate
-- point and ending with the last. So 'nr' = 1 will give the first
-- intermediate point in the path, etc. Returns 'nil' if no point is
-- found at the position.  Returns 'nil' if 'nr' is lower than 1 or
-- bigger than the number of intermediate points.
function path:get_point(nr)
    if type(nr) ~= "number" or
        nr <= 0 or nr > self.intermediate_nr then
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
    if self.intermediate_nr > 0 then
        return self:get_point(math.random(1, self.intermediate_nr))
    end
end

-- Checks if the point belongs to the path as either start,
-- intermediate or finish point. Returns a boolean.
function path:point_in_path(point)
    return self.points[point] or
        self.start == point or
        self.finish == point
end

-- Checks if arguments passed to 'path:insert' are valid.
local function check_insert_arguments(self, nr, point)
    if type(nr) ~= "number" then
        error("Path: nr '"..shallow_dump(nr).."' is not a number.")
    end
    if nr < 1 or nr > self.intermediate_nr + 1 then
        error("Path: nr '"..shallow_dump(nr).."' is out of range.")
    end
end

-- Inserts 'point' into the path at position 'nr', which is the
-- ordinal number of the point in the sequence starting from the
-- first intermediate point. So 'nr' = 1 will insert the point
-- right after the start point. 'nr' = intermediate_nr + 1 will
-- insert the point right before the finish point.
function path:insert(nr, point)
    check_insert_arguments(self, nr, point)
    point = ensure_point(point)
    point:set_path(self)
end

-- Checks if arguments passed to 'path:remove', 'path:remove_before'
-- and 'path:remove_after' are valid.
local function check_remove_arguments(self, point)
    if not self.points[point] then
        error("Path: point '"..shallow_dump(point).."' does not belong to the path .")
    end
    if self.intermediate_nr <= 0 then
        error("Path: there are no intermediate points to remove.")
    end
end

-- Removes 'point' from the path. 'point' must be an intermediate
-- point that belongs to the path. If 'called_from_point' is true,
-- the point's 'remove' method is not called (to avoid infinite recursion).
function path:remove(point, called_from_point)
    point = ensure_point(point)
    check_remove_arguments(self, point)
    point.link(point.previous, point.next)
    if not called_from_point then
        point:remove()
    end
    self.intermediate_nr = self.intermediate_nr - 1
end

-- Removes the point before 'point' from the path. 'point' must be an
-- intermediate point (not the start point or the finish point).
function path:remove_before(point)
    point = ensure_point(point)
    check_remove_arguments(self, point)
    if point.previous == nil or
        point.previous == self.start then
        return
    end
    local middle_point = point.previous
    point.link(middle_point.previous, point)
    middle_point:unlink()
    self.intermediate_nr = self.intermediate_nr - 1
end

-- Removes the point after 'point' from the path. 'point' must be an
-- intermediate point (not the start point or the finish point).
function path:remove_after(point)
    point = ensure_point(point)
    check_remove_arguments(self, point)
    if point.next == nil or
        point.next == self.finish then
        return
    end
    local middle_point = point.next
    point.link(point, middle_point.next)
    middle_point:unlink()
    self.intermediate_nr = self.intermediate_nr - 1
end

-- Checks if arguments passed to 'path:remove_at' are valid,
local function check_remove_at_arguments(self, nr)
    if type(nr) ~= "number" then
        error("Path: nr '"..shallow_dump(nr).."' is not a number.")
    end
    local point = self:get_point(nr)
    if not point then
        error("Path: no intermediate point at nr '"..shallow_dump(nr).."'.")
    end
end

-- Removes an intermediate point given by its ordinal number 'nr'.
function path:remove_at(nr)
    check_remove_at_arguments(self, nr)
    local middle_point = self:get_point(nr)
    self:remove(middle_point)
end

-- Extends the path by adding 'point' at the end of the path.
-- 'point' becomes the new finish point.
function path:extend(point)
    point = ensure_point(point)
    point:set_path(self)
    self.finish:link(point)
    self.points[self.finish] = self.finish
    self.finish = point
    self.intermediate_nr = self.intermediate_nr + 1
end

-- Shortens the path by removing 'nr' points from the end of the path.
-- By default removes just one point.
function path:shorten(nr)
    for i = 1, nr or 1 do
        if next(self.points) == nil then
            return
        end
        local old_finish = self.finish
        self.finish = self.finish.previous
        self.finish:unlink_from_next()
        old_finish:unlink()
        self.intermediate_nr = self.intermediate_nr - 1
    end
end

-- Cuts off (removes from the path) all points that come after the
-- point specified by 'point'. Sets 'point' as the new finish.
function path:cut_off(point)
    point = ensure_point(point)
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
-- intermediate points and finish (in order).
function path:all_points()
    local points = {}
    table.insert(points, self.start)
    for _, p in self.start:iterator() do
        table.insert(points, p)
    end
    return points
end

-- Returns positions of all points of the path including start,
-- intermediate points and finish (in order).
function path:all_positions()
    local positions = {}
    for _, p in ipairs(self:all_points()) do
        table.insert(positions, p.pos)
    end
    return positions
end

-- Returns the length of the path by summing lengths of all segments.
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

-- Unsubdivides the path by removing intermediate points that form an angle
-- smaller than 'angle' (in radians) with their neighbors. Leaves other points untouched.
function path:unsubdivide(angle)
    if self.intermediate_nr <= 0 then
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

-- Splits the path at 'point', which must belong to the path
-- and cannot be the start point. Returns a new path starting from
-- 'point' to the old finish point. The old path is shortened to
-- end at 'point'. 
function path:split_at(point)
    if not self:point_in_path(point) or
        point == self.start then
        return
    end
    local new_path = path.new(point.pos, self.finish)
    for _, bp in pairs(self.branching_points) do
        if bp == point or
            vector.equals(bp.pos, point.pos) or
            point:reverse_iterator()(bp) then
            new_path.branching_points[bp] = bp
            self.branching_points[bp] = nil
        end
    end
    local current_point = point
    while current_point do
        local next_point = current_point.next
        if current_point ~= point then
            current_point.path = new_path
            new_path.points[current_point] = current_point
            new_path.intermediate_nr = new_path.intermediate_nr + 1
            self.points[current_point] = nil
            self.intermediate_nr = self.intermediate_nr - 1
        end
        current_point = next_point
    end
    point:unlink_from_next()
    self.finish = point
    return new_path
end

-- Creates a straight path from 'self.start' to 'self.finish'
-- When 'segment_length' is given, the path will be subdivided
-- into segments with max length of 'segment_length'.
function path:make_straight(segment_length)
    if segment_length then
        self:subdivide(segment_length)
    end
end

-- Creates a wavy path from 'self.start' to 'self.finish'. The wave
-- oscillates with 'amplitude' (in nodes) and 'density' controls how
-- many complete wave cycles fit into the whole length of the path.
-- The path is divided into 'segment_nr' segments.
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

-- Creates a path by connecting 'self.start' and 'self.finish' so that
-- there's only one break point that forms a 45 degree angle with its
-- neighbors. When 'self.start' and 'self.finish' are parallel to
-- either the x or z axis, the function will simply make a straight
-- line. The "straight" region (parallel to x or z axis) is always
-- longer or equal to the "slanted" region. When 'segment_length' is
-- given, the path will be further subdivided into segments with max
-- length of 'segment_length'.
function path:make_slanted(segment_length)
    local vec = self.finish.pos - self.start.pos
    local sign = vector.sign(vec)
    local abs = vector.abs(vec)
    if abs.x ~= 0 and abs.z ~= 0 then
        -- add a mid point only if start and finish are not aligned on x or z axes
        local mid_point = self.start.pos +
            vector.new(abs.z * sign.x, 0, abs.z * sign.z)
        if abs.x < abs.z then
            mid_point = self.start.pos + vector.new(abs.x * sign.x, 0, abs.x * sign.z)
        end
        self:insert(mid_point)
    end
    if segment_length then
        self:subdivide(segment_length)
    end
end

-- Unit tests

pcmg.tests.path = {}
local tests = pcmg.tests.path

function tests.run_all()
    
end

