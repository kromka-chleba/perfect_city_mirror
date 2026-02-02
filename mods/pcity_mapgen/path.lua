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

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local math = math
local vector = vector
local pcmg = pcity_mapgen

pcmg.path = {}
local path = pcmg.path
path.__index = path

pcmg.point = {}
local point = pcmg.point
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
    if not point.same_path(unpack(points)) then
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

-- ============================================================
-- INTERMEDIATE COUNT HELPERS
-- ============================================================

-- Counts intermediate points by traversing the linked list.
-- Returns the number of intermediate points (excludes start and finish).
function path:count_intermediate()
    local count = 0
    local current = self.start and self.start.next
    while current and current ~= self.finish do
        count = count + 1
        current = current.next
    end
    return count
end

-- Checks if the path has any intermediate points.
-- Returns true if there is at least one intermediate point.
function path:has_intermediate()
    return self.start and self.start.next and self.start.next ~= self.finish
end

-- ============================================================
-- COMPARATORS AND SORTING
-- ============================================================

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
    local count1 = pth1:count_intermediate()
    local count2 = pth2:count_intermediate()
    if count1 ~= count2 then
        return count1 < count2
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
-- Returns 'nil' if 'nr' is lower than 1.
-- Note: start and finish are not considered intermediate points.
function path:get_point(nr)
    if type(nr) ~= "number" or nr <= 0 then
        return nil
    end
    local i = 0
    local current = self.start and self.start.next
    while current and current ~= self.finish do
        i = i + 1
        if i == nr then
            return current
        end
        current = current.next
    end
    return nil
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
    local intermediates = {}
    local current = self.start and self.start.next
    while current and current ~= self.finish do
        table.insert(intermediates, current)
        current = current.next
    end
    if #intermediates > 0 then
        return intermediates[math.random(1, #intermediates)]
    end
    return nil
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
end

-- Inserts intermediate point 'p' at ordinal position 'nr' in the path.
-- 'nr' = 1 means inserting 'p' right after the start point.
-- 'nr' = count_intermediate() + 1 means inserting 'p' right before the
-- finish point.
function path:insert_at(nr, p)
    local p1 = self:get_point(nr - 1) or self.start
    local p2 = p1.next or self.finish
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
    local last = self.finish.previous or self.start
    self:insert_between(last, self.finish, p)
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
    if not self:has_intermediate() then
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

-- Checks if arguments passed to 'path:remove_at' are valid.
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
end

-- Shortens the path by removing the finish point and setting the
-- previous point as the new finish. Does nothing if there are no
-- intermediate points. Returns 'true' if the path was shortened,
-- 'false' otherwise.
function path:shorten()
    if not self:has_intermediate() then
        return false
    end
    local old_finish = self.finish
    local new_finish = old_finish.previous
    old_finish:clear()
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
-- SEGMENT AND PATH INTERSECTION
-- ============================================================

-- Calculates the shortest distance between two line segments in 2D (XZ plane).
-- Segment 1: from a1 to a2
-- Segment 2: from b1 to b2
-- Returns the shortest distance and the closest points on each segment.
local function segment_distance_2d(a1, a2, b1, b2)
    -- Project to XZ plane
    local ax1, az1 = a1.x, a1.z
    local ax2, az2 = a2.x, a2.z
    local bx1, bz1 = b1.x, b1.z
    local bx2, bz2 = b2.x, b2.z
    
    -- Direction vectors
    local dax, daz = ax2 - ax1, az2 - az1
    local dbx, dbz = bx2 - bx1, bz2 - bz1
    
    -- Vector from a1 to b1
    local dx, dz = bx1 - ax1, bz1 - az1
    
    -- Squared lengths
    local len_a_sq = dax * dax + daz * daz
    local len_b_sq = dbx * dbx + dbz * dbz
    
    -- Handle degenerate cases (zero-length segments)
    if len_a_sq < 1e-10 and len_b_sq < 1e-10 then
        -- Both segments are points
        local dist = math.sqrt(dx * dx + dz * dz)
        return dist, a1, b1
    end
    
    if len_a_sq < 1e-10 then
        -- Segment A is a point, find closest point on B
        local t = math.max(0, math.min(1, (dx * dbx + dz * dbz) / len_b_sq))
        local closest_b = vector.new(bx1 + t * dbx, (b1.y + b2.y) / 2, bz1 + t * dbz)
        local dist = math.sqrt((ax1 - closest_b.x)^2 + (az1 - closest_b.z)^2)
        return dist, a1, closest_b
    end
    
    if len_b_sq < 1e-10 then
        -- Segment B is a point, find closest point on A
        local t = math.max(0, math.min(1, (-dx * dax - dz * daz) / len_a_sq))
        local closest_a = vector.new(ax1 + t * dax, (a1.y + a2.y) / 2, az1 + t * daz)
        local dist = math.sqrt((closest_a.x - bx1)^2 + (closest_a.z - bz1)^2)
        return dist, closest_a, b1
    end
    
    -- Cross product for parallel check
    local cross = dax * dbz - daz * dbx
    
    -- Dot products
    local dot_aa = len_a_sq
    local dot_bb = len_b_sq
    local dot_ab = dax * dbx + daz * dbz
    local dot_ad = dax * dx + daz * dz
    local dot_bd = dbx * dx + dbz * dz
    
    local s, t
    local denom = dot_aa * dot_bb - dot_ab * dot_ab
    
    if math.abs(denom) < 1e-10 then
        -- Segments are parallel
        s = 0
        t = dot_bd / dot_bb
    else
        s = (dot_ab * dot_bd - dot_bb * dot_ad) / denom
        t = (dot_aa * dot_bd - dot_ab * dot_ad) / denom
    end
    
    -- Clamp parameters to [0, 1]
    if s < 0 then
        s = 0
        t = dot_bd / dot_bb
    elseif s > 1 then
        s = 1
        t = (dot_ab + dot_bd) / dot_bb
    end
    
    if t < 0 then
        t = 0
        s = -dot_ad / dot_aa
        s = math.max(0, math.min(1, s))
    elseif t > 1 then
        t = 1
        s = (dot_ab - dot_ad) / dot_aa
        s = math.max(0, math.min(1, s))
    end
    
    -- Calculate closest points
    local closest_a = vector.new(
        ax1 + s * dax,
        a1.y + s * (a2.y - a1.y),
        az1 + s * daz
    )
    local closest_b = vector.new(
        bx1 + t * dbx,
        b1.y + t * (b2.y - b1.y),
        bz1 + t * dbz
    )
    
    -- Calculate distance
    local dist = math.sqrt(
        (closest_a.x - closest_b.x)^2 + 
        (closest_a.z - closest_b.z)^2
    )
    
    return dist, closest_a, closest_b
end

-- Calculates the shortest distance from a point to a line segment in 2D (XZ plane).
-- Returns the distance and the closest point on the segment.
local function point_to_segment_distance_2d(p, seg_start, seg_end)
    local px, pz = p.x, p.z
    local ax, az = seg_start.x, seg_start.z
    local bx, bz = seg_end.x, seg_end.z
    
    local dx, dz = bx - ax, bz - az
    local len_sq = dx * dx + dz * dz
    
    if len_sq < 1e-10 then
        -- Segment is a point
        local dist = math.sqrt((px - ax)^2 + (pz - az)^2)
        return dist, seg_start
    end
    
    -- Project point onto line, clamped to segment
    local t = ((px - ax) * dx + (pz - az) * dz) / len_sq
    t = math.max(0, math.min(1, t))
    
    local closest = vector.new(
        ax + t * dx,
        seg_start.y + t * (seg_end.y - seg_start.y),
        az + t * dz
    )
    
    local dist = math.sqrt((px - closest.x)^2 + (pz - closest.z)^2)
    return dist, closest
end

-- Checks if two segments intersect or come within 'margin' distance of each other.
-- Returns intersection info table or nil if no intersection within margin.
-- The returned table contains:
--   - intersects: boolean, true if segments actually cross
--   - distance: number, shortest distance between segments
--   - point_a: vector, closest point on segment A
--   - point_b: vector, closest point on segment B
--   - midpoint: vector, midpoint between closest points
function path.segment_intersects(a1, a2, b1, b2, margin)
    margin = margin or 0
    
    local dist, closest_a, closest_b = segment_distance_2d(a1, a2, b1, b2)
    
    if dist <= margin then
        local midpoint = vector.new(
            (closest_a.x + closest_b.x) / 2,
            (closest_a.y + closest_b.y) / 2,
            (closest_a.z + closest_b.z) / 2
        )
        return {
            intersects = dist < 1e-6,
            distance = dist,
            point_a = closest_a,
            point_b = closest_b,
            midpoint = midpoint
        }
    end
    
    return nil
end

-- Returns all segments of the path as a list of {start_pos, end_pos} pairs.
function path:all_segments()
    local segments = {}
    local points = self:all_points()
    for i = 2, #points do
        table.insert(segments, {
            start_pos = points[i - 1].pos,
            end_pos = points[i].pos,
            start_point = points[i - 1],
            end_point = points[i]
        })
    end
    return segments
end

-- Checks if a segment intersects with any segment of this path.
-- Returns a list of intersection info tables (see segment_intersects).
-- Each result also includes:
--   - segment_index: number, index of the path segment that intersects
--   - segment: table, the path segment {start_pos, end_pos, start_point, end_point}
function path:intersects_segment(seg_start, seg_end, margin)
    margin = margin or 0
    local results = {}
    local segments = self:all_segments()
    
    for i, seg in ipairs(segments) do
        local intersection = path.segment_intersects(
            seg_start, seg_end,
            seg.start_pos, seg.end_pos,
            margin
        )
        if intersection then
            intersection.segment_index = i
            intersection.segment = seg
            table.insert(results, intersection)
        end
    end
    
    return results
end

-- Checks if this path intersects with another path.
-- Returns a list of intersection info tables.
-- Each result includes:
--   - self_segment_index: number, index of segment in this path
--   - self_segment: table, the segment from this path
--   - other_segment_index: number, index of segment in other path
--   - other_segment: table, the segment from other path
--   - (plus all fields from segment_intersects)
function path:intersects_path(other_path, margin)
    margin = margin or 0
    local results = {}
    local self_segments = self:all_segments()
    local other_segments = other_path:all_segments()
    
    for i, self_seg in ipairs(self_segments) do
        for j, other_seg in ipairs(other_segments) do
            local intersection = path.segment_intersects(
                self_seg.start_pos, self_seg.end_pos,
                other_seg.start_pos, other_seg.end_pos,
                margin
            )
            if intersection then
                intersection.self_segment_index = i
                intersection.self_segment = self_seg
                intersection.other_segment_index = j
                intersection.other_segment = other_seg
                table.insert(results, intersection)
            end
        end
    end
    
    return results
end

-- Checks if a point is within 'margin' distance of any segment of this path.
-- Returns intersection info or nil.
-- The returned table contains:
--   - distance: number, shortest distance from point to path
--   - closest_point: vector, closest point on the path
--   - segment_index: number, index of the closest segment
--   - segment: table, the closest segment
function path:intersects_point(p, margin)
    margin = margin or 0
    local segments = self:all_segments()
    local best_dist = math.huge
    local best_closest = nil
    local best_segment_index = nil
    local best_segment = nil
    
    for i, seg in ipairs(segments) do
        local dist, closest = point_to_segment_distance_2d(p, seg.start_pos, seg.end_pos)
        if dist < best_dist then
            best_dist = dist
            best_closest = closest
            best_segment_index = i
            best_segment = seg
        end
    end
    
    if best_dist <= margin then
        return {
            distance = best_dist,
            closest_point = best_closest,
            segment_index = best_segment_index,
            segment = best_segment
        }
    end
    
    return nil
end

-- Finds the first intersection point when traversing this path.
-- Useful for finding where a path would collide with an obstacle.
-- Returns the intersection info closest to the start of the path, or nil.
function path:first_intersection_with_path(other_path, margin)
    local intersections = self:intersects_path(other_path, margin)
    if #intersections == 0 then
        return nil
    end
    
    -- Sort by self_segment_index to find first intersection
    table.sort(intersections, function(a, b)
        if a.self_segment_index ~= b.self_segment_index then
            return a.self_segment_index < b.self_segment_index
        end
        -- If same segment, compare distance from segment start
        local dist_a = vector.distance(a.point_a, a.self_segment.start_pos)
        local dist_b = vector.distance(b.point_a, b.self_segment.start_pos)
        return dist_a < dist_b
    end)
    
    return intersections[1]
end

-- Checks if this path intersects with itself (self-intersection).
-- Skips adjacent segments as they naturally share endpoints.
-- Returns a list of intersection info tables.
function path:self_intersections(margin)
    margin = margin or 0
    local results = {}
    local segments = self:all_segments()
    
    for i = 1, #segments - 2 do
        for j = i + 2, #segments do
            local intersection = path.segment_intersects(
                segments[i].start_pos, segments[i].end_pos,
                segments[j].start_pos, segments[j].end_pos,
                margin
            )
            if intersection then
                intersection.segment_index_1 = i
                intersection.segment_1 = segments[i]
                intersection.segment_index_2 = j
                intersection.segment_2 = segments[j]
                table.insert(results, intersection)
            end
        end
    end
    
    return results
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
    if not self:has_intermediate() then
        return
    end
    local prev = self.start
    local mid = prev.next
    local nxt = mid and mid.next
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
    if not self:has_intermediate() then
        error("Path: cannot split path with no intermediate points.")
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
    local new_path = path.new(p:copy(), self.finish:copy())
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
-- and finish.
function path:clear_intermediate()
    while self:has_intermediate() do
        local p = self:get_point(1)
        if p then
            self:remove(p)
        else
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