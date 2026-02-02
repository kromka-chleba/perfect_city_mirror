--[[
    This is a part of "Perfect City".
    Copyright (C) 2023-2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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
local pcmg = pcity_mapgen
local units = pcmg.units
local math = math
local sizes = dofile(mod_path.."/sizes.lua")
local _, materials_by_name = dofile(mod_path.."/canvas_ids.lua")
local units = sizes.units
local canvas_shapes = pcmg.canvas_shapes
local canvas_brush = pcmg.canvas_brush

-- Get mapgen seed for deterministic random generation
local mapgen_seed = tonumber(minetest.get_mapgen_setting("seed")) or 0

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

local road_margin = 40
if citychunk.in_mapchunks == 1 then
    road_margin = 15
end

-- Set random seed based on mapgen seed and position
local function set_position_seed(pos, salt)
    salt = salt or 0
    local seed = mapgen_seed + 
                 pos.x * 73856093 + 
                 pos.y * 19349663 + 
                 pos.z * 83492791 + 
                 salt
    math.randomseed(seed)
end

local function set_citychunk_seed(citychunk_origin, salt)
    set_position_seed(citychunk_origin, salt)
end

-- Returns road origin points for the bottom (X) and left (Z) edges
local function halfchunk_ori(citychunk_coords)
    local origin = units.citychunk_to_node(citychunk_coords)
    set_position_seed(origin, 1)
    local random_x = math.random(0 + road_margin, citychunk.in_nodes - 1 - road_margin)
    local x_edge_ori = origin + vector.new(random_x, 0, 0)
    local random_z = math.random(0 + road_margin, citychunk.in_nodes - 1 - road_margin)
    local z_edge_ori = origin + vector.new(0, 0, random_z)
    return x_edge_ori, z_edge_ori
end

-- Returns all road origin points for the citychunk
function pcmg.citychunk_road_origins(citychunk_origin)
    local citychunk_coords = pcmg.citychunk_coords(citychunk_origin)
    local up_coords = citychunk_coords + vector.new(0, 0, 1)
    local right_coords = citychunk_coords + vector.new(1, 0, 0)
    local bottom, left = halfchunk_ori(citychunk_coords)
    local up, _ = halfchunk_ori(up_coords)
    local _, right = halfchunk_ori(right_coords)
    return {bottom, left, up, right}
end

local function connect_road_origins(citychunk_origin, road_origins)
    local points = {}
    for _, origin in pairs(road_origins) do
        table.insert(points, vector.new(origin))
    end
    set_citychunk_seed(citychunk_origin, 2)
    if #points % 2 ~= 0 then
        table.remove(points)
    end
    local point_pairs = {}
    while (#points > 0) do
        local p1_index = math.random(1, #points)
        local p1 = points[p1_index]
        table.remove(points, p1_index)
        local p2_index = math.random(1, #points)
        local p2 = points[p2_index]
        table.remove(points, p2_index)
        table.insert(point_pairs, {p1, p2})
    end
    return point_pairs
end

-- Material IDs
local road_asphalt_id = materials_by_name["road_asphalt"]
local road_pavement_id = materials_by_name["road_pavement"]
local road_center_id = materials_by_name["road_center"]
local road_origin_id = materials_by_name["road_origin"]
local road_midpoint_id = materials_by_name["road_midpoint"]

local road_radius = 9
local pavement_radius = 13

local road_shape = canvas_shapes.combine_shapes(
    canvas_shapes.make_circle(pavement_radius, road_pavement_id),
    canvas_shapes.make_circle(road_radius, road_asphalt_id)
)

local midpoint_shape = pcmg.canvas_shapes.make_circle(1, road_midpoint_id)
local origin_shape = pcmg.canvas_shapes.make_circle(1, road_origin_id)

-- Street shapes (narrower than main roads)
local street_radius = 5
local street_pavement_radius = 8

local street_shape = canvas_shapes.combine_shapes(
    canvas_shapes.make_circle(street_pavement_radius, road_pavement_id),
    canvas_shapes.make_circle(street_radius, road_asphalt_id)
)

-- Secondary street shapes (even narrower)
local secondary_street_radius = 3
local secondary_street_pavement_radius = 5

local secondary_street_shape = canvas_shapes.combine_shapes(
    canvas_shapes.make_circle(secondary_street_pavement_radius, road_pavement_id),
    canvas_shapes.make_circle(secondary_street_radius, road_asphalt_id)
)

--[[
    Street Generation Configuration
    
    Streets are spaced evenly along roads with minimum spacing of 60 nodes.
    This creates a regular grid-like pattern while still allowing some variation.
--]]
local street_config = {
    -- Minimum spacing between streets (enforced)
    min_street_spacing = 60,
    
    -- Subdivision settings (should match or exceed min_street_spacing)
    road_subdivision_length = 60,
    street_subdivision_length = 60,
    
    -- Primary streets (from main roads)
    primary_branch_probability = 0.7,    -- Higher probability since spacing is enforced
    primary_min_length = 100,
    primary_max_length = 200,
    
    -- Secondary streets (from primary streets) - longer now
    secondary_branch_probability = 0.6,
    secondary_min_length = 80,
    secondary_max_length = 160,
    
    -- Tertiary streets (from secondary streets)
    tertiary_branch_probability = 0.4,
    tertiary_min_length = 50,
    tertiary_max_length = 100,
    
    -- Quaternary streets (from tertiary streets)
    quaternary_branch_probability = 0.3,
    quaternary_min_length = 30,
    quaternary_max_length = 60,
    
    -- Merging settings
    merge_probability = 0.6,
    merge_search_radius = 100,
    min_merge_distance = 30,
    
    -- Collision settings
    parallel_overlap_margin = 25,        -- Increased to prevent close parallel streets
    intersection_margin = 3,
    min_street_length = 20,
    parallel_check_samples = 5,
}

local function draw_points(megacanv, points)
    for _, point in pairs(points) do
        megacanv:set_all_cursors(point)
        megacanv:draw_shape(origin_shape)
    end
end

local road_metastore = pcmg.metastore.new()

local function build_road(megapathpav, start, finish)
    local start_point = pcmg.point.new(start)
    local finish_point = pcmg.point.new(finish)
    local guide_path = pcmg.path.new(start_point, finish_point)
    guide_path:make_slanted()
    local current_point = guide_path.start
    for nr, p in guide_path.start:iterator() do
        local colliding =
            megapathpav:colliding_segments(current_point.pos, p.pos, 1)
        if next(colliding) then
            guide_path:insert(pcmg.point.new(colliding[1].intersections[1]), nr)
        end
        current_point = p
    end
    return guide_path
end

--[[
    Street Generation Algorithm - Even Distribution Tree Branching
    
    1. Subdivide roads/streets into segments of min_street_spacing length
    2. At each subdivision point, possibly create a perpendicular street
    3. Streets maintain minimum spacing from each other
    4. When streets would be too close, they either intersect cleanly or don't spawn
--]]

-- Get axis-aligned perpendicular direction
local function get_perpendicular_direction(segment_dir)
    local abs_x = math.abs(segment_dir.x)
    local abs_z = math.abs(segment_dir.z)
    
    if abs_x > abs_z then
        if math.random() > 0.5 then
            return vector.new(0, 0, 1)
        else
            return vector.new(0, 0, -1)
        end
    else
        if math.random() > 0.5 then
            return vector.new(1, 0, 0)
        else
            return vector.new(-1, 0, 0)
        end
    end
end

-- Calculate the angle between two direction vectors in 2D
local function angle_between_2d(dir1, dir2)
    local dot = dir1.x * dir2.x + dir1.z * dir2.z
    local len1 = math.sqrt(dir1.x * dir1.x + dir1.z * dir1.z)
    local len2 = math.sqrt(dir2.x * dir2.x + dir2.z * dir2.z)
    if len1 < 1e-6 or len2 < 1e-6 then
        return 0
    end
    local cos_angle = math.max(-1, math.min(1, dot / (len1 * len2)))
    return math.acos(cos_angle)
end

-- Check if two segments are roughly parallel
local function segments_are_parallel(seg1_start, seg1_end, seg2_start, seg2_end)
    local dir1 = vector.direction(seg1_start, seg1_end)
    local dir2 = vector.direction(seg2_start, seg2_end)
    local angle = angle_between_2d(dir1, dir2)
    return angle < (math.pi / 6) or angle > (math.pi - math.pi / 6)
end

-- Check if segments overlap when parallel
local function segments_overlap_parallel(seg1_start, seg1_end, seg2_start, seg2_end, margin)
    if not segments_are_parallel(seg1_start, seg1_end, seg2_start, seg2_end) then
        return false, nil
    end
    
    for i = 0, 5 do
        local t = i / 5
        local sample = vector.new(
            seg1_start.x + t * (seg1_end.x - seg1_start.x),
            seg1_start.y + t * (seg1_end.y - seg1_start.y),
            seg1_start.z + t * (seg1_end.z - seg1_start.z)
        )
        
        local intersection = pcmg.path.segment_intersects(
            sample, sample, seg2_start, seg2_end, margin
        )
        if intersection then
            return true, sample
        end
    end
    
    return false, nil
end

-- Get all paths for collision detection
local function get_all_paths(megapathpav, additional_paths)
    local all_paths = {}
    local local_paths = {}
    local seen = {}
    
    for _, path in ipairs(additional_paths) do
        if not seen[path] then
            table.insert(all_paths, path)
            table.insert(local_paths, path)
            seen[path] = true
        end
    end
    
    if megapathpav.central and megapathpav.central.paths then
        for _, path in pairs(megapathpav.central.paths) do
            if not seen[path] then
                table.insert(all_paths, path)
                table.insert(local_paths, path)
                seen[path] = true
            end
        end
    end
    
    if megapathpav.neighbors then
        for _, neighbor in ipairs(megapathpav.neighbors) do
            if neighbor.paths then
                for _, path in pairs(neighbor.paths) do
                    if not seen[path] then
                        table.insert(all_paths, path)
                        seen[path] = true
                    end
                end
            end
        end
    end
    
    return all_paths, local_paths
end

-- Check if path is local (can be modified)
local function is_local_path(path, local_paths)
    for _, lp in ipairs(local_paths) do
        if path == lp then return true end
    end
    return false
end

-- Find segment containing a position
local function find_segment_at(pth, pos, tolerance)
    tolerance = tolerance or 5
    local segments = pth:all_segments()
    
    for _, seg in ipairs(segments) do
        local mid = vector.new(
            (seg.start_pos.x + seg.end_pos.x) / 2,
            (seg.start_pos.y + seg.end_pos.y) / 2,
            (seg.start_pos.z + seg.end_pos.z) / 2
        )
        local len = vector.distance(seg.start_pos, seg.end_pos)
        
        if vector.distance(mid, pos) < len / 2 + tolerance then
            if seg.start_point and seg.end_point and
               seg.start_point.next == seg.end_point then
                return seg
            end
        end
    end
    return nil
end

-- Insert intersection point into path
local function insert_intersection(pth, pos, seg)
    if not seg then return nil end
    if not seg.start_point or not seg.end_point then return nil end
    if seg.start_point.next ~= seg.end_point then return nil end
    
    if vector.distance(seg.start_point.pos, pos) < 2 then
        return seg.start_point
    end
    if vector.distance(seg.end_point.pos, pos) < 2 then
        return seg.end_point
    end
    
    local new_point = pcmg.point.new(pos)
    pth:insert_between(seg.start_point, seg.end_point, new_point)
    return new_point
end

-- Check if a position is too close to any existing street start point
-- This enforces minimum spacing between parallel streets
local function is_too_close_to_existing_streets(pos, direction, all_paths, parent_path, min_spacing)
    for _, existing in ipairs(all_paths) do
        if existing == parent_path then goto continue end
        
        -- Check distance to start of existing path
        local start_pos = existing.start.pos
        local dist = vector.distance(pos, start_pos)
        
        if dist < min_spacing then
            -- Check if streets would be parallel (going same direction)
            local existing_dir = vector.direction(existing.start.pos, existing.finish.pos)
            if segments_are_parallel(pos, vector.add(pos, direction), start_pos, existing.finish.pos) then
                return true
            end
        end
        
        -- Also check along the path for parallel segments nearby
        local segments = existing:all_segments()
        for _, seg in ipairs(segments) do
            -- Find closest point on segment to our position
            local seg_dir = vector.subtract(seg.end_pos, seg.start_pos)
            local seg_len = vector.length(seg_dir)
            if seg_len > 0 then
                local to_pos = vector.subtract(pos, seg.start_pos)
                local t = (to_pos.x * seg_dir.x + to_pos.z * seg_dir.z) / (seg_len * seg_len)
                t = math.max(0, math.min(1, t))
                
                local closest = vector.new(
                    seg.start_pos.x + t * seg_dir.x,
                    seg.start_pos.y + t * seg_dir.y,
                    seg.start_pos.z + t * seg_dir.z
                )
                
                local dist_to_seg = vector.distance(pos, closest)
                
                if dist_to_seg < min_spacing then
                    -- Check if our street would be parallel to this segment
                    if segments_are_parallel(pos, vector.add(pos, direction), seg.start_pos, seg.end_pos) then
                        return true
                    end
                end
            end
        end
        
        ::continue::
    end
    
    return false
end

-- Check for parallel overlaps with existing paths
local function has_overlap(street, all_paths, parent_path, config)
    local street_segs = street:all_segments()
    
    for _, existing in ipairs(all_paths) do
        if existing == parent_path then goto continue end
        
        local dominated = street.start:attached_sorted()
        local is_parent = false
        for _, att in ipairs(dominated) do
            if att.path == existing then
                is_parent = true
                break
            end
        end
        if is_parent then goto continue end
        
        local existing_segs = existing:all_segments()
        
        for _, ss in ipairs(street_segs) do
            for _, es in ipairs(existing_segs) do
                local overlaps, point = segments_overlap_parallel(
                    ss.start_pos, ss.end_pos,
                    es.start_pos, es.end_pos,
                    config.parallel_overlap_margin
                )
                if overlaps then
                    return true, point
                end
            end
        end
        
        ::continue::
    end
    
    return false, nil
end

-- Find intersections with other paths
local function find_intersections(street, all_paths, local_paths, parent_path, config)
    local results = {}
    local street_points = street:all_points()
    
    for _, existing in ipairs(all_paths) do
        if existing == parent_path then goto continue end
        
        local dominated = street.start:attached_sorted()
        local is_parent = false
        for _, att in ipairs(dominated) do
            if att.path == existing then
                is_parent = true
                break
            end
        end
        if is_parent then goto continue end
        
        local intersections = street:intersects_path(existing, config.intersection_margin)
        
        for _, int in ipairs(intersections) do
            local ss = int.self_segment
            local os = int.other_segment
            
            if not segments_are_parallel(ss.start_pos, ss.end_pos, os.start_pos, os.end_pos) then
                local dist = 0
                for i = 2, int.self_segment_index do
                    dist = dist + vector.distance(street_points[i-1].pos, street_points[i].pos)
                end
                dist = dist + vector.distance(ss.start_pos, int.point_a)
                
                table.insert(results, {
                    intersection = int,
                    existing_path = existing,
                    distance = dist,
                    is_local = is_local_path(existing, local_paths)
                })
            end
        end
        
        ::continue::
    end
    
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

-- Find a path to merge into
local function find_merge_target(end_pos, direction, all_paths, parent_path, config)
    local best_path = nil
    local best_pos = nil
    local best_dist = config.merge_search_radius
    
    local search_end = vector.add(end_pos, vector.multiply(direction, config.merge_search_radius))
    
    for _, existing in ipairs(all_paths) do
        if existing == parent_path then goto continue end
        
        local segments = existing:all_segments()
        for _, seg in ipairs(segments) do
            local intersection = pcmg.path.segment_intersects(
                end_pos, search_end,
                seg.start_pos, seg.end_pos,
                config.intersection_margin
            )
            
            if intersection then
                local int_pos = intersection.midpoint
                if int_pos then
                    local dist = vector.distance(end_pos, int_pos)
                    
                    if dist >= config.min_merge_distance and dist < best_dist then
                        if not segments_are_parallel(end_pos, search_end, seg.start_pos, seg.end_pos) then
                            best_path = existing
                            best_pos = int_pos
                            best_dist = dist
                        end
                    end
                end
            end
        end
        
        ::continue::
    end
    
    return best_path, best_pos
end

-- Create a street from a branching point
local function create_street(branch_point, direction, length, parent_path, all_paths, local_paths, config)
    local start_pos = branch_point.pos
    
    -- Check if too close to existing parallel streets before creating
    if is_too_close_to_existing_streets(start_pos, direction, all_paths, parent_path, config.min_street_spacing) then
        return nil
    end
    
    local end_pos = vector.add(start_pos, vector.multiply(direction, length))
    
    -- Round to grid
    end_pos.x = math.floor(end_pos.x + 0.5)
    end_pos.y = math.floor(end_pos.y + 0.5)
    end_pos.z = math.floor(end_pos.z + 0.5)
    
    -- Create path using branch
    local finish_point = pcmg.point.new(end_pos)
    local street = branch_point:branch(finish_point)
    
    -- Check for parallel overlaps
    local overlaps, overlap_point = has_overlap(street, all_paths, parent_path, config)
    if overlaps then
        local points = street:all_points()
        local cut_point = nil
        local cut_dist = 0
        
        for i = 2, #points do
            local seg_mid = vector.new(
                (points[i-1].pos.x + points[i].pos.x) / 2,
                (points[i-1].pos.y + points[i].pos.y) / 2,
                (points[i-1].pos.z + points[i].pos.z) / 2
            )
            if vector.distance(seg_mid, overlap_point) < config.parallel_overlap_margin * 2 then
                if i > 2 then
                    cut_point = points[i-1]
                end
                break
            end
            cut_dist = cut_dist + vector.distance(points[i-1].pos, points[i].pos)
        end
        
        if cut_point and cut_dist >= config.min_street_length then
            street:cut_off(cut_point)
        else
            return nil
        end
    end
    
    -- Check length
    if street:length() < config.min_street_length then
        return nil
    end
    
    -- Try to merge into another path
    if math.random() < config.merge_probability then
        local merge_path, merge_pos = find_merge_target(
            street.finish.pos, direction, all_paths, parent_path, config
        )
        if merge_path and merge_pos then
            local new_finish = pcmg.point.new(merge_pos)
            street:set_finish(new_finish)
            
            if is_local_path(merge_path, local_paths) then
                local seg = find_segment_at(merge_path, merge_pos)
                if seg then
                    insert_intersection(merge_path, merge_pos, seg)
                end
            end
        end
    end
    
    -- Find and create intersection points
    local intersections = find_intersections(street, all_paths, local_paths, parent_path, config)
    for _, int_data in ipairs(intersections) do
        local pos = int_data.intersection.midpoint
        if pos then
            if int_data.is_local then
                local seg = find_segment_at(int_data.existing_path, pos)
                if seg then
                    insert_intersection(int_data.existing_path, pos, seg)
                end
            end
            
            local seg = find_segment_at(street, pos)
            if seg then
                insert_intersection(street, pos, seg)
            end
        end
    end
    
    return street
end

-- Get evenly spaced branching points from a path
local function get_branch_points(pth, subdivision_length)
    -- Subdivide to create intermediate points at regular intervals
    pth:subdivide(subdivision_length)
    
    -- Collect all intermediate points (not start or finish)
    local points = {}
    local all = pth:all_points()
    
    for i = 2, #all - 1 do
        local prev_pos = all[i - 1].pos
        local curr_pos = all[i].pos
        local next_pos = all[i + 1].pos
        
        local segment_dir = vector.direction(prev_pos, next_pos)
        
        table.insert(points, {
            point = all[i],
            segment_dir = segment_dir,
            index = i,
        })
    end
    
    return points
end

-- Recursive street generation with even spacing
local function generate_streets_recursive(parent_path, depth, all_paths, local_paths, config)
    local created = {}
    
    -- Get parameters based on depth
    local branch_prob, min_len, max_len, subdiv_len
    
    if depth == 0 then
        branch_prob = config.primary_branch_probability
        min_len = config.primary_min_length
        max_len = config.primary_max_length
        subdiv_len = config.road_subdivision_length
    elseif depth == 1 then
        branch_prob = config.secondary_branch_probability
        min_len = config.secondary_min_length
        max_len = config.secondary_max_length
        subdiv_len = config.street_subdivision_length
    elseif depth == 2 then
        branch_prob = config.tertiary_branch_probability
        min_len = config.tertiary_min_length
        max_len = config.tertiary_max_length
        subdiv_len = config.street_subdivision_length
    elseif depth == 3 then
        branch_prob = config.quaternary_branch_probability
        min_len = config.quaternary_min_length
        max_len = config.quaternary_max_length
        subdiv_len = config.street_subdivision_length
    else
        return created
    end
    
    -- Get branching points at regular intervals
    local branch_points = get_branch_points(parent_path, subdiv_len)
    
    -- Track last branch position to ensure spacing
    local last_branch_pos = nil
    
    for _, bp in ipairs(branch_points) do
        -- Check spacing from last branch on this path
        if last_branch_pos then
            local dist = vector.distance(bp.point.pos, last_branch_pos)
            if dist < config.min_street_spacing then
                goto continue
            end
        end
        
        if math.random() < branch_prob then
            local direction = get_perpendicular_direction(bp.segment_dir)
            local length = math.random(min_len, max_len)
            
            local street = create_street(
                bp.point, direction, length,
                parent_path, all_paths, local_paths, config
            )
            
            if street then
                last_branch_pos = bp.point.pos
                
                table.insert(created, {street = street, depth = depth})
                table.insert(all_paths, street)
                table.insert(local_paths, street)
                
                -- Recursively create sub-branches
                local sub_streets = generate_streets_recursive(
                    street, depth + 1, all_paths, local_paths, config
                )
                for _, ss in ipairs(sub_streets) do
                    table.insert(created, ss)
                end
            end
        end
        
        ::continue::
    end
    
    return created
end

-- Generate all streets from main roads
local function generate_street_network(megapathpav, main_roads, config)
    local all_paths, local_paths = get_all_paths(megapathpav, main_roads)
    local all_streets = {}
    
    for _, road in ipairs(main_roads) do
        local streets = generate_streets_recursive(road, 0, all_paths, local_paths, config)
        for _, s in ipairs(streets) do
            table.insert(all_streets, s)
        end
    end
    
    return all_streets
end

-- Draw streets based on depth
local function draw_streets(megacanv, all_streets)
    for _, street_data in ipairs(all_streets) do
        local street = street_data.street
        local depth = street_data.depth
        
        if depth == 0 then
            megacanv:draw_path(street_shape, street, "straight")
        else
            megacanv:draw_path(secondary_street_shape, street, "straight")
        end
        megacanv:draw_path_points(midpoint_shape, street)
    end
end

-- Main generation pipeline
local function generate_and_draw_streets(megacanv, megapathpav, main_roads, config)
    local all_streets = generate_street_network(megapathpav, main_roads, config)
    
    for _, street_data in ipairs(all_streets) do
        megapathpav:save_path(street_data.street)
    end
    
    draw_streets(megacanv, all_streets)
    
    return all_streets
end

local function road_generator(megacanv, pathpaver_cache)
    megacanv:set_metastore(road_metastore)
    
    set_citychunk_seed(megacanv.origin, 0)
    
    local road_origins = pcmg.citychunk_road_origins(megacanv.origin)
    local connected_points = connect_road_origins(megacanv.origin, road_origins)
    local megapathpav = pcmg.megapathpaver.new(megacanv.origin, pathpaver_cache)
    
    local main_roads = {}
    for _, points in ipairs(connected_points) do
        local start = points[1]
        local finish = points[2]
        local path = build_road(megapathpav, start, finish)
        megapathpav:save_path(path)
        table.insert(main_roads, path)
        draw_points(megacanv, road_origins)
    end
    
    for _, path in pairs(megapathpav.paths) do
        megacanv:draw_path(road_shape, path, "straight")
        megacanv:draw_path_points(midpoint_shape, path)
    end
    
    generate_and_draw_streets(megacanv, megapathpav, main_roads, street_config)
end

function pcmg.generate_roads(megacanv, pathpaver_cache)
    local t1 = minetest.get_us_time()
    megacanv:generate(road_generator, 1, pathpaver_cache)
end