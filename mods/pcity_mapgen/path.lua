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

pcmg.path = pcmg.path or {}
local path = pcmg.path
path.__index = path

local point = pcmg.point or dofile(mod_path.."/point.lua")
local path_utils = pcmg.path_utils or dofile(mod_path.."/path_utils.lua")

-- Counter for generating unique path IDs.
local path_id_counter = 0

-- Checks if 'p' is a point, otherwise throws an error.
local function check_point(p)
    if not point.check(p) then
        error("Path: p '"..shallow_dump(p).."' is not a point.")
    end
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

-- ============================================================
-- SEGMENT AND PATH INTERSECTION (EXISTING FUNCTIONS)
-- ============================================================

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
        local intersection = path_utils.segment_intersects(
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
            local intersection = path_utils.segment_intersects(
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
        local dist, closest = path_utils.point_to_segment_distance_2d(p, seg.start_pos, seg.end_pos)
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
            local intersection = path_utils.segment_intersects(
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
-- SEGMENT FINDING AND POINT INSERTION
-- ============================================================

-- Find the segment in a path that contains the given position
-- Returns the segment, its index, the t parameter, and the distance from the segment
function path:find_segment_containing_point(pos, tolerance)
    tolerance = tolerance or 10
    local segments = self:all_segments()

    for seg_idx, seg in ipairs(segments) do
        local seg_dir = vector.subtract(seg.end_pos, seg.start_pos)
        local seg_len_sq = path_utils.xz_length_sq(seg_dir)

        if seg_len_sq > 1e-6 then
            local to_pos = vector.subtract(pos, seg.start_pos)
            local t = path_utils.xz_dot(to_pos, seg_dir) / seg_len_sq

            -- Check if t is within segment bounds
            if t >= -0.1 and t <= 1.1 then
                local clamped_t = math.max(0, math.min(1, t))
                local closest = vector.add(seg.start_pos, vector.multiply(seg_dir, clamped_t))
                local dist = vector.distance(pos, closest)

                if dist < tolerance then
                    return seg, seg_idx, t, dist
                end
            end
        end
    end

    return nil, nil, nil, nil
end

-- Insert a point into the path at the given position
-- Returns the new point (or existing point if close enough), and whether it was inserted
-- min_distance: minimum distance to existing points before returning existing point
function path:insert_point_at_position(pos, min_distance)
    min_distance = min_distance or 5

    -- Check if there's already a point close to this position
    local all_points = self:all_points()
    for _, p in ipairs(all_points) do
        if vector.distance(p.pos, pos) < min_distance then
            return p, false  -- Return existing point, no insertion needed
        end
    end

    -- Find the segment containing this position
    local seg, seg_idx, t, dist = self:find_segment_containing_point(pos, min_distance * 3)

    if not seg then
        return nil, false
    end

    -- Verify the segment is still valid (points are adjacent)
    if not seg.start_point or not seg.end_point then
        return nil, false
    end

    if seg.start_point.next ~= seg.end_point then
        return nil, false
    end

    -- Check distance from segment endpoints
    if vector.distance(seg.start_point.pos, pos) < min_distance then
        return seg.start_point, false
    end
    if vector.distance(seg.end_point.pos, pos) < min_distance then
        return seg.end_point, false
    end

    -- Check if t is too close to endpoints
    if t < 0.05 then
        return seg.start_point, false
    elseif t > 0.95 then
        return seg.end_point, false
    end

    -- Insert new point
    local new_point = point.new(pos)
    self:insert_between(seg.start_point, seg.end_point, new_point)
    return new_point, true
end

-- ============================================================
-- PATH INTERSECTION FINDING (NEW FUNCTIONS)
-- ============================================================

-- Find all intersections between this path and another path
-- Returns a list of intersection data with positions and segment info
-- skip_position: optional position to skip (e.g., branch point)
-- skip_tolerance: distance within which to skip intersections near skip_position
function path:find_intersections_with_path(other_path, skip_position, skip_tolerance)
    skip_tolerance = skip_tolerance or 10
    local intersections = {}
    local self_segments = self:all_segments()
    local other_segments = other_path:all_segments()

    for self_idx, self_seg in ipairs(self_segments) do
        for other_idx, other_seg in ipairs(other_segments) do
            local int_pos, t1, t2 = path_utils.calculate_segment_intersection(
                self_seg.start_pos, self_seg.end_pos,
                other_seg.start_pos, other_seg.end_pos
            )

            if int_pos then
                -- Skip if this is near the skip position
                local should_skip = false
                if skip_position and vector.distance(int_pos, skip_position) < skip_tolerance then
                    should_skip = true
                end

                -- Skip if segments are parallel
                if path_utils.segments_are_parallel(
                    self_seg.start_pos, self_seg.end_pos,
                    other_seg.start_pos, other_seg.end_pos
                ) then
                    should_skip = true
                end

                if not should_skip then
                    table.insert(intersections, {
                        pos = int_pos,
                        t1 = t1,
                        t2 = t2,
                        self_segment = self_seg,
                        self_segment_index = self_idx,
                        other_segment = other_seg,
                        other_segment_index = other_idx,
                        other_path = other_path
                    })
                end
            end
        end
    end

    return intersections
end

-- Find all intersections between this path and a list of other paths
-- Returns intersections sorted by distance from start of this path
function path:find_intersections_with_paths(other_paths, skip_position, skip_tolerance)
    local all_intersections = {}
    local self_points = self:all_points()

    for _, other_path in ipairs(other_paths) do
        local intersections = self:find_intersections_with_path(other_path, skip_position, skip_tolerance)

        for _, int_data in ipairs(intersections) do
            -- Calculate cumulative distance from path start
            local cumulative_dist = 0
            for i = 2, int_data.self_segment_index do
                cumulative_dist = cumulative_dist + vector.distance(
                    self_points[i-1].pos, self_points[i].pos
                )
            end
            cumulative_dist = cumulative_dist + vector.distance(
                int_data.self_segment.start_pos, int_data.pos
            )

            int_data.distance_from_start = cumulative_dist
            table.insert(all_intersections, int_data)
        end
    end

    -- Sort by distance from start
    table.sort(all_intersections, function(a, b)
        return a.distance_from_start < b.distance_from_start
    end)

    return all_intersections
end

-- Create intersection points in this path and optionally in intersecting paths
-- intersections: list from find_intersections_with_path or find_intersections_with_paths
-- modify_other_paths: if true, also insert points in the other paths
-- min_distance: minimum distance between intersection points
function path:create_intersection_points(intersections, modify_other_paths, min_distance)
    min_distance = min_distance or 5
    local created_points = {}

    -- Process intersections in reverse order (farthest first)
    -- to avoid invalidating segment references
    for i = #intersections, 1, -1 do
        local int_data = intersections[i]
        local pos = int_data.pos

        -- Check if we're too close to an already created point
        local too_close = false
        for _, created in ipairs(created_points) do
            if vector.distance(pos, created.pos) < min_distance then
                too_close = true
                break
            end
        end

        if not too_close then
            -- Insert point in this path
            local self_point, self_inserted = self:insert_point_at_position(pos, min_distance)

            -- Insert point in the other path if requested
            local other_point = nil
            local other_inserted = false
            if modify_other_paths and int_data.other_path then
                other_point, other_inserted = int_data.other_path:insert_point_at_position(pos, min_distance)
            end

            if self_point then
                table.insert(created_points, {
                    pos = pos,
                    self_point = self_point,
                    other_point = other_point,
                    self_inserted = self_inserted,
                    other_inserted = other_inserted
                })
            end
        end
    end

    return created_points
end

-- ============================================================
-- GRID SUBDIVISION
-- ============================================================

-- Subdivide path by inserting points at grid intersections
-- grid_spacing: the spacing between grid lines
-- min_point_distance: minimum distance between points (to avoid clustering)
-- Returns list of inserted points
function path:subdivide_to_grid(grid_spacing, min_point_distance)
    min_point_distance = min_point_distance or 5
    local segments = self:all_segments()
    local points_to_insert = {}

    -- Collect all grid intersection points for all segments
    for seg_index, seg in ipairs(segments) do
        -- Find X grid lines that intersect this segment
        local min_x = math.min(seg.start_pos.x, seg.end_pos.x)
        local max_x = math.max(seg.start_pos.x, seg.end_pos.x)
        local first_x_grid = math.ceil(min_x / grid_spacing) * grid_spacing

        local x_grid = first_x_grid
        while x_grid <= max_x do
            local int_pos, t = path_utils.segment_grid_intersection(seg.start_pos, seg.end_pos, x_grid, true)
            if int_pos then
                local dist = vector.distance(seg.start_pos, int_pos)
                table.insert(points_to_insert, {
                    pos = int_pos,
                    segment_index = seg_index,
                    distance_from_start = dist,
                    start_point = seg.start_point,
                    end_point = seg.end_point
                })
            end
            x_grid = x_grid + grid_spacing
        end

        -- Find Z grid lines that intersect this segment
        local min_z = math.min(seg.start_pos.z, seg.end_pos.z)
        local max_z = math.max(seg.start_pos.z, seg.end_pos.z)
        local first_z_grid = math.ceil(min_z / grid_spacing) * grid_spacing

        local z_grid = first_z_grid
        while z_grid <= max_z do
            local int_pos, t = path_utils.segment_grid_intersection(seg.start_pos, seg.end_pos, z_grid, false)
            if int_pos then
                local dist = vector.distance(seg.start_pos, int_pos)
                table.insert(points_to_insert, {
                    pos = int_pos,
                    segment_index = seg_index,
                    distance_from_start = dist,
                    start_point = seg.start_point,
                    end_point = seg.end_point
                })
            end
            z_grid = z_grid + grid_spacing
        end
    end

    -- Sort by segment index (descending) then by distance (descending)
    -- We insert in reverse order to avoid invalidating segment references
    table.sort(points_to_insert, function(a, b)
        if a.segment_index ~= b.segment_index then
            return a.segment_index > b.segment_index
        end
        return a.distance_from_start > b.distance_from_start
    end)

    -- Insert points into the path
    local inserted_points = {}
    for _, pt_data in ipairs(points_to_insert) do
        -- Check if this segment is still valid (points still adjacent)
        if pt_data.start_point.next == pt_data.end_point then
            -- Check we're not too close to existing points
            local too_close = false

            if vector.distance(pt_data.start_point.pos, pt_data.pos) < min_point_distance then
                too_close = true
            elseif vector.distance(pt_data.end_point.pos, pt_data.pos) < min_point_distance then
                too_close = true
            end

            if not too_close then
                local new_point = point.new(pt_data.pos)
                self:insert_between(pt_data.start_point, pt_data.end_point, new_point)
                table.insert(inserted_points, new_point)
            end
        end
    end

    return inserted_points
end

-- ============================================================
-- SUBDIVIDE AND UNSUBDIVIDE (EXISTING)
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

return pcmg.path
