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
local cpml = pcity_cpml_proxy
local sizes = dofile(mod_path.."/sizes.lua")
local path_utils = pcmg.path_utils

local pathpaver_margin = sizes.citychunk.overgen_margin
local margin_vector = vector.new(1, 1, 1) * pathpaver_margin
local margin_min = sizes.citychunk.pos_min - margin_vector
local margin_max = sizes.citychunk.pos_max + margin_vector

--[[
    Pathpaver
    1. stores point data for a given citychunk
    2. stores path data for a given citychunk
    3. helps check for collisions
--]]

pcmg.pathpaver = {}
local pathpaver = pcmg.pathpaver
pathpaver.__index = pathpaver

function pathpaver.new(citychunk_origin)
    local p = {}
    p.origin = vector.copy(citychunk_origin)
    p.margin_min = p.origin + margin_min
    p.margin_max = p.origin + margin_max
    p.paths = {}
    p.points = setmetatable({}, {__mode = "kv"})
    return setmetatable(p, pathpaver)
end

-- Checks if position 'pos' is inside the citychunk and its
-- overgeneration area. Returns a boolean.
function pathpaver:pos_in_margin(pos)
    return vector.in_area(pos, self.margin_min, self.margin_max)
end

-- Checks if position 'pos' is inside the citychunk (NOT including its
-- overgeneration area. Returns a boolean.
function pathpaver:pos_in_citychunk(pos)
    return vector.in_area(pos, self.origin, self.origin +
                          sizes.citychunk.pos_max)
end

function pathpaver.check(p)
    return getmetatable(p) == pathpaver
end

-- Saves the 'pnt' point in the pathpaver.
function pathpaver:save_point(pnt)
    if self:pos_in_margin(pnt.pos) then
        self.points[pnt] = pnt
    end
end

-- Saves a path and all its points in the pathpaver
function pathpaver:save_path(pth)
    self.paths[pth] = pth
    local points = pth:all_points()
    for _, p in ipairs(points) do
        self:save_point(p)
    end
end

-- Returns all points that belong to paths saved in this pathpaver
function pathpaver:path_points()
    local all = {}
    for _, pth in pairs(self.paths) do
        local points = pth:all_points()
        for _, p in pairs(points) do
            all[p] = p
        end
    end
    return all
end

-- Checks if a position given by 'pos' is contained in the radius of
-- a point given by 'radius'. Returns all points that contain the
-- position within the radius. Returns false if no colliding points
-- were found for the position. When 'only_paths' is 'true', the
-- function will only search in points that belong to paths saved in
-- the current pathpaver and won't include overgenerated points from
-- neighboring citychunks. When 'only_paths' is 'false' (the default),
-- the function will check all points in the pathpaver.
function pathpaver:colliding_points(pos, radius, only_paths)
    local colliding = {}
    local points = only_paths and self:path_points() or self.points
    for _, pnt in pairs(points) do
        local distance = vector.distance(pos, pnt.pos)
        if distance <= radius then
            table.insert(colliding, pnt)
        end
    end
    return colliding
end

-- Finds segments in the pathpaver that intersect with a segment
-- formed by 'pos1' and 'pos2' within the 'threshold'. It searches only
-- through the paths that belong to the current citychunk.
function pathpaver:colliding_segments(pos1, pos2, threshold)
    threshold = threshold or 1 -- one node by default
    local colliding = {}
    local seg1 = {pos1, pos2}
    for _, pth in pairs(self.paths) do
        local current_point = pth.start
        for _, p in pth.start:iterator() do
            local seg2 = {current_point.pos, p.pos}
            local intersections, distance =
                cpml.intersect.segment_segment(seg1, seg2, threshold)
            if intersections then
                local i1, i2 = intersections[1], intersections[2]
                table.insert(colliding, {segment = {current_point, p},
                                         intersections = {i1, i2},
                                         distance = distance})
            end
            current_point = p
        end
    end
    return colliding
end

-- ============================================================
-- PATH COLLECTION UTILITIES
-- ============================================================

-- Check if a path belongs to this pathpaver (is local)
function pathpaver:is_local_path(pth)
    return self.paths[pth] ~= nil
end

-- Get all paths from this pathpaver
-- additional_paths: extra paths to include (e.g., newly created ones not yet saved)
-- Returns all_paths (complete list) and local_paths (only from this citychunk)
function pathpaver:get_all_paths(additional_paths)
    additional_paths = additional_paths or {}
    local all_paths = {}
    local local_paths = {}
    local seen = {}
    
    -- Add additional paths first
    for _, pth in ipairs(additional_paths) do
        if pth and not seen[pth] then
            table.insert(all_paths, pth)
            table.insert(local_paths, pth)
            seen[pth] = true
        end
    end
    
    -- Add paths from this pathpaver
    for _, pth in pairs(self.paths) do
        if pth and not seen[pth] then
            table.insert(all_paths, pth)
            table.insert(local_paths, pth)
            seen[pth] = true
        end
    end
    
    return all_paths, local_paths
end

-- ============================================================
-- INTERSECTION UTILITIES
-- ============================================================

-- Find all paths that a segment intersects with
-- Returns list of intersection data
function pathpaver:find_segment_path_intersections(seg_start, seg_end, skip_paths, margin)
    margin = margin or 1
    skip_paths = skip_paths or {}
    local intersections = {}
    
    -- Convert skip_paths to a lookup table
    local skip_lookup = {}
    for _, pth in ipairs(skip_paths) do
        skip_lookup[pth] = true
    end
    
    for _, pth in pairs(self.paths) do
        if not skip_lookup[pth] then
            local path_intersections = pth:intersects_segment(seg_start, seg_end, margin)
            for _, int_data in ipairs(path_intersections) do
                int_data.path = pth
                table.insert(intersections, int_data)
            end
        end
    end
    
    return intersections
end

-- Check if a proposed path segment would be too close to existing parallel paths
-- direction: the direction of the proposed segment
-- min_spacing: minimum allowed distance to parallel segments
function pathpaver:segment_too_close_to_parallel(start_pos, end_pos, direction, min_spacing, skip_paths)
    skip_paths = skip_paths or {}
    local skip_lookup = {}
    for _, pth in ipairs(skip_paths) do
        skip_lookup[pth] = true
    end
    
    local street_length = vector.distance(start_pos, end_pos)
    local num_samples = math.max(3, math.floor(street_length / 30))
    
    for _, existing in pairs(self.paths) do
        if not skip_lookup[existing] then
            local existing_segments = existing:all_segments()
            
            for _, seg in ipairs(existing_segments) do
                -- Check if direction is parallel to this segment
                if path_utils.direction_parallel_to_segment(direction, seg.start_pos, seg.end_pos) then
                    -- Sample points along the proposed segment
                    for i = 0, num_samples do
                        local t = i / num_samples
                        local sample = vector.new(
                            start_pos.x + t * (end_pos.x - start_pos.x),
                            start_pos.y + t * (end_pos.y - start_pos.y),
                            start_pos.z + t * (end_pos.z - start_pos.z)
                        )
                        
                        local dist = path_utils.point_to_segment_distance(sample, seg.start_pos, seg.end_pos)
                        
                        if dist < min_spacing then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

-- Check if a proposed segment overlaps with any existing parallel segment
-- Returns true and the overlap point if overlap is found
function pathpaver:check_parallel_overlap(seg_start, seg_end, margin, skip_paths)
    skip_paths = skip_paths or {}
    local skip_lookup = {}
    for _, pth in ipairs(skip_paths) do
        skip_lookup[pth] = true
    end
    
    for _, existing in pairs(self.paths) do
        if not skip_lookup[existing] then
            local existing_segments = existing:all_segments()
            
            for _, es in ipairs(existing_segments) do
                if path_utils.segments_are_parallel(seg_start, seg_end, es.start_pos, es.end_pos) then
                    -- Check for overlap by sampling
                    for i = 0, 5 do
                        local t = i / 5
                        local sample = vector.new(
                            seg_start.x + t * (seg_end.x - seg_start.x),
                            seg_start.y + t * (seg_end.y - seg_start.y),
                            seg_start.z + t * (seg_end.z - seg_start.z)
                        )
                        
                        local intersection = path_utils.segment_intersects(
                            sample, sample, es.start_pos, es.end_pos, margin
                        )
                        if intersection then
                            return true, sample, existing
                        end
                    end
                end
            end
        end
    end
    
    return false, nil, nil
end

-- Find a merge target for a street endpoint
-- Searches for paths that the street could connect to
function pathpaver:find_merge_target(end_pos, direction, search_radius, min_distance, skip_paths)
    skip_paths = skip_paths or {}
    local skip_lookup = {}
    for _, pth in ipairs(skip_paths) do
        skip_lookup[pth] = true
    end
    
    local best_path = nil
    local best_pos = nil
    local best_dist = search_radius
    
    local search_end = vector.add(end_pos, vector.multiply(direction, search_radius))
    
    for _, existing in pairs(self.paths) do
        if not skip_lookup[existing] then
            local segments = existing:all_segments()
            for _, seg in ipairs(segments) do
                local int_pos = path_utils.calculate_segment_intersection(
                    end_pos, search_end,
                    seg.start_pos, seg.end_pos
                )
                
                if int_pos then
                    local dist = vector.distance(end_pos, int_pos)
                    
                    if dist >= min_distance and dist < best_dist then
                        if not path_utils.segments_are_parallel(end_pos, search_end, seg.start_pos, seg.end_pos) then
                            best_path = existing
                            best_pos = int_pos
                            best_dist = dist
                        end
                    end
                end
            end
        end
    end
    
    return best_path, best_pos
end
