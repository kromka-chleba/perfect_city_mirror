--[[
    This is a part of "Perfect City".
    Copyright (C) 2024-2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
    SPDX-License-Identifier: AGPL-3.0-or-later

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local math = math
local vector = vector
local pcmg = pcity_mapgen

pcmg.path = pcmg.path or {}
local path = pcmg.path
path.__index = path

local point = pcmg.point or dofile(mod_path.."/point.lua")
local path_utils = pcmg.path_utils or dofile(mod_path.."/path_utils.lua")
local checks = pcmg.point_checks or dofile(mod_path.."/point_checks.lua")

-- Counter for generating unique path IDs.
local path_id_counter = 0

-- ============================================================
-- PATH CLASS
-- ============================================================

--- Creates a new instance of the Path class.
-- Paths consist of a start point, a finish point and any number of 
-- intermediate points in between. Points are instances of the Point class.
-- All points (including start and finish) are stored in self.points. 
-- Paths support various operations for manipulating points such as
-- inserting, removing, splitting, extending, shortening, subdividing,
-- unsubdividing, etc.
-- @param start table Point instance for the path start
-- @param finish table Point instance for the path finish
-- @return table New path instance
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

--- Checks if an object is a path as created by path.new.
-- @param pth any Object to check
-- @return boolean True if the object is a path, false otherwise
function path.check(pth)
    return getmetatable(pth) == path
end

-- ============================================================
-- INTERMEDIATE COUNT HELPERS
-- ============================================================

--- Counts intermediate points by traversing the linked list.
-- @return number The number of intermediate points (excludes start and finish)
function path:count_intermediate()
    local count = 0
    local current = self.start and self.start.next
    while current and current ~= self.finish do
        count = count + 1
        current = current.next
    end
    return count
end

--- Checks if the path has any intermediate points.
-- @return boolean True if there is at least one intermediate point
function path:has_intermediate()
    return self.start and self.start.next and self.start.next ~= self.finish
end

-- ============================================================
-- COMPARATORS AND SORTING
-- ============================================================

--- Comparator for paths.
-- Compares by start, finish, intermediate points, then by ID.
-- Deterministic across Lua environments.
-- @param pth1 table First path to compare
-- @param pth2 table Second path to compare
-- @return boolean True if pth1 should be ordered before pth2
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

--- Returns a sorted copy of a table of paths.
-- @param paths table Table of paths to sort
-- @return table Sorted copy of the paths table
function path.sort(paths)
    local sorted = {}
    for _, pth in pairs(paths) do
        table.insert(sorted, pth)
    end
    table.sort(sorted, path.comparator)
    return sorted
end

--- Returns branching points in deterministic order (path order).
-- @return table List of branching points in path order
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

--- Sets the start point of the path.
-- The start point is added to the path's points table.
-- @param p table Point to set as the start point
function path:set_start(p)
    checks.check_point(p)
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

--- Sets the finish point of the path.
-- The finish point is added to the path's points table.
-- @param p table Point to set as the finish point
function path:set_finish(p)
    checks.check_point(p)
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

--- Returns an intermediate point given by its ordinal number.
-- The ordinal number starts from the first intermediate point (after start)
-- and ends with the last (before finish). So nr = 1 will give the first 
-- intermediate point in the path, etc.
-- Note: start and finish are not considered intermediate points.
-- @param nr number Ordinal number of the point (must be >= 1)
-- @return table|nil The point at the given position, or nil if not found
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

--- Returns all intermediate points between two points.
-- The range is inclusive if intermediate, exclusive if start/finish.
-- Note: start and finish points are never included in the returned list.
-- @param from table Starting point (must belong to the path)
-- @param to table Ending point (must belong to the path)
-- @return table List of intermediate points between from and to
function path:get_points(from, to)
    checks.check_point(from)
    checks.check_point(to)
    checks.check_same_path({self.start, from, to, self.finish})
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

--- Picks a random intermediate point in the path.
-- Note: start and finish are not considered intermediate points.
-- @return table|nil A random intermediate point, or nil if none exist
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

--- Checks if a point belongs to the path.
-- Checks if the point belongs as start, intermediate, or finish point.
-- All points are stored in self.points, so this simply checks if the 
-- point exists in that table.
-- @param p table Point to check
-- @return boolean True if the point belongs to the path
function path:point_in_path(p)
    return self.points[p] ~= nil
end

-- ============================================================
-- INSERTION
-- ============================================================

--- Inserts intermediate point between two points.
-- Both p_prev and p_next need to belong to the path. The inserted point
-- is added to the path's points table.
-- @param p_prev table Previous point (must belong to the path)
-- @param p_next table Next point (must belong to the path)
-- @param p table Point to insert between p_prev and p_next
function path:insert_between(p_prev, p_next, p)
    checks.check_insert_between_arguments(self, p_prev, p_next, p)
    p:set_path(self)
    point.link(p_prev, p, p_next)
end

--- Inserts intermediate point at ordinal position in the path.
-- nr = 1 means inserting right after the start point.
-- nr = count_intermediate() + 1 means inserting right before the finish point.
-- @param nr number Ordinal position to insert at
-- @param p table Point to insert
function path:insert_at(nr, p)
    local p1 = self:get_point(nr - 1) or self.start
    local p2 = p1.next or self.finish
    self:insert_between(p1, p2, p)
end

--- Inserts an intermediate point before a target point.
-- @param target table Point to insert before
-- @param p table Point to insert
function path:insert_before(target, p)
    self:insert_between(target.previous, target, p)
end

--- Inserts an intermediate point after a target point.
-- @param target table Point to insert after
-- @param p table Point to insert
function path:insert_after(target, p)
    self:insert_between(target, target.next, p)
end

--- Inserts an intermediate point before the finish point.
-- @param p table Point to insert
function path:insert(p)
    local last = self.finish.previous or self.start
    self:insert_between(last, self.finish, p)
end

-- ============================================================
-- REMOVAL
-- ============================================================

--- Removes intermediate point from the path.
-- Cannot remove start or finish points.
-- @param p table Point to remove (must be an intermediate point)
function path:remove(p)
    checks.check_point(p)
    checks.check_remove_arguments(self, p)
    local prev = p.previous
    local nxt = p.next
    -- Link neighbors before clearing to maintain chain integrity
    if prev and nxt then
        prev.next = nxt
        nxt.previous = prev
    end
    p:clear()
end

--- Removes the intermediate point that comes before a given point.
-- Cannot remove start or finish points.
-- @param p table Point whose previous point will be removed
function path:remove_previous(p)
    checks.check_point(p)
    checks.check_remove_arguments(self, p.previous)
    self:remove(p.previous)
end

--- Removes the intermediate point that comes after a given point.
-- Cannot remove start or finish points.
-- @param p table Point whose next point will be removed
function path:remove_next(p)
    checks.check_point(p)
    checks.check_remove_arguments(self, p.next)
    self:remove(p.next)
end

--- Removes an intermediate point given by its ordinal number.
-- @param nr number Ordinal number of the point to remove
function path:remove_at(nr)
    checks.check_remove_at_arguments(self, nr)
    local p = self:get_point(nr)
    self:remove(p)
end

-- ============================================================
-- EXTEND AND SHORTEN
-- ============================================================

--- Extends the path by adding a point at the end.
-- The point becomes the new finish point, and the old finish becomes
-- an intermediate point.
-- @param p table Point to add at the end
function path:extend(p)
    checks.check_point(p)
    local old_finish = self.finish
    -- Set up new finish
    p:set_path(self)
    p:unlink()
    point.link(old_finish, p)
    self.finish = p
end

--- Shortens the path by removing the finish point.
-- Sets the previous point as the new finish. Does nothing if there are no
-- intermediate points.
-- @return boolean True if the path was shortened, false otherwise
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

--- Shortens the path by a given number of points.
-- If nr is bigger than the number of intermediate points, the path is 
-- shortened as much as possible.
-- @param nr number Number of points to shorten by
function path:shorten_by(nr)
    for i = 1, nr do
        if not self:shorten() then
            break
        end
    end
end

--- Cuts off all points that come after a given point.
-- Removes from the path all points after stop_point and sets stop_point 
-- as the new finish.
-- @param stop_point table Point to cut off after
function path:cut_off(stop_point)
    checks.check_point(stop_point)
    checks.check_same_path({self.start, stop_point, self.finish})
    while self.finish ~= stop_point do
        if not self:shorten() then
            break
        end
    end
end

-- ============================================================
-- ALL POINTS AND POSITIONS
-- ============================================================

--- Returns all points of the path.
-- Includes start, intermediate points and finish (in order).
-- @return table List of all points in the path
function path:all_points()
    local points = {}
    table.insert(points, self.start)
    for _, p in self.start:iterator() do
        table.insert(points, p)
    end
    return points
end

--- Returns positions of all points of the path.
-- Includes start, intermediate points and finish (in order).
-- @return table List of all point positions as vectors
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

--- Returns the length of the path.
-- Calculates by summing lengths of all segments.
-- @return number The total length of the path
function path:length()
    local points = self:all_points()
    local len = 0
    for i = 2, #points do
        local v = points[i].pos - points[i - 1].pos
        len = len + vector.length(v)
    end
    return len
end

-- ============================================================
-- 2D GEOMETRY UTILITIES (STATIC FUNCTIONS)
-- ============================================================
-- Moved to path_utils.lua (pcmg.path_utils)

--- Returns all segments of the path.
-- Each segment is a table with start_pos, end_pos, start_point, and end_point.
-- @return table List of segments
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


-- ============================================================
-- SUBDIVIDE AND UNSUBDIVIDE (EXISTING)
-- ============================================================

--- Subdivides path into segments with maximum length.
-- Leaves segments shorter than segment_length untouched.
-- @param segment_length number Maximum length for each segment
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

--- Unsubdivides the path by removing nearly collinear points.
-- Removes intermediate points that form an angle smaller than the threshold
-- with their neighbors. Leaves other points untouched.
-- @param angle number Angle threshold in radians
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

--- Transfers intermediate points to another path.
-- Transfers all intermediate points between first and last (inclusive) from
-- this path to another path. Both first and last need to belong to this path.
-- Only intermediate points are transferred (not start or finish).
-- @param pth table Target path to transfer points to
-- @param first table First point in the range
-- @param last table Last point in the range
function path:transfer_points_to(pth, first, last)
    local points = self:get_points(first, last)
    for _, p in ipairs(points) do
        self:remove(p)
        pth:insert(p)
    end
end

--- Splits the path into two paths at a given point.
-- The point must be an intermediate point. The point gets duplicated so 
-- that it becomes the finish point of the first path and the start point 
-- of the second path. The path needs to have at least 1 intermediate point 
-- for the split to be possible.
-- @param p table Point to split at (must be an intermediate point)
-- @return table The newly created second path
function path:split_at(p)
    checks.check_point(p)
    checks.check_split_at_arguments(self, p)
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

--- Clears all intermediate points from the path.
-- Leaves only start and finish.
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

--- Creates a straight path from start to finish.
-- When segment_length is given, the path will be subdivided into segments
-- with max length of segment_length.
-- @param segment_length number|nil Optional maximum segment length
function path:make_straight(segment_length)
    if segment_length then
        self:subdivide(segment_length)
    end
end

--- Creates a wavy path from start to finish.
-- The wave oscillates with the given amplitude (in nodes) and density
-- controls how many complete wave cycles fit into the whole length of the path.
-- The path is divided into segment_nr segments.
-- @param segment_nr number Number of segments to divide the path into
-- @param amplitude number Wave amplitude in nodes
-- @param density number Number of complete wave cycles along the path
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

--- Creates a path with a 45 degree angle break point.
-- Connects start and finish so that there's only one break point that forms
-- a 45 degree angle with its neighbors. When start and finish are parallel 
-- to either the x or z axis, the function will simply make a straight line.
-- The "straight" region (parallel to x or z axis) is always longer or equal 
-- to the "slanted" region. When segment_length is given, the path will be 
-- further subdivided into segments with max length of segment_length.
-- @param segment_length number|nil Optional maximum segment length
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

return pcmg.path
