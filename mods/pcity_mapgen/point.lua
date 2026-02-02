--[[
    This is a part of "Perfect City".
    Copyright (C) 2024-2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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

pcmg.point = pcmg.point or {}
local point = pcmg.point
point.__index = point

local path = pcmg.path or dofile(mod_path.."/path.lua")
local checks = pcmg.point_checks or dofile(mod_path.."/point_checks.lua")

-- Counter for generating unique point IDs. Ensures deterministic
-- ordering for points at the same position, as long as points are
-- created in the same order across environments.
local point_id_counter = 0

-- Counter for generating unique path IDs.
local path_id_counter = 0

-- Creates a new instance of the Point class. Points store absolute
-- world position, the previous and the next point in a sequence and
-- the path (see the Path class below) they belong to. Points can be
-- linked to create linked lists which should be helpful for
-- road/street generation algorithms.
function point.new(pos)
    checks.check_point_new_arguments(pos)
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
-- (point.check is used elsewhere; checks.check_point resolves runtime)
-- (no local duplicate here)

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

-- Links points in order, accepts any number of points. '...' is any number of points.
-- Only points belonging to the same path can be linked.
function point.link(...)
    local points = {...}
    checks.check_same_path(points)
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
        checks.check_point(p)
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
        checks.check_point(p)
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

return pcmg.point
