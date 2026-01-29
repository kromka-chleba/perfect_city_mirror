--[[
    This is a part of "Perfect City".
    Copyright (C) 2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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

--[[
    Utilities for spatial-vector 2D (XZ) geometry and path-related helpers.
--]]

local math = math
local vector = vector
local pcmg = pcity_mapgen

pcmg.path_utils = pcmg.path_utils or {}
local path_utils = pcmg.path_utils

local function vector_flatten_xz(v)
    return vector.new(v.x, 0, v.z)
end

local function vector_xz_dot(v1, v2)
    return vector.dot(vector_flatten_xz(v1), vector_flatten_xz(v2))
end

local function vector_xz_length(v)
    return vector.length(vector_flatten_xz(v))
end

local function vector_xz_length_sq(v)
    local flat = vector_flatten_xz(v)
    return vector.dot(flat, flat)
end

function path_utils.xz_dot(v1, v2)
    return vector_xz_dot(v1, v2)
end

function path_utils.xz_length(v)
    return vector_xz_length(v)
end

function path_utils.xz_length_sq(v)
    return vector_xz_length_sq(v)
end

-- Calculate the 2D angle between two direction vectors (in XZ plane)
function path_utils.angle_between_2d(dir1, dir2)
    local flat1 = vector_flatten_xz(dir1)
    local flat2 = vector_flatten_xz(dir2)
    local dot = vector.dot(flat1, flat2)
    local len1 = vector.length(flat1)
    local len2 = vector.length(flat2)
    if len1 < 1e-6 or len2 < 1e-6 then
        return 0
    end
    local cos_angle = math.max(-1, math.min(1, dot / (len1 * len2)))
    return math.acos(cos_angle)
end

-- Check if two segments are parallel (within a threshold angle)
-- Returns true if angle between segments is less than threshold or greater than pi - threshold
function path_utils.segments_are_parallel(seg1_start, seg1_end, seg2_start, seg2_end, threshold)
    threshold = threshold or (math.pi / 6)

    local dir1 = vector.direction(seg1_start, seg1_end)
    local dir2 = vector.direction(seg2_start, seg2_end)

    local angle = path_utils.angle_between_2d(dir1, dir2)

    return angle < threshold or angle > (math.pi - threshold)
end

-- Check if a direction is parallel to a segment
function path_utils.direction_parallel_to_segment(direction, seg_start, seg_end, threshold)
    threshold = threshold or (math.pi / 6)
    local seg_dir = vector.direction(seg_start, seg_end)
    local angle = path_utils.angle_between_2d(direction, seg_dir)
    return angle < threshold or angle > (math.pi - threshold)
end

-- Calculate the shortest distance from a point to a line segment (in 2D, XZ plane)
-- Returns the distance and the closest point on the segment
function path_utils.point_to_segment_distance(pos, seg_start, seg_end)
    local seg_dir = vector.subtract(seg_end, seg_start)
    local seg_len_sq = vector_xz_length_sq(seg_dir)

    if seg_len_sq < 1e-6 then
        return vector_xz_length(vector.subtract(pos, seg_start)), seg_start
    end

    local to_pos = vector.subtract(pos, seg_start)
    local t = vector_xz_dot(to_pos, seg_dir) / seg_len_sq
    t = math.max(0, math.min(1, t))

    local closest = vector.add(seg_start, vector.multiply(seg_dir, t))

    return vector.distance(pos, closest), closest
end

-- Calculate the intersection point between two line segments
-- Returns the intersection point, t1 (parameter along seg1), t2 (parameter along seg2)
-- or nil if segments don't intersect
function path_utils.calculate_segment_intersection(seg1_start, seg1_end, seg2_start, seg2_end)
    local d1 = vector.subtract(seg1_end, seg1_start)
    local d2 = vector.subtract(seg2_end, seg2_start)

    local cross = d1.x * d2.z - d1.z * d2.x

    -- Check if segments are parallel
    if math.abs(cross) < 1e-6 then
        return nil
    end

    local delta = vector.subtract(seg2_start, seg1_start)

    local t1 = (delta.x * d2.z - delta.z * d2.x) / cross
    local t2 = (delta.x * d1.z - delta.z * d1.x) / cross

    -- Check if intersection is within both segments
    if t1 < 0.01 or t1 > 0.99 or t2 < 0.01 or t2 > 0.99 then
        return nil
    end

    -- Calculate intersection point
    local intersection = vector.add(seg1_start, vector.multiply(d1, t1))
    local iy = (seg1_start.y + seg2_start.y) / 2

    return vector.new(intersection.x, iy, intersection.z), t1, t2
end

-- ============================================================
-- INTERNAL 2D DISTANCE HELPERS
-- ============================================================

local function segment_distance_2d(a1, a2, b1, b2)
    local a_dir = vector.subtract(a2, a1)
    local b_dir = vector.subtract(b2, b1)
    local d = vector.subtract(b1, a1)

    local len_a_sq = vector_xz_length_sq(a_dir)
    local len_b_sq = vector_xz_length_sq(b_dir)

    -- Handle degenerate cases (zero-length segments)
    if len_a_sq < 1e-10 and len_b_sq < 1e-10 then
        local dist = vector_xz_length(d)
        return dist, a1, b1
    end

    if len_a_sq < 1e-10 then
        local t = math.max(0, math.min(1, vector_xz_dot(d, b_dir) / len_b_sq))
        local closest_b = vector.add(b1, vector.multiply(b_dir, t))
        closest_b = vector.new(closest_b.x, (b1.y + b2.y) / 2, closest_b.z)
        local dist = vector_xz_length(vector.subtract(a1, closest_b))
        return dist, a1, closest_b
    end

    if len_b_sq < 1e-10 then
        local t = math.max(0, math.min(1, -vector_xz_dot(d, a_dir) / len_a_sq))
        local closest_a = vector.add(a1, vector.multiply(a_dir, t))
        closest_a = vector.new(closest_a.x, (a1.y + a2.y) / 2, closest_a.z)
        local dist = vector_xz_length(vector.subtract(closest_a, b1))
        return dist, closest_a, b1
    end

    local dot_aa = len_a_sq
    local dot_bb = len_b_sq
    local dot_ab = vector_xz_dot(a_dir, b_dir)
    local dot_ad = vector_xz_dot(a_dir, d)
    local dot_bd = vector_xz_dot(b_dir, d)

    local s, t
    local denom = dot_aa * dot_bb - dot_ab * dot_ab

    if math.abs(denom) < 1e-10 then
        s = 0
        t = dot_bd / dot_bb
    else
        s = (dot_ab * dot_bd - dot_bb * dot_ad) / denom
        t = (dot_aa * dot_bd - dot_ab * dot_ad) / denom
    end

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

    local closest_a = vector.add(a1, vector.multiply(a_dir, s))
    local closest_b = vector.add(b1, vector.multiply(b_dir, t))

    local dist = vector_xz_length(vector.subtract(closest_a, closest_b))

    return dist, closest_a, closest_b
end

function path_utils.segment_intersects(a1, a2, b1, b2, margin)
    margin = margin or 0

    local dist, closest_a, closest_b = segment_distance_2d(a1, a2, b1, b2)

    if dist <= margin then
        local midpoint = vector.multiply(vector.add(closest_a, closest_b), 0.5)
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

function path_utils.point_to_segment_distance_2d(p, seg_start, seg_end)
    local seg_dir = vector.subtract(seg_end, seg_start)
    local len_sq = vector_xz_length_sq(seg_dir)

    if len_sq < 1e-10 then
        local dist = vector_xz_length(vector.subtract(p, seg_start))
        return dist, seg_start
    end

    local t = vector_xz_dot(vector.subtract(p, seg_start), seg_dir) / len_sq
    t = math.max(0, math.min(1, t))

    local closest = vector.add(seg_start, vector.multiply(seg_dir, t))

    local dist = vector_xz_length(vector.subtract(p, closest))
    return dist, closest
end

-- Find intersection point between a line segment and a grid line
-- Returns the intersection point and t parameter, or nil if no intersection
function path_utils.segment_grid_intersection(seg_start, seg_end, grid_coord, is_x_grid)
    local start_coord, end_coord
    local other_start, other_end

    if is_x_grid then
        start_coord = seg_start.x
        end_coord = seg_end.x
        other_start = seg_start.z
        other_end = seg_end.z
    else
        start_coord = seg_start.z
        end_coord = seg_end.z
        other_start = seg_start.x
        other_end = seg_end.x
    end

    if (start_coord < grid_coord and end_coord < grid_coord) or
       (start_coord > grid_coord and end_coord > grid_coord) then
        return nil
    end

    if math.abs(end_coord - start_coord) < 1e-6 then
        return nil
    end

    local t = (grid_coord - start_coord) / (end_coord - start_coord)

    if t < 0.01 or t > 0.99 then
        return nil
    end

    local other_coord = other_start + t * (other_end - other_start)
    local y_coord = seg_start.y + t * (seg_end.y - seg_start.y)

    if is_x_grid then
        return vector.new(grid_coord, y_coord, other_coord), t
    else
        return vector.new(other_coord, y_coord, grid_coord), t
    end
end

return path_utils
