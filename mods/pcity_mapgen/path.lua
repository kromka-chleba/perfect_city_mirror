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

-- Creates a new instance of the Point class. Points store absolute
-- world position, the previous and the next point in a sequence and
-- the path (see the Path class below) they belong to. Points can be
-- linked to create linked lists which should be helpful for
-- road/street generation algorithms.
function point.new(pos)
    check_point_new_arguments(pos)
    local p = {}
    p.pos = vector.copy(pos)
    p.path = nil
    p.previous = nil
    p.next = nil
    -- Weak table: attached points are kept alive by their own paths,
    -- not by the attachment relationship itself.
    p.attached = setmetatable({}, {__mode = "kv"})
    -- Weak table: branches (paths) are kept alive by their own points,
    -- not by the branching point.
    p.branches = setmetatable({}, {__mode = "kv"})
    return setmetatable(p, point)
end

-- Checks if the object is a point.
function point.check(p)
    return getmetatable(p) == point
end

-- Checks if 'p' is a point, otherwise throws an error.
local function check_point(p)
    if not point.check(p) then
        error("Path: p '"..shallow_dump(p).."' is not a point.")
    end
end

-- Creates a copy of point 'p' with the same position. The copy does
-- not inherit path, previous/next links, attachments, or branches -
-- it is a fresh, unlinked point. Use this when you need a new point
-- at the same location (e.g., when splitting a path).
function point:copy()
    return point.new(self.pos)
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
    if self.previous and self.previous.next == self then
        self.previous.next = nil
    end
    self.previous = nil
end

-- Unlinks the current point from the next point.
function point:unlink_from_next()
    if self.next and self.next.previous == self then
        self.next.previous = nil
    end
    self.next = nil
end

-- Unlinks the point from both the previous and the next point.
function point:unlink()
    self:unlink_from_previous()
    self:unlink_from_next()
end

-- Attaches this point to any number of other points passed as
-- arguments. '...' is any number of points. Attached points share
-- the same position as this point. When the position of this point
-- changes, the positions of all attached points change as well.
function point:attach(...)
    local points = {...}
    for _, p in ipairs(points) do
        check_point(p)
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
        check_point(p)
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

-- Sets 'pth' as the path for the point. Removes the point from the
-- old path's points table and adds it to the new path's points table.
function point:set_path(pth)
    if not path.check(pth) then
        error("Path: pth '"..shallow_dump(pth).."' is not a path.")
    end
    local old_path = self.path
    self.path = pth
    if old_path then
        old_path.points[self] = nil
    end
    pth.points[self] = self
end

-- Creates a new branch starting from this point and ending at
-- 'finish' point. The branch is a new path instance. The start point
-- of the branch is attached to this point. The branch is stored
-- in this point's branches table. The point is marked as a
-- branching point in the path's branching_points table. Returns
-- the newly created branch (path).
function point:branch(finish)
    self.path.branching_points[self] = self
    local pth = path.new(self:copy(), finish)
    self:attach(pth.start)
    self.branches[pth] = pth
    return pth
end

-- Checks if the point has any branches.
function point:has_branches()
    return next(self.branches) ~= nil
end

-- Removes the branch 'pth' from the point.
function point:unbranch(pth)
    self.branches[pth] = nil
    -- if there are no more branches, unmark this point
    if next(self.branches) == nil and self.path then
        self.path.branching_points[self] = nil
    end
end

-- Removes all branches from the point.
function point:unbranch_all()
    for _, branch in pairs(self.branches) do
        self:unbranch(branch)
    end
    self.branches = setmetatable({}, {__mode = "kv"})
end

-- Clears the point by unlinking it from previous and next points,
-- detaching all attached points and unbranching all branches. Also
-- removes the point from its path's points table.
-- *Caution*: after calling this method, the point could be collected by
-- the garbage collector if there are no other references to it.
function point:clear()
    self:unlink()
    self:detach_all()
    self:unbranch_all()
    if self.path then
        self.path.points[self] = nil
    end
    self.path = nil
end

-- Creates a new instance of the Path class. Paths consist of a start
-- point, a finish point and any number of intermediate points in
-- between. Points are instances of the Point class. All points
-- (including start and finish) are stored in self.points. Paths
-- support various operations for manipulating points such as
-- inserting, removing, splitting, extending, shortening, subdividing,
-- unsubdividing, etc. 'start' and 'finish' are points (instances of
-- the Point class).
function path.new(start, finish)
    local pth = setmetatable({}, path)
    -- Weak table: points are kept alive by the linked list
    -- (start -> next -> ... -> finish), not by this table.
    pth.points = setmetatable({}, {__mode = "kv"})
    pth.intermediate_nr = 0 -- nr of intermediate points (excludes start and finish)
    -- Weak table: branching points are kept alive by the path's
    -- linked list, not by this table.
    pth.branching_points = setmetatable({}, {__mode = "kv"})
    pth:set_start(start)
    pth:set_finish(finish)
    return pth
end

-- Checks if an object is a path as created by path.new
function path.check(pth)
    return getmetatable(pth) == path
end

-- Sets the start point of the path to 'p'. The start point is added
-- to the path's points table.
function path:set_start(p)
    check_point(p)
    if self.start then
        self.points[self.start] = nil
    end
    self.start = p
    self.start:set_path(self)
    self.start:unlink()
    if self.intermediate_nr > 0 then
        point.link(self.start, self:get_point(1))
    elseif self.finish then
        point.link(self.start, self.finish)
    end
end

-- Sets the finish point of the path to 'p'. The finish point is added
-- to the path's points table.
function path:set_finish(p)
    check_point(p)
    if self.finish then
        self.points[self.finish] = nil
    end
    self.finish = p
    self.finish:set_path(self)
    self.finish:unlink()
    if self.intermediate_nr > 0 then
        point.link(self:get_point(self.intermediate_nr), self.finish)
    elseif self.start then
        point.link(self.start, self.finish)
    end
end

-- Returns an intermediate point given by 'nr' that is the ordinal
-- number of the point in the sequence starting from the first
-- intermediate point (after start) and ending with the last (before
-- finish). So 'nr' = 1 will give the first intermediate point in the
-- path, etc. Returns 'nil' if no point is found at the position.
-- Returns 'nil' if 'nr' is lower than 1 or bigger than the number of
-- intermediate points. Note: start and finish are not considered
-- intermediate points.
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

-- Returns all intermediate points between 'from' and 'to' (inclusive
-- if intermediate, exclusive if start/finish), which are points
-- belonging to the path. Note: start and finish points are never
-- included in the returned list.
function path:get_points(from, to)
    check_point(from)
    check_point(to)
    check_same_path({self.start, from, to, self.finish})
    local points = {}
    local current_point = from ~= self.start and from or from.next
    while current_point and current_point ~= self.finish do
        table.insert(points, current_point)
        if current_point == to then
            break
        end
        current_point = current_point.next
    end
    return points
end

-- Picks a random intermediate point in the path and returns it.
-- Returns 'nil' if there are no intermediate points.
-- Note: start and finish are not considered intermediate points.
function path:random_intermediate_point()
    if self.intermediate_nr > 0 then
        return self:get_point(math.random(1, self.intermediate_nr))
    end
end

-- Checks if the point belongs to the path (as start, intermediate,
-- or finish point). All points are stored in self.points, so this
-- simply checks if the point exists in that table.
function path:point_in_path(p)
    return self.points[p] ~= nil
end

-- Checks if arguments passed to 'path:insert' are valid.
local function check_insert_between_arguments(self, p_prev, p_next, p)
    check_point(p)
    check_point(p_prev)
    check_point(p_next)
    check_same_path({self.start, p_prev, p_next, self.finish})
end

-- Inserts intermediate point 'p' between points 'p_prev' and 'p_next'.
-- 'p_prev' and 'p_next' need to belong to the path. The inserted point
-- is added to the path's points table.
function path:insert_between(p_prev, p_next, p)
    check_insert_between_arguments(self, p_prev, p_next, p)
    p:set_path(self)
    point.link(p_prev, p, p_next)
    self.intermediate_nr = self.intermediate_nr + 1
end

-- Inserts intermediate point 'p' at ordinal position 'nr' in the path.
-- 'nr' = 1 means inserting 'p' right after the start point.
-- 'nr' = intermediate_nr + 1 means inserting 'p' right before the
-- finish point.
function path:insert_at(nr, p)
    local p1 = self:get_point(nr - 1) or self.start
    local p2 = self:get_point(nr) or self.finish
    self:insert_between(p1, p2, p)
end

-- Inserts an intermediate point 'p' before point 'target'.
function path:insert_before(target, p)
    self:insert_between(target.previous, target, p)
end

-- Inserts an intermediate point 'p' after point 'target'.
function path:insert_after(target, p)
    self:insert_between(target, target.next, p)
end

-- Inserts an intermediate point 'p' before the finish point.
function path:insert(p)
    self:insert_at(self.intermediate_nr + 1, p)
end

-- Checks if arguments passed to 'path:remove', 'path:remove_before'
-- and 'path:remove_after' are valid. Only intermediate points can be
-- removed (not start or finish).
local function check_remove_arguments(self, p)
    if not self.points[p] then
        error("Path: p '"..shallow_dump(p).."' does not belong to the path.")
    end
    if p == self.start or p == self.finish then
        error("Path: cannot remove start or finish point.")
    end
    if self.intermediate_nr <= 0 then
        error("Path: there are no intermediate points to remove.")
    end
end

-- Removes intermediate point 'p' from the path. Cannot remove start
-- or finish points.
function path:remove(p)
    check_point(p)
    check_remove_arguments(self, p)
    point.link(p.previous, p.next)
    p:clear()
    self.intermediate_nr = self.intermediate_nr - 1
end

-- Removes the intermediate point that comes before point 'p'.
-- Cannot remove start or finish points.
function path:remove_previous(p)
    check_point(p)
    check_remove_arguments(self, p.previous)
    self:remove(p.previous)
end

-- Removes the intermediate point that comes after point 'p'.
-- Cannot remove start or finish points.
function path:remove_next(p)
    check_point(p)
    check_remove_arguments(self, p.next)
    self:remove(p.next)
end

-- Checks if arguments passed to 'path:remove_at' are valid,
local function check_remove_at_arguments(self, nr)
    if type(nr) ~= "number" then
        error("Path: nr '"..shallow_dump(nr).."' is not a number.")
    end
    local p = self:get_point(nr)
    if not p then
        error("Path: no intermediate point at nr '"..shallow_dump(nr).."'.")
    end
end

-- Removes an intermediate point given by its ordinal number 'nr'.
function path:remove_at(nr)
    check_remove_at_arguments(self, nr)
    local p = self:get_point(nr)
    self:remove(p)
end

-- Extends the path by adding 'p' at the end of the path.
-- 'p' becomes the new finish point, and the old finish becomes
-- an intermediate point.
function path:extend(p)
    check_point(p)
    local old_finish = self.finish
    self:set_finish(p)
    self:insert_before(self.finish, old_finish)
end

-- Shortens the path by removing the finish point and setting the
-- previous point as the new finish. Does nothing if there are no
-- intermediate points. Returns 'true' if the path was shortened,
-- 'false' otherwise.
function path:shorten()
    if self.intermediate_nr <= 0 then
        return false
    end
    local old_finish = self.finish
    local new_finish = self.finish.previous
    old_finish:clear()
    self.intermediate_nr = self.intermediate_nr - 1
    self.finish = new_finish
    self.finish:set_path(self)
    self.finish:unlink_from_next()
    return true
end

-- Shortens the path by 'nr' points. If 'nr' is bigger than the
-- number of intermediate points, the path is shortened as much
-- as possible.
function path:shorten_by(nr)
    for i = 1, nr do
        self:shorten()
    end
end

-- Cuts off (removes from the path) all points that come after the
-- point specified by 'stop_point'. Sets 'stop_point' as the new finish.
function path:cut_off(stop_point)
    check_point(stop_point)
    check_same_path({self.start, stop_point, self.finish})
    while self.finish ~= stop_point do
        if not self:shorten() then
            break
        end
    end
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
    local current_point = self.start
    while (current_point.next) do
        local v = current_point.next.pos - current_point.pos
        if vector.length(v) > segment_length then
            local new_segment = vector.normalize(v) * segment_length
            local new_point = point.new(current_point.pos + new_segment)
            self:insert_after(current_point, new_point)
        end
        current_point = current_point.next
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

-- Checks if arguments passed to 'path:split_at' are valid.
local function check_split_at_arguments(self, p)
    check_same_path({self.start, p, self.finish})
    -- check if 'p' is an intermediate point
    if p == self.start or p == self.finish then
        error("Path: cannot split path at start or finish point.")
    end
    if self.intermediate_nr < 1 then
        error("Path: cannot split path with less than one intermediate point.")
    end
end

-- Transfers all intermediate points between 'first' and 'last'
-- (inclusive) from 'self' path to 'pth' path. 'first' and 'last'
-- need to belong to this path. Only intermediate points are
-- transferred (not start or finish).
function path:transfer_points_to(pth, first, last)
    local points = self:get_points(first, last)
    for _, p in ipairs(points) do
        self:remove(p)
        pth:insert(p)
    end
end

-- Splits the path into two paths at point 'p' which needs to be an
-- intermediate point. 'p' gets duplicated so that it becomes the
-- finish point of the first path and the start point of the second
-- path. The path needs to have at least 1 intermediate point for the
-- split to be possible. Returns the newly created second path.
function path:split_at(p)
    check_point(p)
    check_split_at_arguments(self, p)
    local new_path = path.new(p:copy(), self.finish)
    self:transfer_points_to(new_path, p.next, self.finish.previous)
    self:set_finish(p)
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
        local p = point.new(pos)
        self:insert(p)
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
        local mid_point_pos = self.start.pos +
            vector.new(abs.z * sign.x, 0, abs.z * sign.z)
        if abs.x < abs.z then
            mid_point_pos = self.start.pos + vector.new(abs.x * sign.x, 0, abs.x * sign.z)
        end
        local mid_point = point.new(mid_point_pos)
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
