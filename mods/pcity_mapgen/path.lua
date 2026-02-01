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

-- Counter for generating unique point IDs. Ensures deterministic
-- ordering for points at the same position, as long as points are
-- created in the same order across environments.
local point_id_counter = 0

-- Counter for generating unique path IDs.
local path_id_counter = 0

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
    point_id_counter = point_id_counter + 1
    p.id = point_id_counter
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

-- ============================================================
-- COMPARATORS
-- ============================================================

-- Comparator for vectors. Compares by x, y, z in order.
-- Returns false for equal vectors (strict weak ordering).
function vector.comparator(v1, v2)
    if v1.x ~= v2.x then return v1.x < v2.x end
    if v1.y ~= v2.y then return v1.y < v2.y end
    if v1.z ~= v2.z then return v1.z < v2.z end
    return false
end

function point.equals(p1, p2)
    return vector.equals(p1.pos, p2.pos) and p1.id == p2.id
end

-- Comparator for points. Compares by position, then by ID.
-- Deterministic across Lua environments.
function point.comparator(p1, p2)
    if not vector.equals(p1.pos, p2.pos) then
        return vector.comparator(p1.pos, p2.pos)
    end
    return p1.id < p2.id
end

-- ============================================================
-- SORTING HELPERS
-- ============================================================

-- Returns a sorted copy of a table of points.
function point.sort(points)
    local sorted = {}
    for _, p in pairs(points) do
        table.insert(sorted, p)
    end
    table.sort(sorted, point.comparator)
    return sorted
end

-- Returns attached points in deterministic order.
function point:attached_sorted()
    return point.sort(self.attached)
end

-- Returns branches in deterministic order.
function point:branches_sorted()
    return path.sort(self.branches)
end

-- ============================================================
-- ITERATORS
-- ============================================================

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

-- ============================================================
-- PATH ASSIGNMENT AND BRANCHING
-- ============================================================

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
-- You're more likely to want to use 'path:remove' instead.
function point:clear()
    self:unlink()
    self:detach_all()
    self:unbranch_all()
    if self.path then
        self.path.points[self] = nil
    end
    self.path = nil
end

-- ============================================================
-- PATH CLASS
-- ============================================================

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
    path_id_counter = path_id_counter + 1
    pth.id = path_id_counter
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

-- Comparator for paths. Compares by start, finish, intermediate
-- points, then by ID. Deterministic across Lua environments.
function path.comparator(pth1, pth2)
    -- Compare start points
    if not point.equals(pth1.start, pth2.start) then
        return point.comparator(pth1.start, pth2.start)
    end
    -- Compare finish points
    if not point.equals(pth1.finish, pth2.finish) then
        return point.comparator(pth1.finish, pth2.finish)
    end
    -- Compare number of intermediate points
    if pth1.intermediate_nr ~= pth2.intermediate_nr then
        return pth1.intermediate_nr < pth2.intermediate_nr
    end
    -- Compare each intermediate point position
    local p1 = pth1.start.next
    local p2 = pth2.start.next
    while p1 and p1 ~= pth1.finish and p2 and p2 ~= pth2.finish do
        if not point.equals(p1, p2) then
            return point.comparator(p1, p2)
        end
        p1 = p1.next
        p2 = p2.next
    end
    -- Use ID as final tiebreaker
    return pth1.id < pth2.id
end

-- Returns a sorted copy of a table of paths.
function path.sort(paths)
    local sorted = {}
    for _, pth in pairs(paths) do
        table.insert(sorted, pth)
    end
    table.sort(sorted, path.comparator)
    return sorted
end

-- Returns branching points in deterministic order (path order).
function path:branching_points_sorted()
    local result = {}
    for _, p in ipairs(self:all_points()) do
        if self.branching_points[p] then
            table.insert(result, p)
        end
    end
    return result
end

-- ============================================================
-- INTERMEDIATE COUNT HELPERS
-- ============================================================

-- Recomputes intermediate_nr by traversing the linked list.
-- Use this to recover from any potential desync situations.
function path:recompute_intermediate_nr()
    local count = 0
    local current = self.start and self.start.next
    while current and current ~= self.finish do
        count = count + 1
        current = current.next
    end
    self.intermediate_nr = count
    return count
end

-- Validates that intermediate_nr matches the actual linked list state.
-- Returns true if consistent, false otherwise.
-- Optionally repairs the count if 'repair' is true.
function path:validate_intermediate_nr(repair)
    local actual_count = 0
    local current = self.start and self.start.next
    while current and current ~= self.finish do
        actual_count = actual_count + 1
        current = current.next
    end
    local is_valid = (self.intermediate_nr == actual_count)
    if not is_valid and repair then
        self.intermediate_nr = actual_count
    end
    return is_valid, self.intermediate_nr, actual_count
end

-- ============================================================
-- START AND FINISH
-- ============================================================

-- Sets the start point of the path to 'p'. The start point is added
-- to the path's points table.
function path:set_start(p)
    check_point(p)
    local old_start = self.start
    local first_intermediate = old_start and old_start.next
    -- Unlink and remove old start from points table
    if old_start then
        old_start:unlink()
        self.points[old_start] = nil
    end
    self.start = p
    self.start:set_path(self)
    self.start:unlink()
    -- Link new start to existing chain
    if first_intermediate and first_intermediate ~= self.finish then
        point.link(self.start, first_intermediate)
    elseif self.finish then
        point.link(self.start, self.finish)
    end
end

-- Sets the finish point of the path to 'p'. The finish point is added
-- to the path's points table.
function path:set_finish(p)
    check_point(p)
    local old_finish = self.finish
    local last_intermediate = old_finish and old_finish.previous
    -- Unlink and remove old finish from points table
    if old_finish then
        old_finish:unlink()
        self.points[old_finish] = nil
    end
    self.finish = p
    self.finish:set_path(self)
    self.finish:unlink()
    -- Link new finish to existing chain
    if last_intermediate and last_intermediate ~= self.start then
        point.link(last_intermediate, self.finish)
    elseif self.start then
        point.link(self.start, self.finish)
    end
end

-- ============================================================
-- POINT RETRIEVAL
-- ============================================================

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

-- ============================================================
-- INSERTION
-- ============================================================

-- Checks if arguments passed to 'path:insert' are valid.
local function check_insert_between_arguments(self, p_prev, p_next, p)
    check_point(p)
    check_point(p_prev)
    check_point(p_next)
    check_same_path({self.start, p_prev, p_next, self.finish})
    -- Verify that p_prev and p_next are actually adjacent
    if p_prev.next ~= p_next then
        error("Path: p_prev and p_next are not adjacent points.")
    end
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

-- ============================================================
-- REMOVAL
-- ============================================================

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
    local prev = p.previous
    local nxt = p.next
    -- Link neighbors before clearing to maintain chain integrity
    if prev and nxt then
        prev.next = nxt
        nxt.previous = prev
    end
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

-- ============================================================
-- EXTEND AND SHORTEN
-- ============================================================

-- Extends the path by adding 'p' at the end of the path.
-- 'p' becomes the new finish point, and the old finish becomes
-- an intermediate point.
function path:extend(p)
    check_point(p)
    local old_finish = self.finish
    -- Set up new finish
    p:set_path(self)
    p:unlink()
    point.link(old_finish, p)
    self.finish = p
    -- old_finish is now an intermediate point
    self.intermediate_nr = self.intermediate_nr + 1
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
    local new_finish = old_finish.previous
    old_finish:clear()
    self.intermediate_nr = self.intermediate_nr - 1
    self.finish = new_finish
    self.finish.next = nil  -- ensure new finish doesn't point to anything
    return true
end

-- Shortens the path by 'nr' points. If 'nr' is bigger than the
-- number of intermediate points, the path is shortened as much
-- as possible.
function path:shorten_by(nr)
    for i = 1, nr do
        if not self:shorten() then
            break
        end
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

-- ============================================================
-- ALL POINTS AND POSITIONS
-- ============================================================

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

-- ============================================================
-- LENGTH AND GEOMETRY
-- ============================================================

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

-- ============================================================
-- SUBDIVIDE AND UNSUBDIVIDE
-- ============================================================

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
            -- After removal, continue from the same prev point
            mid = prev.next
            nxt = mid and mid.next
        else
            prev = mid
            mid = prev.next
            nxt = mid and mid.next
        end
    end
end

-- ============================================================
-- SPLIT AND TRANSFER
-- ============================================================

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
    -- Create new path with duplicated point 'p'
    local p_copy = p:copy()
    local new_path = path.new(p_copy, self.finish)
    -- Transfer points from 'p.next' to 'self.finish' to the new path
    if p.next and p.next ~= self.finish then
        self:transfer_points_to(new_path, p.next, self.finish.previous)
    end
    -- Update finish of the original path to 'p'
    self:set_finish(p)
    return new_path
end

-- ============================================================
-- CLEAR INTERMEDIATE
-- ============================================================

-- Clears all intermediate points from the path, leaving only start
-- and finish. Properly updates intermediate_nr.
function path:clear_intermediate()
    while self.intermediate_nr > 0 do
        local p = self:get_point(1)
        if p then
            self:remove(p)
        else
            -- Safety: if get_point returns nil but count > 0, recompute
            self:recompute_intermediate_nr()
            break
        end
    end
end

-- ============================================================
-- PATH SHAPE GENERATORS
-- ============================================================

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

-- ============================================================
-- UNIT TESTS
-- ============================================================

pcmg.tests.path = {}
local tests = pcmg.tests.path

function tests.run_all()
    tests.test_intermediate_nr_consistency()
    tests.test_split_preserves_count()
    tests.test_extend_shorten_count()
    tests.test_unsubdivide_count()
    -- Point class tests
    tests.test_point_new()
    tests.test_point_check()
    tests.test_point_copy()
    tests.test_point_same_path()
    tests.test_point_link()
    tests.test_point_unlink_from_previous()
    tests.test_point_unlink_from_next()
    tests.test_point_unlink()
    tests.test_point_attach()
    tests.test_point_detach()
    tests.test_point_detach_all()
    tests.test_point_set_position()
    tests.test_point_equals()
    tests.test_point_comparator()
    tests.test_point_sort()
    tests.test_point_attached_sorted()
    tests.test_point_branches_sorted()
    tests.test_point_iterator()
    tests.test_point_reverse_iterator()
    tests.test_point_set_path()
    tests.test_point_branch()
    tests.test_point_has_branches()
    tests.test_point_unbranch()
    tests.test_point_unbranch_all()
    tests.test_point_clear()
    -- Path class tests
    tests.test_path_new()
    tests.test_path_check()
    tests.test_path_comparator()
    tests.test_path_sort()
    tests.test_path_branching_points_sorted()
    tests.test_path_recompute_intermediate_nr()
    tests.test_path_validate_intermediate_nr()
    tests.test_path_set_start()
    tests.test_path_set_finish()
    tests.test_path_get_point()
    tests.test_path_get_points()
    tests.test_path_random_intermediate_point()
    tests.test_path_point_in_path()
    tests.test_path_insert_between()
    tests.test_path_insert_at()
    tests.test_path_insert_before()
    tests.test_path_insert_after()
    tests.test_path_insert()
    tests.test_path_remove()
    tests.test_path_remove_previous()
    tests.test_path_remove_next()
    tests.test_path_remove_at()
    tests.test_path_extend()
    tests.test_path_shorten()
    tests.test_path_shorten_by()
    tests.test_path_cut_off()
    tests.test_path_all_points()
    tests.test_path_all_positions()
    tests.test_path_length()
    tests.test_path_subdivide()
    tests.test_path_unsubdivide()
    tests.test_path_split_at()
    tests.test_path_transfer_points_to()
    tests.test_path_clear_intermediate()
    tests.test_path_make_straight()
    tests.test_path_make_wave()
    tests.test_path_make_slanted()
    tests.test_vector_comparator()
end

-- Test that intermediate_nr stays consistent through various operations
function tests.test_intermediate_nr_consistency()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    assert(pth.intermediate_nr == 0, "Initial intermediate_nr should be 0")
    
    -- Insert some points
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    
    assert(pth.intermediate_nr == 3, "After 3 inserts, intermediate_nr should be 3")
    
    local valid, cached, actual = pth:validate_intermediate_nr(false)
    assert(valid, "intermediate_nr should match actual count")
    
    -- Remove a point
    pth:remove_at(2)
    assert(pth.intermediate_nr == 2, "After removal, intermediate_nr should be 2")
    
    valid, cached, actual = pth:validate_intermediate_nr(false)
    assert(valid, "intermediate_nr should still match after removal")
end

-- Test that split_at preserves correct counts
function tests.test_split_preserves_count()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    pth:insert(point.new(vector.new(8, 0, 0)))
    
    local split_point = pth:get_point(2) -- point at (4,0,0)
    local new_path = pth:split_at(split_point)
    
    local valid1, cached1, actual1 = pth:validate_intermediate_nr(false)
    local valid2, cached2, actual2 = new_path:validate_intermediate_nr(false)
    
    assert(valid1, "Original path intermediate_nr should be valid after split")
    assert(valid2, "New path intermediate_nr should be valid after split")
end

-- Test extend and shorten maintain count
function tests.test_extend_shorten_count()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    assert(pth.intermediate_nr == 0, "Initial count should be 0")
    
    pth:extend(point.new(vector.new(20, 0, 0)))
    assert(pth.intermediate_nr == 1, "After extend, old finish becomes intermediate")
    
    local valid = pth:validate_intermediate_nr(false)
    assert(valid, "Count should be valid after extend")
    
    pth:shorten()
    assert(pth.intermediate_nr == 0, "After shorten, count should be 0")
    
    valid = pth:validate_intermediate_nr(false)
    assert(valid, "Count should be valid after shorten")
end

-- Test unsubdivide maintains count
function tests.test_unsubdivide_count()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    -- Create a straight line with multiple points
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    pth:insert(point.new(vector.new(8, 0, 0)))
    
    assert(pth.intermediate_nr == 4, "Should have 4 intermediate points")
    
    -- Unsubdivide with a small angle (should remove collinear points)
    pth:unsubdivide(0.1)
    
    local valid = pth:validate_intermediate_nr(false)
    assert(valid, "Count should be valid after unsubdivide")
end

-- ============================================================
-- POINT CLASS UNIT TESTS
-- ============================================================

-- Tests that point.new creates a point with correct position and unique ID
function tests.test_point_new()
    local pos = vector.new(5, 10, 15)
    local p = point.new(pos)
    
    assert(p.pos.x == 5, "Point x coordinate should be 5")
    assert(p.pos.y == 10, "Point y coordinate should be 10")
    assert(p.pos.z == 15, "Point z coordinate should be 15")
    assert(p.id ~= nil, "Point should have an ID")
    assert(p.path == nil, "New point should not belong to a path")
    assert(p.previous == nil, "New point should have no previous link")
    assert(p.next == nil, "New point should have no next link")
    
    -- Test that IDs are unique
    local p2 = point.new(vector.new(0, 0, 0))
    assert(p2.id ~= p.id, "Points should have unique IDs")
end

-- Tests that point.check correctly identifies point objects
function tests.test_point_check()
    local p = point.new(vector.new(0, 0, 0))
    
    assert(point.check(p) == true, "point.check should return true for a point")
    assert(point.check({}) == false, "point.check should return false for a table")
    assert(point.check("string") == false, "point.check should return false for a string")
    assert(point.check(nil) == false, "point.check should return false for nil")
end

-- Tests that point:copy creates a new point with same position but no links
function tests.test_point_copy()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    local p_copy = p_mid:copy()
    
    assert(vector.equals(p_copy.pos, p_mid.pos), "Copy should have same position")
    assert(p_copy.id ~= p_mid.id, "Copy should have different ID")
    assert(p_copy.path == nil, "Copy should not belong to any path")
    assert(p_copy.previous == nil, "Copy should have no previous link")
    assert(p_copy.next == nil, "Copy should have no next link")
end

-- Tests that point.same_path correctly identifies points on the same path
function tests.test_point_same_path()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p3 = point.new(vector.new(5, 0, 0))
    pth:insert(p3)
    
    assert(point.same_path(p1, p2, p3) == true, "All points should be on same path")
    
    -- Create another path
    local p4 = point.new(vector.new(0, 0, 0))
    local p5 = point.new(vector.new(10, 0, 0))
    local pth2 = path.new(p4, p5)
    
    assert(point.same_path(p1, p4) == false, "Points from different paths should return false")
end

-- Tests that point.link correctly links multiple points in order
function tests.test_point_link()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(5, 0, 0))
    local p3 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p3)
    p2:set_path(pth)
    
    point.link(p1, p2, p3)
    
    assert(p1.next == p2, "p1.next should be p2")
    assert(p2.previous == p1, "p2.previous should be p1")
    assert(p2.next == p3, "p2.next should be p3")
    assert(p3.previous == p2, "p3.previous should be p2")
end

-- Tests that point:unlink_from_previous correctly severs the previous link
function tests.test_point_unlink_from_previous()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    p_mid:unlink_from_previous()
    
    assert(p_mid.previous == nil, "p_mid.previous should be nil after unlink")
    assert(p1.next == nil, "p1.next should be nil after unlink")
end

-- Tests that point:unlink_from_next correctly severs the next link
function tests.test_point_unlink_from_next()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    p_mid:unlink_from_next()
    
    assert(p_mid.next == nil, "p_mid.next should be nil after unlink")
    assert(p2.previous == nil, "p2.previous should be nil after unlink")
end

-- Tests that point:unlink correctly severs both previous and next links
function tests.test_point_unlink()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    p_mid:unlink()
    
    assert(p_mid.previous == nil, "p_mid.previous should be nil")
    assert(p_mid.next == nil, "p_mid.next should be nil")
    assert(p1.next == nil, "p1.next should be nil")
    assert(p2.previous == nil, "p2.previous should be nil")
end

-- Tests that point:attach shares position between attached points
function tests.test_point_attach()
    local p1 = point.new(vector.new(5, 5, 5))
    local p2 = point.new(vector.new(0, 0, 0))
    local p3 = point.new(vector.new(10, 10, 10))
    
    p1:attach(p2, p3)
    
    -- Attached points should share the same position reference
    assert(p2.pos == p1.pos, "p2 should share position with p1")
    assert(p3.pos == p1.pos, "p3 should share position with p1")
    assert(p1.attached[p2] == p2, "p2 should be in p1's attached table")
    assert(p1.attached[p3] == p3, "p3 should be in p1's attached table")
    assert(p2.attached[p1] == p1, "p1 should be in p2's attached table")
end

-- Tests that point:detach removes attachment relationship
function tests.test_point_detach()
    local p1 = point.new(vector.new(5, 5, 5))
    local p2 = point.new(vector.new(0, 0, 0))
    local p3 = point.new(vector.new(10, 10, 10))
    
    p1:attach(p2, p3)
    p1:detach(p2)
    
    assert(p1.attached[p2] == nil, "p2 should be removed from p1's attached table")
    assert(p2.attached[p1] == nil, "p1 should be removed from p2's attached table")
    assert(p1.attached[p3] == p3, "p3 should still be attached to p1")
end

-- Tests that point:detach_all removes all attachments
function tests.test_point_detach_all()
    local p1 = point.new(vector.new(5, 5, 5))
    local p2 = point.new(vector.new(0, 0, 0))
    local p3 = point.new(vector.new(10, 10, 10))
    
    p1:attach(p2, p3)
    p1:detach_all()
    
    assert(next(p1.attached) == nil, "p1's attached table should be empty")
    assert(p2.attached[p1] == nil, "p1 should be removed from p2's attached table")
    assert(p3.attached[p1] == nil, "p1 should be removed from p3's attached table")
end

-- Tests that point:set_position updates position for all attached points
function tests.test_point_set_position()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 10, 10))
    
    p1:attach(p2)
    p1:set_position(vector.new(100, 200, 300))
    
    assert(p1.pos.x == 100, "p1.x should be 100")
    assert(p1.pos.y == 200, "p1.y should be 200")
    assert(p1.pos.z == 300, "p1.z should be 300")
    assert(p2.pos == p1.pos, "p2 should share the updated position")
end

-- Tests that point.equals correctly compares points by position and ID
function tests.test_point_equals()
    local p1 = point.new(vector.new(5, 5, 5))
    local p2 = point.new(vector.new(5, 5, 5))
    local p3 = point.new(vector.new(10, 10, 10))
    
    -- Same point should equal itself
    assert(point.equals(p1, p1) == true, "Point should equal itself")
    
    -- Different points with same position should not be equal (different IDs)
    assert(point.equals(p1, p2) == false, "Points with same pos but different ID should not be equal")
    
    -- Different positions should not be equal
    assert(point.equals(p1, p3) == false, "Points with different positions should not be equal")
end

-- Tests that point.comparator provides deterministic ordering
function tests.test_point_comparator()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(5, 0, 0))
    local p3 = point.new(vector.new(0, 5, 0))
    local p4 = point.new(vector.new(0, 0, 5))
    
    -- Compare by x first
    assert(point.comparator(p1, p2) == true, "p1 should come before p2 (x comparison)")
    
    -- Compare by y when x is equal
    assert(point.comparator(p1, p3) == true, "p1 should come before p3 (y comparison)")
    
    -- Compare by z when x and y are equal
    assert(point.comparator(p1, p4) == true, "p1 should come before p4 (z comparison)")
    
    -- Same position, compare by ID
    local p5 = point.new(vector.new(0, 0, 0))
    assert(point.comparator(p1, p5) == true, "p1 should come before p5 (ID comparison)")
end

-- Tests that point.sort returns points in deterministic order
function tests.test_point_sort()
    local p3 = point.new(vector.new(10, 0, 0))
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(5, 0, 0))
    
    local points = {p3, p1, p2}
    local sorted = point.sort(points)
    
    assert(sorted[1] == p1, "First point should be at x=0")
    assert(sorted[2] == p2, "Second point should be at x=5")
    assert(sorted[3] == p3, "Third point should be at x=10")
end

-- Tests that point:attached_sorted returns attached points in order
function tests.test_point_attached_sorted()
    local p1 = point.new(vector.new(5, 5, 5))
    local p2 = point.new(vector.new(0, 0, 0))
    local p3 = point.new(vector.new(10, 10, 10))
    
    p1:attach(p3, p2)  -- attach in reverse order
    
    local sorted = p1:attached_sorted()
    
    -- Should be sorted by position/ID
    assert(#sorted == 2, "Should have 2 attached points")
end

-- Tests that point:branches_sorted returns branches in deterministic order
function tests.test_point_branches_sorted()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    -- Create branches
    local branch1_end = point.new(vector.new(5, 10, 0))
    local branch2_end = point.new(vector.new(5, 5, 0))
    
    p_mid:branch(branch1_end)
    p_mid:branch(branch2_end)
    
    local sorted = p_mid:branches_sorted()
    
    assert(#sorted == 2, "Should have 2 branches")
end

-- Tests that point:iterator traverses forward through linked points
function tests.test_point_iterator()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    
    local count = 0
    local positions = {}
    for i, p in p1:iterator() do
        count = count + 1
        table.insert(positions, p.pos.x)
    end
    
    assert(count == 4, "Iterator should visit 4 points after start")
    assert(positions[1] == 2, "First visited should be at x=2")
    assert(positions[2] == 4, "Second visited should be at x=4")
    assert(positions[3] == 6, "Third visited should be at x=6")
    assert(positions[4] == 10, "Fourth visited should be at x=10 (finish)")
end

-- Tests that point:reverse_iterator traverses backward through linked points
function tests.test_point_reverse_iterator()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    
    local count = 0
    local positions = {}
    for i, p in p2:reverse_iterator() do
        count = count + 1
        table.insert(positions, p.pos.x)
    end
    
    assert(count == 4, "Reverse iterator should visit 4 points before finish")
    assert(positions[1] == 6, "First visited should be at x=6")
    assert(positions[2] == 4, "Second visited should be at x=4")
    assert(positions[3] == 2, "Third visited should be at x=2")
    assert(positions[4] == 0, "Fourth visited should be at x=0 (start)")
end

-- Tests that point:set_path correctly assigns point to path
function tests.test_point_set_path()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p3 = point.new(vector.new(5, 0, 0))
    p3:set_path(pth)
    
    assert(p3.path == pth, "Point should be assigned to path")
    assert(pth.points[p3] == p3, "Path should contain point in points table")
end

-- Tests that point:branch creates a new path branching from this point
function tests.test_point_branch()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    local branch_end = point.new(vector.new(5, 10, 0))
    local branch = p_mid:branch(branch_end)
    
    assert(path.check(branch), "Branch should be a path")
    assert(branch.finish == branch_end, "Branch finish should be branch_end")
    assert(p_mid.branches[branch] == branch, "Branch should be in point's branches table")
    assert(pth.branching_points[p_mid] == p_mid, "Point should be marked as branching point")
    assert(p_mid.attached[branch.start] == branch.start, "Branch start should be attached to branching point")
end

-- Tests that point:has_branches correctly detects branches
function tests.test_point_has_branches()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    assert(p_mid:has_branches() == false, "Point should have no branches initially")
    
    local branch_end = point.new(vector.new(5, 10, 0))
    p_mid:branch(branch_end)
    
    assert(p_mid:has_branches() == true, "Point should have branches after branching")
end

-- Tests that point:unbranch removes a specific branch
function tests.test_point_unbranch()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    local branch1_end = point.new(vector.new(5, 10, 0))
    local branch2_end = point.new(vector.new(5, 5, 0))
    local branch1 = p_mid:branch(branch1_end)
    local branch2 = p_mid:branch(branch2_end)
    
    p_mid:unbranch(branch1)
    
    assert(p_mid.branches[branch1] == nil, "Branch1 should be removed")
    assert(p_mid.branches[branch2] == branch2, "Branch2 should still exist")
    assert(pth.branching_points[p_mid] == p_mid, "Point should still be a branching point")
    
    p_mid:unbranch(branch2)
    assert(pth.branching_points[p_mid] == nil, "Point should no longer be a branching point")
end

-- Tests that point:unbranch_all removes all branches
function tests.test_point_unbranch_all()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    local branch1_end = point.new(vector.new(5, 10, 0))
    local branch2_end = point.new(vector.new(5, 5, 0))
    p_mid:branch(branch1_end)
    p_mid:branch(branch2_end)
    
    p_mid:unbranch_all()
    
    assert(next(p_mid.branches) == nil, "All branches should be removed")
    assert(pth.branching_points[p_mid] == nil, "Point should no longer be a branching point")
end

-- Tests that point:clear removes all links, attachments, and branches
function tests.test_point_clear()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(5, 0, 0))
    pth:insert(p_mid)
    
    local p_attached = point.new(vector.new(5, 0, 0))
    p_mid:attach(p_attached)
    
    local branch_end = point.new(vector.new(5, 10, 0))
    p_mid:branch(branch_end)
    
    p_mid:clear()
    
    assert(p_mid.previous == nil, "previous should be nil after clear")
    assert(p_mid.next == nil, "next should be nil after clear")
    assert(next(p_mid.attached) == nil, "attached should be empty after clear")
    assert(next(p_mid.branches) == nil, "branches should be empty after clear")
    assert(p_mid.path == nil, "path should be nil after clear")
end

-- ============================================================
-- PATH CLASS UNIT TESTS
-- ============================================================

-- Tests that path.new creates a path with start and finish points
function tests.test_path_new()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    assert(pth.start == p1, "Path start should be p1")
    assert(pth.finish == p2, "Path finish should be p2")
    assert(pth.intermediate_nr == 0, "Initial intermediate_nr should be 0")
    assert(pth.id ~= nil, "Path should have an ID")
    assert(p1.path == pth, "Start point should belong to path")
    assert(p2.path == pth, "Finish point should belong to path")
    assert(p1.next == p2, "Start should link to finish")
    assert(p2.previous == p1, "Finish should link back to start")
end

-- Tests that path.check correctly identifies path objects
function tests.test_path_check()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    assert(path.check(pth) == true, "path.check should return true for a path")
    assert(path.check({}) == false, "path.check should return false for a table")
    assert(path.check("string") == false, "path.check should return false for a string")
    assert(path.check(nil) == false, "path.check should return false for nil")
end

-- Tests that path.comparator provides deterministic ordering
function tests.test_path_comparator()
    local pth1 = path.new(point.new(vector.new(0, 0, 0)), point.new(vector.new(10, 0, 0)))
    local pth2 = path.new(point.new(vector.new(5, 0, 0)), point.new(vector.new(15, 0, 0)))
    local pth3 = path.new(point.new(vector.new(0, 0, 0)), point.new(vector.new(20, 0, 0)))
    
    -- Compare by start position first
    assert(path.comparator(pth1, pth2) == true, "pth1 should come before pth2 (start comparison)")
    
    -- Same start, compare by finish
    assert(path.comparator(pth1, pth3) == true, "pth1 should come before pth3 (finish comparison)")
end

-- Tests that path.sort returns paths in deterministic order
function tests.test_path_sort()
    local pth3 = path.new(point.new(vector.new(10, 0, 0)), point.new(vector.new(20, 0, 0)))
    local pth1 = path.new(point.new(vector.new(0, 0, 0)), point.new(vector.new(10, 0, 0)))
    local pth2 = path.new(point.new(vector.new(5, 0, 0)), point.new(vector.new(15, 0, 0)))
    
    local paths = {pth3, pth1, pth2}
    local sorted = path.sort(paths)
    
    assert(sorted[1] == pth1, "First path should start at x=0")
    assert(sorted[2] == pth2, "Second path should start at x=5")
    assert(sorted[3] == pth3, "Third path should start at x=10")
end

-- Tests that path:branching_points_sorted returns branching points in path order
function tests.test_path_branching_points_sorted()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local p_mid1 = point.new(vector.new(3, 0, 0))
    local p_mid2 = point.new(vector.new(7, 0, 0))
    pth:insert(p_mid1)
    pth:insert(p_mid2)
    
    -- Create branches in reverse order
    p_mid2:branch(point.new(vector.new(7, 10, 0)))
    p_mid1:branch(point.new(vector.new(3, 10, 0)))
    
    local sorted = pth:branching_points_sorted()
    
    assert(#sorted == 2, "Should have 2 branching points")
    assert(sorted[1] == p_mid1, "First branching point should be p_mid1")
    assert(sorted[2] == p_mid2, "Second branching point should be p_mid2")
end

-- Tests that path:recompute_intermediate_nr correctly counts intermediate points
function tests.test_path_recompute_intermediate_nr()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    
    -- Manually corrupt the count
    pth.intermediate_nr = 999
    
    local count = pth:recompute_intermediate_nr()
    
    assert(count == 3, "Recomputed count should be 3")
    assert(pth.intermediate_nr == 3, "intermediate_nr should be corrected to 3")
end

-- Tests that path:validate_intermediate_nr detects and optionally repairs inconsistencies
function tests.test_path_validate_intermediate_nr()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(5, 0, 0)))
    
    local valid, cached, actual = pth:validate_intermediate_nr(false)
    assert(valid == true, "Count should be valid initially")
    
    -- Corrupt the count
    pth.intermediate_nr = 10
    
    valid, cached, actual = pth:validate_intermediate_nr(false)
    assert(valid == false, "Count should be invalid after corruption")
    assert(cached == 10, "Cached value should be 10")
    assert(actual == 1, "Actual value should be 1")
    
    -- Repair
    valid, cached, actual = pth:validate_intermediate_nr(true)
    assert(pth.intermediate_nr == 1, "Count should be repaired to 1")
end

-- Tests that path:set_start replaces the start point
function tests.test_path_set_start()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(5, 0, 0)))
    
    local new_start = point.new(vector.new(-5, 0, 0))
    pth:set_start(new_start)
    
    assert(pth.start == new_start, "Start should be new_start")
    assert(new_start.path == pth, "New start should belong to path")
    assert(new_start.next.pos.x == 5, "New start should link to first intermediate")
end

-- Tests that path:set_finish replaces the finish point
function tests.test_path_set_finish()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(5, 0, 0)))
    
    local new_finish = point.new(vector.new(20, 0, 0))
    pth:set_finish(new_finish)
    
    assert(pth.finish == new_finish, "Finish should be new_finish")
    assert(new_finish.path == pth, "New finish should belong to path")
    assert(new_finish.previous.pos.x == 5, "New finish should link from last intermediate")
end

-- Tests that path:get_point returns the correct intermediate point by index
function tests.test_path_get_point()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(2, 0, 0))
    local mid2 = point.new(vector.new(4, 0, 0))
    local mid3 = point.new(vector.new(6, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    assert(pth:get_point(1) == mid1, "get_point(1) should return first intermediate")
    assert(pth:get_point(2) == mid2, "get_point(2) should return second intermediate")
    assert(pth:get_point(3) == mid3, "get_point(3) should return third intermediate")
    assert(pth:get_point(0) == nil, "get_point(0) should return nil")
    assert(pth:get_point(4) == nil, "get_point(4) should return nil (out of range)")
end

-- Tests that path:get_points returns intermediate points in a range
function tests.test_path_get_points()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(2, 0, 0))
    local mid2 = point.new(vector.new(4, 0, 0))
    local mid3 = point.new(vector.new(6, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    local points = pth:get_points(mid1, mid3)
    
    assert(#points == 3, "Should return 3 intermediate points")
    assert(points[1] == mid1, "First should be mid1")
    assert(points[2] == mid2, "Second should be mid2")
    assert(points[3] == mid3, "Third should be mid3")
    
    -- Test from start (exclusive)
    points = pth:get_points(p1, mid2)
    assert(#points == 2, "Should return 2 points when starting from start")
    assert(points[1] == mid1, "First should be mid1")
    assert(points[2] == mid2, "Second should be mid2")
end

-- Tests that path:random_intermediate_point returns a valid intermediate point
function tests.test_path_random_intermediate_point()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    -- No intermediate points
    assert(pth:random_intermediate_point() == nil, "Should return nil with no intermediates")
    
    local mid1 = point.new(vector.new(2, 0, 0))
    local mid2 = point.new(vector.new(4, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    
    local random_point = pth:random_intermediate_point()
    assert(random_point == mid1 or random_point == mid2, "Should return one of the intermediate points")
    assert(random_point ~= p1 and random_point ~= p2, "Should not return start or finish")
end

-- Tests that path:point_in_path correctly checks if point belongs to path
function tests.test_path_point_in_path()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(5, 0, 0))
    pth:insert(mid)
    
    local outside = point.new(vector.new(100, 100, 100))
    
    assert(pth:point_in_path(p1) == true, "Start should be in path")
    assert(pth:point_in_path(p2) == true, "Finish should be in path")
    assert(pth:point_in_path(mid) == true, "Intermediate should be in path")
    assert(pth:point_in_path(outside) == false, "Outside point should not be in path")
end

-- Tests that path:insert_between inserts a point between two adjacent points
function tests.test_path_insert_between()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(5, 0, 0))
    pth:insert_between(p1, p2, mid)
    
    assert(pth.intermediate_nr == 1, "Should have 1 intermediate point")
    assert(p1.next == mid, "p1.next should be mid")
    assert(mid.previous == p1, "mid.previous should be p1")
    assert(mid.next == p2, "mid.next should be p2")
    assert(p2.previous == mid, "p2.previous should be mid")
end

-- Tests that path:insert_at inserts a point at a specific ordinal position
function tests.test_path_insert_at()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(3, 0, 0)))
    pth:insert(point.new(vector.new(7, 0, 0)))
    
    local mid = point.new(vector.new(5, 0, 0))
    pth:insert_at(2, mid)
    
    assert(pth.intermediate_nr == 3, "Should have 3 intermediate points")
    assert(pth:get_point(2) == mid, "Point at position 2 should be mid")
end

-- Tests that path:insert_before inserts a point before target
function tests.test_path_insert_before()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(5, 0, 0))
    pth:insert(mid1)
    
    local mid2 = point.new(vector.new(3, 0, 0))
    pth:insert_before(mid1, mid2)
    
    assert(pth.intermediate_nr == 2, "Should have 2 intermediate points")
    assert(mid2.next == mid1, "mid2.next should be mid1")
    assert(mid1.previous == mid2, "mid1.previous should be mid2")
end

-- Tests that path:insert_after inserts a point after target
function tests.test_path_insert_after()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(5, 0, 0))
    pth:insert(mid1)
    
    local mid2 = point.new(vector.new(7, 0, 0))
    pth:insert_after(mid1, mid2)
    
    assert(pth.intermediate_nr == 2, "Should have 2 intermediate points")
    assert(mid1.next == mid2, "mid1.next should be mid2")
    assert(mid2.previous == mid1, "mid2.previous should be mid1")
end

-- Tests that path:insert appends a point before finish
function tests.test_path_insert()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(5, 0, 0))
    pth:insert(mid)
    
    assert(pth.intermediate_nr == 1, "Should have 1 intermediate point")
    assert(mid.next == p2, "Inserted point should link to finish")
    assert(p2.previous == mid, "Finish should link back to inserted point")
end

-- Tests that path:remove removes an intermediate point
function tests.test_path_remove()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(3, 0, 0))
    local mid2 = point.new(vector.new(5, 0, 0))
    local mid3 = point.new(vector.new(7, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    pth:remove(mid2)
    
    assert(pth.intermediate_nr == 2, "Should have 2 intermediate points")
    assert(mid1.next == mid3, "mid1 should now link to mid3")
    assert(mid3.previous == mid1, "mid3 should link back to mid1")
    assert(pth:point_in_path(mid2) == false, "mid2 should no longer be in path")
end

-- Tests that path:remove_previous removes the point before target
function tests.test_path_remove_previous()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(3, 0, 0))
    local mid2 = point.new(vector.new(7, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    
    pth:remove_previous(mid2)
    
    assert(pth.intermediate_nr == 1, "Should have 1 intermediate point")
    assert(pth:get_point(1) == mid2, "Only mid2 should remain")
end

-- Tests that path:remove_next removes the point after target
function tests.test_path_remove_next()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(3, 0, 0))
    local mid2 = point.new(vector.new(7, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    
    pth:remove_next(mid1)
    
    assert(pth.intermediate_nr == 1, "Should have 1 intermediate point")
    assert(pth:get_point(1) == mid1, "Only mid1 should remain")
end

-- Tests that path:remove_at removes the point at a specific ordinal position
function tests.test_path_remove_at()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(3, 0, 0))
    local mid2 = point.new(vector.new(5, 0, 0))
    local mid3 = point.new(vector.new(7, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    pth:remove_at(2)
    
    assert(pth.intermediate_nr == 2, "Should have 2 intermediate points")
    assert(pth:get_point(1) == mid1, "First should be mid1")
    assert(pth:get_point(2) == mid3, "Second should be mid3")
end

-- Tests that path:extend adds a new finish point
function tests.test_path_extend()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local new_finish = point.new(vector.new(20, 0, 0))
    pth:extend(new_finish)
    
    assert(pth.finish == new_finish, "Finish should be new_finish")
    assert(pth.intermediate_nr == 1, "Old finish should become intermediate")
    assert(pth:get_point(1) == p2, "p2 should now be intermediate")
    assert(p2.next == new_finish, "p2 should link to new finish")
end

-- Tests that path:shorten removes the finish and promotes last intermediate
function tests.test_path_shorten()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(5, 0, 0))
    pth:insert(mid)
    
    local result = pth:shorten()
    
    assert(result == true, "Shorten should return true on success")
    assert(pth.finish == mid, "mid should become new finish")
    assert(pth.intermediate_nr == 0, "Should have no intermediate points")
    
    -- Cannot shorten further
    result = pth:shorten()
    assert(result == false, "Shorten should return false when no intermediates")
end

-- Tests that path:shorten_by shortens by multiple points
function tests.test_path_shorten_by()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    pth:insert(point.new(vector.new(8, 0, 0)))
    
    pth:shorten_by(2)
    
    assert(pth.intermediate_nr == 2, "Should have 2 intermediate points left")
    assert(pth.finish.pos.x == 6, "Finish should be at x=6")
end

-- Tests that path:cut_off removes all points after stop_point
function tests.test_path_cut_off()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(2, 0, 0))
    local mid2 = point.new(vector.new(4, 0, 0))
    local mid3 = point.new(vector.new(6, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    pth:cut_off(mid2)
    
    assert(pth.finish == mid2, "Finish should be mid2")
    assert(pth.intermediate_nr == 1, "Should have 1 intermediate point")
    assert(pth:get_point(1) == mid1, "Only mid1 should remain as intermediate")
end

-- Tests that path:all_points returns all points in order
function tests.test_path_all_points()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(3, 0, 0))
    local mid2 = point.new(vector.new(7, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    
    local all = pth:all_points()
    
    assert(#all == 4, "Should return 4 points")
    assert(all[1] == p1, "First should be start")
    assert(all[2] == mid1, "Second should be mid1")
    assert(all[3] == mid2, "Third should be mid2")
    assert(all[4] == p2, "Fourth should be finish")
end

-- Tests that path:all_positions returns positions of all points in order
function tests.test_path_all_positions()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(5, 0, 0))
    pth:insert(mid)
    
    local positions = pth:all_positions()
    
    assert(#positions == 3, "Should return 3 positions")
    assert(positions[1].x == 0, "First position x should be 0")
    assert(positions[2].x == 5, "Second position x should be 5")
    assert(positions[3].x == 10, "Third position x should be 10")
end

-- Tests that path:length returns the total length of the path
function tests.test_path_length()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local length = pth:length()
    assert(length == 10, "Straight path length should be 10")
    
    -- Add intermediate point (doesn't change total length if collinear)
    local mid = point.new(vector.new(5, 0, 0))
    pth:insert(mid)
    
    length = pth:length()
    assert(length == 10, "Path length should still be 10 with collinear point")
    
    -- Add non-collinear point
    local off = point.new(vector.new(5, 3, 0))
    pth:insert_before(mid, off)
    
    length = pth:length()
    assert(length > 10, "Path length should increase with detour")
end

-- Tests that path:subdivide breaks long segments into shorter ones
function tests.test_path_subdivide()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:subdivide(3)
    
    -- 10 / 3 = 3.33, so we should have at least 3 segments
    assert(pth.intermediate_nr >= 2, "Should have at least 2 intermediate points")
    
    -- Verify no segment is longer than 3 units
    local points = pth:all_points()
    for i = 2, #points do
        local dist = vector.distance(points[i-1].pos, points[i].pos)
        assert(dist <= 3.01, "No segment should be longer than 3 units")
    end
end

-- Tests that path:unsubdivide removes nearly-collinear intermediate points
function tests.test_path_unsubdivide()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    -- Add collinear points
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    pth:insert(point.new(vector.new(8, 0, 0)))
    
    assert(pth.intermediate_nr == 4, "Should start with 4 intermediate points")
    
    -- Unsubdivide with small angle threshold (collinear = 0 angle)
    pth:unsubdivide(0.1)
    
    assert(pth.intermediate_nr == 0, "All collinear points should be removed")
end

-- Tests that path:split_at divides a path into two at an intermediate point
function tests.test_path_split_at()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(3, 0, 0))
    local mid2 = point.new(vector.new(5, 0, 0))
    local mid3 = point.new(vector.new(7, 0, 0))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    local new_path = pth:split_at(mid2)
    
    assert(pth.finish == mid2, "Original path finish should be mid2")
    assert(pth.intermediate_nr == 1, "Original path should have 1 intermediate")
    assert(pth:get_point(1) == mid1, "Original path intermediate should be mid1")
    
    assert(new_path.start.pos.x == 5, "New path should start at x=5")
    assert(new_path.finish == p2, "New path finish should be p2")
end

-- Tests that path:transfer_points_to moves intermediate points between paths
function tests.test_path_transfer_points_to()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth1 = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(3, 0, 0))
    local mid2 = point.new(vector.new(5, 0, 0))
    local mid3 = point.new(vector.new(7, 0, 0))
    pth1:insert(mid1)
    pth1:insert(mid2)
    pth1:insert(mid3)
    
    local p3 = point.new(vector.new(100, 0, 0))
    local p4 = point.new(vector.new(200, 0, 0))
    local pth2 = path.new(p3, p4)
    
    pth1:transfer_points_to(pth2, mid1, mid2)
    
    assert(pth1.intermediate_nr == 1, "pth1 should have 1 intermediate left")
    assert(pth2.intermediate_nr == 2, "pth2 should have 2 intermediates")
end

-- Tests that path:clear_intermediate removes all intermediate points
function tests.test_path_clear_intermediate()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(2, 0, 0)))
    pth:insert(point.new(vector.new(4, 0, 0)))
    pth:insert(point.new(vector.new(6, 0, 0)))
    
    pth:clear_intermediate()
    
    assert(pth.intermediate_nr == 0, "Should have no intermediate points")
    assert(pth.start.next == pth.finish, "Start should link directly to finish")
end

-- Tests that path:make_straight subdivides if segment_length is given
function tests.test_path_make_straight()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:make_straight(3)
    
    assert(pth.intermediate_nr >= 2, "Should have intermediate points after subdivision")
end

-- Tests that path:make_wave creates a wavy path with intermediate points
function tests.test_path_make_wave()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(100, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:make_wave(10, 5, 2)
    
    assert(pth.intermediate_nr == 9, "Should have 9 intermediate points (segment_nr - 1)")
    
    -- Check that some points are offset from the straight line
    local has_offset = false
    for _, p in ipairs(pth:all_points()) do
        if p.pos.z ~= 0 then
            has_offset = true
            break
        end
    end
    assert(has_offset, "Wave should have points offset from straight line")
end

-- Tests that path:make_slanted creates a path with a 45-degree break point
function tests.test_path_make_slanted()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 0, 5))
    local pth = path.new(p1, p2)
    
    pth:make_slanted()
    
    assert(pth.intermediate_nr == 1, "Should have 1 intermediate point for 45-degree break")
    
    -- Test aligned case (no intermediate needed)
    local p3 = point.new(vector.new(0, 0, 0))
    local p4 = point.new(vector.new(10, 0, 0))
    local pth2 = path.new(p3, p4)
    
    pth2:make_slanted()
    
    assert(pth2.intermediate_nr == 0, "Aligned path should have no intermediate points")
end

-- Tests that vector.comparator provides correct ordering
function tests.test_vector_comparator()
    local v1 = vector.new(0, 0, 0)
    local v2 = vector.new(1, 0, 0)
    local v3 = vector.new(0, 1, 0)
    local v4 = vector.new(0, 0, 1)
    local v5 = vector.new(0, 0, 0)
    
    assert(vector.comparator(v1, v2) == true, "v1 < v2 by x")
    assert(vector.comparator(v2, v1) == false, "v2 > v1 by x")
    assert(vector.comparator(v1, v3) == true, "v1 < v3 by y")
    assert(vector.comparator(v1, v4) == true, "v1 < v4 by z")
    assert(vector.comparator(v1, v5) == false, "Equal vectors return false")
end
