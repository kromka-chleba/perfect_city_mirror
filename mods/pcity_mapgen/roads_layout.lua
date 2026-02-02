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
local path_utils = pcmg.path_utils

-- Get mapgen seed for deterministic random generation
local mapgen_seed = tonumber(minetest.get_mapgen_setting("seed")) or 0

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

-- Grid spacing for all road/street points (1 mapchunk = 80 nodes)
local grid_spacing = 80

-- Border connection point configuration
local border_grid_spacing = grid_spacing
local border_point_probability = 0.6
local road_origin_margin = 80

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

-- ============================================================
-- ROAD ORIGIN GENERATION
-- ============================================================

-- Get all grid-aligned points along a citychunk border
local function get_grid_points_on_border(citychunk_origin, border_edge)
    local min_x = citychunk_origin.x
    local max_x = citychunk_origin.x + citychunk.in_nodes - 1
    local min_z = citychunk_origin.z
    local max_z = citychunk_origin.z + citychunk.in_nodes - 1
    local y = citychunk_origin.y
    
    local points = {}
    
    if border_edge == "x_min" or border_edge == "x_max" then
        local x = (border_edge == "x_min") and min_x or max_x
        local first_z = math.ceil(min_z / grid_spacing) * grid_spacing
        local z = first_z
        while z <= max_z do
            if z > min_z and z < max_z then
                table.insert(points, vector.new(x, y, z))
            end
            z = z + grid_spacing
        end
    else
        local z = (border_edge == "z_min") and min_z or max_z
        local first_x = math.ceil(min_x / grid_spacing) * grid_spacing
        local x = first_x
        while x <= max_x do
            if x > min_x and x < max_x then
                table.insert(points, vector.new(x, y, z))
            end
            x = x + grid_spacing
        end
    end
    
    return points
end

-- Returns a random grid-aligned road origin point for the given border edge
local function get_road_origin_on_border(citychunk_origin, border_edge, salt)
    local grid_points = get_grid_points_on_border(citychunk_origin, border_edge)
    
    if #grid_points == 0 then
        local min_x = citychunk_origin.x
        local max_x = citychunk_origin.x + citychunk.in_nodes - 1
        local min_z = citychunk_origin.z
        local max_z = citychunk_origin.z + citychunk.in_nodes - 1
        local y = citychunk_origin.y
        
        if border_edge == "x_min" then
            return vector.new(min_x, y, (min_z + max_z) / 2)
        elseif border_edge == "x_max" then
            return vector.new(max_x, y, (min_z + max_z) / 2)
        elseif border_edge == "z_min" then
            return vector.new((min_x + max_x) / 2, y, min_z)
        else
            return vector.new((min_x + max_x) / 2, y, max_z)
        end
    end
    
    local border_coord
    if border_edge == "x_min" then
        border_coord = citychunk_origin.x
    elseif border_edge == "x_max" then
        border_coord = citychunk_origin.x + citychunk.in_nodes - 1
    elseif border_edge == "z_min" then
        border_coord = citychunk_origin.z
    else
        border_coord = citychunk_origin.z + citychunk.in_nodes - 1
    end
    
    local border_seed = mapgen_seed + border_coord * 73856093 + salt * 83492791
    math.randomseed(border_seed)
    
    local index = math.random(1, #grid_points)
    return grid_points[index]
end

local function halfchunk_ori(citychunk_coords)
    local origin = units.citychunk_to_node(citychunk_coords)
    local x_edge_ori = get_road_origin_on_border(origin, "z_min", 1)
    local z_edge_ori = get_road_origin_on_border(origin, "x_min", 2)
    return x_edge_ori, z_edge_ori
end

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

-- ============================================================
-- MATERIALS AND SHAPES
-- ============================================================

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

local street_radius = 5
local street_pavement_radius = 8

local street_shape = canvas_shapes.combine_shapes(
    canvas_shapes.make_circle(street_pavement_radius, road_pavement_id),
    canvas_shapes.make_circle(street_radius, road_asphalt_id)
)

local secondary_street_radius = 3
local secondary_street_pavement_radius = 5

local secondary_street_shape = canvas_shapes.combine_shapes(
    canvas_shapes.make_circle(secondary_street_pavement_radius, road_pavement_id),
    canvas_shapes.make_circle(secondary_street_radius, road_asphalt_id)
)

-- ============================================================
-- STREET GENERATION CONFIGURATION
-- ============================================================

local street_config = {
    min_segment_length = 80,
    min_street_spacing = 70,
    road_subdivision_length = 100,
    street_subdivision_length = 100,
    
    primary_branch_probability = 0.9,
    primary_min_length = 200,
    primary_max_length = 500,
    
    secondary_branch_probability = 0.8,
    secondary_min_length = 150,
    secondary_max_length = 350,
    
    tertiary_branch_probability = 0.6,
    tertiary_min_length = 100,
    tertiary_max_length = 200,
    
    quaternary_branch_probability = 0.4,
    quaternary_min_length = 80,
    quaternary_max_length = 150,
    
    merge_probability = 0.7,
    merge_search_radius = 150,
    min_merge_distance = 50,
    
    border_connection_spacing = 80,
    border_snap_radius = 50,
    
    parallel_overlap_margin = 25,
    intersection_margin = 3,
    min_street_length = 80,
    
    min_intersection_point_distance = 5,
    branch_point_tolerance = 10,
}

-- ============================================================
-- DRAWING UTILITIES
-- ============================================================

local function draw_points(megacanv, points)
    for _, pt in pairs(points) do
        megacanv:set_all_cursors(pt)
        megacanv:draw_shape(origin_shape)
    end
end

local road_metastore = pcmg.metastore.new()

-- ============================================================
-- CITYCHUNK BOUNDARY UTILITIES
-- ============================================================

local function get_citychunk_bounds(citychunk_origin)
    local min_pos = vector.copy(citychunk_origin)
    local max_pos = vector.add(citychunk_origin, vector.new(
        citychunk.in_nodes - 1,
        0,
        citychunk.in_nodes - 1
    ))
    return min_pos, max_pos
end

local function is_inside_citychunk(pos, citychunk_origin)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    return pos.x >= min_pos.x and pos.x <= max_pos.x and
           pos.z >= min_pos.z and pos.z <= max_pos.z
end

local function is_on_citychunk_border(pos, citychunk_origin, tolerance)
    tolerance = tolerance or 1
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    
    local on_x_min = math.abs(pos.x - min_pos.x) <= tolerance
    local on_x_max = math.abs(pos.x - max_pos.x) <= tolerance
    local on_z_min = math.abs(pos.z - min_pos.z) <= tolerance
    local on_z_max = math.abs(pos.z - max_pos.z) <= tolerance
    
    local in_x_range = pos.x >= min_pos.x - tolerance and pos.x <= max_pos.x + tolerance
    local in_z_range = pos.z >= min_pos.z - tolerance and pos.z <= max_pos.z + tolerance
    
    return (on_x_min or on_x_max) and in_z_range or
           (on_z_min or on_z_max) and in_x_range
end

local function clamp_to_citychunk(pos, citychunk_origin)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    return vector.new(
        math.max(min_pos.x, math.min(max_pos.x, pos.x)),
        pos.y,
        math.max(min_pos.z, math.min(max_pos.z, pos.z))
    )
end

local function get_citychunk_border_intersection(start_pos, end_pos, citychunk_origin)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    
    local direction = vector.subtract(end_pos, start_pos)
    local length = vector.length(direction)
    if length < 1e-6 then
        return nil
    end
    direction = vector.divide(direction, length)
    
    local best_t = math.huge
    local best_pos = nil
    
    if direction.x < -1e-6 then
        local t = (min_pos.x - start_pos.x) / direction.x
        if t > 0 and t < best_t and t <= length then
            local z = start_pos.z + t * direction.z
            if z >= min_pos.z and z <= max_pos.z then
                best_t = t
                best_pos = vector.new(min_pos.x, start_pos.y, z)
            end
        end
    end
    
    if direction.x > 1e-6 then
        local t = (max_pos.x - start_pos.x) / direction.x
        if t > 0 and t < best_t and t <= length then
            local z = start_pos.z + t * direction.z
            if z >= min_pos.z and z <= max_pos.z then
                best_t = t
                best_pos = vector.new(max_pos.x, start_pos.y, z)
            end
        end
    end
    
    if direction.z < -1e-6 then
        local t = (min_pos.z - start_pos.z) / direction.z
        if t > 0 and t < best_t and t <= length then
            local x = start_pos.x + t * direction.x
            if x >= min_pos.x and x <= max_pos.x then
                best_t = t
                best_pos = vector.new(x, start_pos.y, min_pos.z)
            end
        end
    end
    
    if direction.z > 1e-6 then
        local t = (max_pos.z - start_pos.z) / direction.z
        if t > 0 and t < best_t and t <= length then
            local x = start_pos.x + t * direction.x
            if x >= min_pos.x and x <= max_pos.x then
                best_t = t
                best_pos = vector.new(x, start_pos.y, max_pos.z)
            end
        end
    end
    
    return best_pos, best_t
end

-- ============================================================
-- BORDER CONNECTION POINTS
-- ============================================================

local function get_all_road_origins_for_chunk(citychunk_origin)
    local citychunk_coords = pcmg.citychunk_coords(citychunk_origin)
    local up_coords = citychunk_coords + vector.new(0, 0, 1)
    local right_coords = citychunk_coords + vector.new(1, 0, 0)
    
    local bottom, left = halfchunk_ori(citychunk_coords)
    local up, _ = halfchunk_ori(up_coords)
    local _, right = halfchunk_ori(right_coords)
    
    return {bottom, left, up, right}
end

local function is_too_close_to_road_origins(pos, road_origins, margin)
    for _, origin in ipairs(road_origins) do
        local dist = math.sqrt((pos.x - origin.x)^2 + (pos.z - origin.z)^2)
        if dist < margin then
            return true
        end
    end
    return false
end

local function get_border_connection_points(citychunk_origin, border_edge, spacing)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    local points = {}
    
    local road_origins = get_all_road_origins_for_chunk(citychunk_origin)
    
    local border_coord, start_coord, end_coord, is_x_border
    
    if border_edge == "x_min" then
        border_coord = min_pos.x
        start_coord = min_pos.z
        end_coord = max_pos.z
        is_x_border = true
    elseif border_edge == "x_max" then
        border_coord = max_pos.x
        start_coord = min_pos.z
        end_coord = max_pos.z
        is_x_border = true
    elseif border_edge == "z_min" then
        border_coord = min_pos.z
        start_coord = min_pos.x
        end_coord = max_pos.x
        is_x_border = false
    else
        border_coord = max_pos.z
        start_coord = min_pos.x
        end_coord = max_pos.x
        is_x_border = false
    end
    
    local grid_start = math.ceil(start_coord / border_grid_spacing) * border_grid_spacing
    local base_border_seed = mapgen_seed + border_coord * 73856093
    
    local coord = grid_start
    while coord <= end_coord do
        if coord > start_coord and coord < end_coord then
            local point_seed = base_border_seed + coord * 19349663
            math.randomseed(point_seed)
            
            local candidate_point
            if is_x_border then
                candidate_point = vector.new(border_coord, min_pos.y, coord)
            else
                candidate_point = vector.new(coord, min_pos.y, border_coord)
            end
            
            if math.random() < border_point_probability then
                if not is_too_close_to_road_origins(candidate_point, road_origins, road_origin_margin) then
                    table.insert(points, candidate_point)
                end
            end
        end
        coord = coord + border_grid_spacing
    end
    
    return points
end

local function calculate_border_intersection(start_pos, direction, citychunk_origin)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    
    local t = math.huge
    local hit_border = nil
    
    if direction.x > 0.1 then
        local t_x = (max_pos.x - start_pos.x) / direction.x
        if t_x > 0 and t_x < t then
            t = t_x
            hit_border = "x_max"
        end
    elseif direction.x < -0.1 then
        local t_x = (min_pos.x - start_pos.x) / direction.x
        if t_x > 0 and t_x < t then
            t = t_x
            hit_border = "x_min"
        end
    end
    
    if direction.z > 0.1 then
        local t_z = (max_pos.z - start_pos.z) / direction.z
        if t_z > 0 and t_z < t then
            t = t_z
            hit_border = "z_max"
        end
    elseif direction.z < -0.1 then
        local t_z = (min_pos.z - start_pos.z) / direction.z
        if t_z > 0 and t_z < t then
            t = t_z
            hit_border = "z_min"
        end
    end
    
    if t == math.huge then
        return nil, nil, nil
    end
    
    local border_pos = vector.add(start_pos, vector.multiply(direction, t))
    border_pos.x = math.floor(border_pos.x + 0.5)
    border_pos.y = start_pos.y
    border_pos.z = math.floor(border_pos.z + 0.5)
    
    return border_pos, hit_border, t
end

local function find_nearest_connection_point(pos, citychunk_origin, border_edge, config)
    local connection_points = get_border_connection_points(
        citychunk_origin, border_edge, config.border_connection_spacing
    )
    
    local best_point = nil
    local best_dist = math.huge
    
    for _, cp in ipairs(connection_points) do
        local dist = vector.distance(pos, cp)
        if dist < best_dist then
            best_dist = dist
            best_point = cp
        end
    end
    
    return best_point, best_dist
end

local function snap_to_border_connection(start_pos, end_pos, direction, citychunk_origin, config)
    if not is_inside_citychunk(end_pos, citychunk_origin) then
        local border_intersection = get_citychunk_border_intersection(start_pos, end_pos, citychunk_origin)
        if border_intersection then
            end_pos = border_intersection
        else
            end_pos = clamp_to_citychunk(end_pos, citychunk_origin)
        end
    end
    
    local border_pos, border_edge, t = calculate_border_intersection(start_pos, direction, citychunk_origin)
    
    if not border_pos or not border_edge then
        return end_pos, false
    end
    
    local dist_to_border = vector.distance(start_pos, border_pos)
    local dist_to_end = vector.distance(start_pos, end_pos)
    
    if dist_to_end < dist_to_border - config.border_snap_radius then
        return end_pos, false
    end
    
    local connection_point, dist_to_connection = find_nearest_connection_point(
        border_pos, citychunk_origin, border_edge, config
    )
    
    if connection_point and dist_to_connection <= config.border_snap_radius then
        local new_length = vector.distance(start_pos, connection_point)
        if new_length >= config.min_segment_length then
            return connection_point, true
        end
    end
    
    if dist_to_border >= config.min_segment_length then
        return border_pos, false
    end
    
    return end_pos, false
end

-- ============================================================
-- ROAD BUILDING
-- ============================================================

local function build_road(megapathpav, start, finish)
    local start_point = pcmg.point.new(start)
    local finish_point = pcmg.point.new(finish)
    local guide_path = pcmg.path.new(start_point, finish_point)
    guide_path:make_slanted()
    local current_point = guide_path.start
    for nr, p in guide_path.start:iterator() do
        local colliding = megapathpav:colliding_segments(current_point.pos, p.pos, 1)
        if next(colliding) then
            guide_path:insert(pcmg.point.new(colliding[1].intersections[1]), nr)
        end
        current_point = p
    end
    return guide_path
end

-- ============================================================
-- STREET GENERATION UTILITIES
-- ============================================================

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

local function street_too_close_to_existing(start_pos, end_pos, direction, all_paths, parent_path, min_spacing)
    local street_length = vector.distance(start_pos, end_pos)
    local num_samples = math.max(3, math.floor(street_length / 30))
    
    for _, existing in ipairs(all_paths) do
        if existing == parent_path then goto continue_path end
        
        local existing_segments = existing:all_segments()
        
        for _, seg in ipairs(existing_segments) do
            if path_utils.direction_parallel_to_segment(direction, seg.start_pos, seg.end_pos) then
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
        
        ::continue_path::
    end
    
    return false
end

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
                if path_utils.segments_are_parallel(ss.start_pos, ss.end_pos, es.start_pos, es.end_pos) then
                    for i = 0, 5 do
                        local t = i / 5
                        local sample = vector.new(
                            ss.start_pos.x + t * (ss.end_pos.x - ss.start_pos.x),
                            ss.start_pos.y + t * (ss.end_pos.y - ss.start_pos.y),
                            ss.start_pos.z + t * (ss.end_pos.z - ss.start_pos.z)
                        )
                        
                        local intersection = path_utils.segment_intersects(
                            sample, sample, es.start_pos, es.end_pos, config.parallel_overlap_margin
                        )
                        if intersection then
                            return true, sample
                        end
                    end
                end
            end
        end
        
        ::continue::
    end
    
    return false, nil
end

local function find_merge_target(end_pos, direction, all_paths, parent_path, config, citychunk_origin)
    local best_path = nil
    local best_pos = nil
    local best_dist = config.merge_search_radius
    
    local search_end = vector.add(end_pos, vector.multiply(direction, config.merge_search_radius))
    
    if not is_inside_citychunk(search_end, citychunk_origin) then
        local border_intersection = get_citychunk_border_intersection(end_pos, search_end, citychunk_origin)
        if border_intersection then
            search_end = border_intersection
        end
    end
    
    for _, existing in ipairs(all_paths) do
        if existing == parent_path then goto continue end
        
        local segments = existing:all_segments()
        for _, seg in ipairs(segments) do
            local int_pos = path_utils.calculate_segment_intersection(
                end_pos, search_end,
                seg.start_pos, seg.end_pos
            )
            
            if int_pos then
                if is_inside_citychunk(int_pos, citychunk_origin) or 
                   is_on_citychunk_border(int_pos, citychunk_origin) then
                    local dist = vector.distance(end_pos, int_pos)
                    
                    if dist >= config.min_merge_distance and dist < best_dist then
                        if not path_utils.segments_are_parallel(end_pos, search_end, seg.start_pos, seg.end_pos) then
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

-- ============================================================
-- STREET CREATION
-- ============================================================

local function create_street(branch_point, direction, length, parent_path, all_paths, local_paths, citychunk_origin, config)
    local start_pos = branch_point.pos
    local end_pos = vector.add(start_pos, vector.multiply(direction, length))
    
    end_pos.x = math.floor(end_pos.x + 0.5)
    end_pos.y = math.floor(end_pos.y + 0.5)
    end_pos.z = math.floor(end_pos.z + 0.5)
    
    if not is_inside_citychunk(end_pos, citychunk_origin) then
        local border_intersection = get_citychunk_border_intersection(start_pos, end_pos, citychunk_origin)
        if border_intersection then
            end_pos = border_intersection
        else
            end_pos = clamp_to_citychunk(end_pos, citychunk_origin)
        end
    end
    
    local snapped_end, did_snap = snap_to_border_connection(
        start_pos, end_pos, direction, citychunk_origin, config
    )
    end_pos = snapped_end
    
    local street_length = vector.distance(start_pos, end_pos)
    if street_length < config.min_segment_length then
        return nil, false
    end
    
    if street_too_close_to_existing(start_pos, end_pos, direction, all_paths, parent_path, config.min_street_spacing) then
        return nil, false
    end
    
    -- Pre-check intersections
    local temp_path = pcmg.path.new(pcmg.point.new(start_pos), pcmg.point.new(end_pos))
    local pre_intersections = temp_path:find_intersections_with_paths(all_paths, start_pos, config.branch_point_tolerance)
    
    if #pre_intersections > 0 then
        if pre_intersections[1].distance_from_start < config.min_segment_length * 0.3 then
            return nil, false
        end
        
        for i = 1, #pre_intersections - 1 do
            local spacing = pre_intersections[i + 1].distance_from_start - pre_intersections[i].distance_from_start
            if spacing < config.min_intersection_point_distance then
                return nil, false
            end
        end
    end
    
    -- Create the actual street
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
        
        if cut_point and cut_dist >= config.min_segment_length then
            street:cut_off(cut_point)
            did_snap = false
        else
            return nil, false
        end
    end
    
    if street:length() < config.min_segment_length then
        return nil, false
    end
    
    -- Try to merge
    if not did_snap and math.random() < config.merge_probability then
        local merge_path, merge_pos = find_merge_target(
            street.finish.pos, direction, all_paths, parent_path, config, citychunk_origin
        )
        if merge_path and merge_pos then
            local new_length = vector.distance(start_pos, merge_pos)
            if new_length >= config.min_segment_length then
                if not street_too_close_to_existing(start_pos, merge_pos, direction, all_paths, parent_path, config.min_street_spacing) then
                    local new_finish = pcmg.point.new(merge_pos)
                    street:set_finish(new_finish)
                    merge_path:insert_point_at_position(merge_pos, config.min_intersection_point_distance)
                end
            end
        end
    end
    
    -- Find and create intersection points using path methods
    local intersections = street:find_intersections_with_paths(all_paths, start_pos, config.branch_point_tolerance)
    street:create_intersection_points(intersections, true, config.min_intersection_point_distance)
    
    return street, did_snap
end

-- ============================================================
-- BRANCH POINT GENERATION
-- ============================================================

local function get_grid_aligned_branch_points(pth, grid_spacing_param, citychunk_origin)
    pth:subdivide_to_grid(grid_spacing_param, 5)
    
    local points = {}
    local all = pth:all_points()
    
    for i = 2, #all - 1 do
        local prev_pos = all[i - 1].pos
        local curr_pos = all[i].pos
        local next_pos = all[i + 1].pos
        
        if is_inside_citychunk(curr_pos, citychunk_origin) then
            local segment_dir = vector.direction(prev_pos, next_pos)
            
            table.insert(points, {
                point = all[i],
                segment_dir = segment_dir,
                index = i,
            })
        end
    end
    
    return points
end

-- ============================================================
-- RECURSIVE STREET GENERATION
-- ============================================================

local function generate_streets_recursive(parent_path, depth, all_paths, local_paths, citychunk_origin, config)
    local created = {}
    
    -- Safety check for nil tables
    if not all_paths or not local_paths then
        minetest.log("warning", "generate_streets_recursive: all_paths or local_paths is nil")
        return created
    end
    
    local branch_prob, min_len, max_len
    
    if depth == 0 then
        branch_prob = config.primary_branch_probability
        min_len = config.primary_min_length
        max_len = config.primary_max_length
    elseif depth == 1 then
        branch_prob = config.secondary_branch_probability
        min_len = config.secondary_min_length
        max_len = config.secondary_max_length
    elseif depth == 2 then
        branch_prob = config.tertiary_branch_probability
        min_len = config.tertiary_min_length
        max_len = config.tertiary_max_length
    elseif depth == 3 then
        branch_prob = config.quaternary_branch_probability
        min_len = config.quaternary_min_length
        max_len = config.quaternary_max_length
    else
        return created
    end
    
    local branch_points = get_grid_aligned_branch_points(parent_path, grid_spacing, citychunk_origin)
    
    local last_branch_pos = nil
    
    for _, bp in ipairs(branch_points) do
        if last_branch_pos then
            local dist = vector.distance(bp.point.pos, last_branch_pos)
            if dist < config.min_segment_length * 0.9 then
                goto continue
            end
        end
        
        if math.random() < branch_prob then
            local direction = get_perpendicular_direction(bp.segment_dir)
            local length = math.random(min_len, max_len)
            
            local street, did_snap = create_street(
                bp.point, direction, length,
                parent_path, all_paths, local_paths, citychunk_origin, config
            )
            
            if street then
                last_branch_pos = bp.point.pos
                
                table.insert(created, {
                    street = street, 
                    depth = depth, 
                    border_connected = did_snap
                })
                table.insert(all_paths, street)
                table.insert(local_paths, street)
                
                local sub_streets = generate_streets_recursive(
                    street, depth + 1, all_paths, local_paths, citychunk_origin, config
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

-- ============================================================
-- STREET NETWORK GENERATION
-- ============================================================

local function generate_street_network(megapathpav, main_roads, citychunk_origin, config)
    local all_paths, local_paths = megapathpav:get_all_paths(main_roads)
    
    -- Ensure we have valid tables
    if not all_paths then
        all_paths = {}
    end
    if not local_paths then
        local_paths = {}
    end
    
    local all_streets = {}
    
    for _, road in ipairs(main_roads) do
        local streets = generate_streets_recursive(road, 0, all_paths, local_paths, citychunk_origin, config)
        for _, s in ipairs(streets) do
            table.insert(all_streets, s)
        end
    end
    
    return all_streets
end

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

local function generate_and_draw_streets(megacanv, megapathpav, main_roads, config)
    local all_streets = generate_street_network(megapathpav, main_roads, megacanv.origin, config)
    
    for _, street_data in ipairs(all_streets) do
        megapathpav:save_path(street_data.street)
    end
    
    draw_streets(megacanv, all_streets)
    
    return all_streets
end

-- ============================================================
-- MAIN GENERATION
-- ============================================================

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
        local pth = build_road(megapathpav, start, finish)
        megapathpav:save_path(pth)
        table.insert(main_roads, pth)
        draw_points(megacanv, road_origins)
    end
    
    for _, pth in pairs(megapathpav.paths) do
        megacanv:draw_path(road_shape, pth, "straight")
        megacanv:draw_path_points(midpoint_shape, pth)
    end
    
    generate_and_draw_streets(megacanv, megapathpav, main_roads, street_config)
end

function pcmg.generate_roads(megacanv, pathpaver_cache)
    local t1 = minetest.get_us_time()
    megacanv:generate(road_generator, 1, pathpaver_cache)
end
