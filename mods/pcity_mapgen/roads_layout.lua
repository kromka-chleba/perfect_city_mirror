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

-- Grid spacing for all road/street points (1 mapchunk = 80 nodes)
local grid_spacing = 80

-- Border connection point configuration
local border_grid_spacing = grid_spacing
local border_point_probability = 0.6        -- Chance of generating point at each grid intersection
local road_origin_margin = 80               -- Minimum distance from road origins

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

-- Get all grid-aligned points along a citychunk border
-- Returns points that fall on the grid within the citychunk edge
local function get_grid_points_on_border(citychunk_origin, border_edge)
    local min_x = citychunk_origin.x
    local max_x = citychunk_origin.x + citychunk.in_nodes - 1
    local min_z = citychunk_origin.z
    local max_z = citychunk_origin.z + citychunk.in_nodes - 1
    local y = citychunk_origin.y
    
    local points = {}
    
    if border_edge == "x_min" or border_edge == "x_max" then
        -- Points along Z axis
        local x = (border_edge == "x_min") and min_x or max_x
        local first_z = math.ceil(min_z / grid_spacing) * grid_spacing
        local z = first_z
        while z <= max_z do
            -- Skip corners (they belong to z borders)
            if z > min_z and z < max_z then
                table.insert(points, vector.new(x, y, z))
            end
            z = z + grid_spacing
        end
    else
        -- Points along X axis (z_min or z_max)
        local z = (border_edge == "z_min") and min_z or max_z
        local first_x = math.ceil(min_x / grid_spacing) * grid_spacing
        local x = first_x
        while x <= max_x do
            -- Skip corners (they belong to x borders)
            if x > min_x and x < max_x then
                table.insert(points, vector.new(x, y, z))
            end
            x = x + grid_spacing
        end
    end
    
    return points
end

-- Returns a random grid-aligned road origin point for the given border edge
-- Uses deterministic seeding based on border coordinate
local function get_road_origin_on_border(citychunk_origin, border_edge, salt)
    local grid_points = get_grid_points_on_border(citychunk_origin, border_edge)
    
    if #grid_points == 0 then
        -- Fallback: return center of border if no grid points available
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
        else -- z_max
            return vector.new((min_x + max_x) / 2, y, max_z)
        end
    end
    
    -- Get the border coordinate for deterministic seeding
    local border_coord
    if border_edge == "x_min" then
        border_coord = citychunk_origin.x
    elseif border_edge == "x_max" then
        border_coord = citychunk_origin.x + citychunk.in_nodes - 1
    elseif border_edge == "z_min" then
        border_coord = citychunk_origin.z
    else -- z_max
        border_coord = citychunk_origin.z + citychunk.in_nodes - 1
    end
    
    -- Seed based on border coordinate (same for both adjacent chunks)
    local border_seed = mapgen_seed + border_coord * 73856093 + salt * 83492791
    math.randomseed(border_seed)
    
    -- Pick a random grid point
    local index = math.random(1, #grid_points)
    return grid_points[index]
end

-- Returns road origin points for the bottom (X) and left (Z) edges
-- Points are aligned to the grid
local function halfchunk_ori(citychunk_coords)
    local origin = units.citychunk_to_node(citychunk_coords)
    
    -- Get grid-aligned road origins for x_min (bottom) and z_min (left) edges
    local x_edge_ori = get_road_origin_on_border(origin, "z_min", 1)  -- bottom edge (along X)
    local z_edge_ori = get_road_origin_on_border(origin, "x_min", 2)  -- left edge (along Z)
    
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
    
    Streets use deterministic border connection points so that streets
    from adjacent citychunks will meet at the same points on the shared border.
--]]
local street_config = {
    -- Minimum segment length (enforced)
    min_segment_length = 80,
    
    -- Minimum spacing between parallel streets/roads
    min_street_spacing = 70,
    
    -- Subdivision settings - larger = fewer but more spread out branches
    road_subdivision_length = 100,
    street_subdivision_length = 100,
    
    -- Primary streets (from main roads) - much longer to cross the chunk
    primary_branch_probability = 0.9,
    primary_min_length = 200,
    primary_max_length = 500,  -- Can cross entire chunk
    
    -- Secondary streets (from primary streets) - also long
    secondary_branch_probability = 0.8,
    secondary_min_length = 150,
    secondary_max_length = 350,
    
    -- Tertiary streets (from secondary streets)
    tertiary_branch_probability = 0.6,
    tertiary_min_length = 100,
    tertiary_max_length = 200,
    
    -- Quaternary streets (from tertiary streets)
    quaternary_branch_probability = 0.4,
    quaternary_min_length = 80,
    quaternary_max_length = 150,
    
    -- Merging settings
    merge_probability = 0.7,
    merge_search_radius = 150,
    min_merge_distance = 50,
    
    -- Border connection settings
    border_connection_spacing = 80,     -- Spacing between connection points on border
    border_snap_radius = 50,            -- How close to snap to a connection point
    
    -- Collision settings
    parallel_overlap_margin = 25,
    intersection_margin = 3,
    min_street_length = 80,
    parallel_check_samples = 5,
    
    -- Intersection point settings
    min_intersection_point_distance = 5,  -- Minimum distance between intersection points
    branch_point_tolerance = 10,          -- Distance to consider as branch point
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
    Deterministic Border Connection Points
    
    Both adjacent citychunks calculate the same connection points on their
    shared border. This is done by using the actual border coordinate
    (not the citychunk origin) as the seed.
    
    For example, the x_max border of chunk A and x_min border of chunk B
    are at the same X coordinate, so they generate the same points.
    
    Points are generated at grid intersections (every 80 nodes, matching
    mapchunk size) with a probability check, and filtered to maintain
    minimum distance from road origins.
--]]

-- Get the citychunk boundaries
local function get_citychunk_bounds(citychunk_origin)
    local min_pos = vector.copy(citychunk_origin)
    local max_pos = vector.add(citychunk_origin, vector.new(
        citychunk.in_nodes - 1,
        0,
        citychunk.in_nodes - 1
    ))
    return min_pos, max_pos
end

-- Check if a position is inside the citychunk boundaries
local function is_inside_citychunk(pos, citychunk_origin)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    return pos.x >= min_pos.x and pos.x <= max_pos.x and
           pos.z >= min_pos.z and pos.z <= max_pos.z
end

-- Check if a position is on the citychunk border
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

-- Clamp a position to stay within citychunk boundaries
local function clamp_to_citychunk(pos, citychunk_origin)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    return vector.new(
        math.max(min_pos.x, math.min(max_pos.x, pos.x)),
        pos.y,
        math.max(min_pos.z, math.min(max_pos.z, pos.z))
    )
end

-- Calculate where a line segment intersects the citychunk boundary
-- Returns the intersection point closest to start_pos, or nil if no intersection
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
    
    -- Check intersection with each boundary
    -- X min boundary
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
    
    -- X max boundary
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
    
    -- Z min boundary
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
    
    -- Z max boundary
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

-- Get all road origins for a citychunk (needed for margin checking)
local function get_all_road_origins_for_chunk(citychunk_origin)
    local citychunk_coords = pcmg.citychunk_coords(citychunk_origin)
    local up_coords = citychunk_coords + vector.new(0, 0, 1)
    local right_coords = citychunk_coords + vector.new(1, 0, 0)
    
    local bottom, left = halfchunk_ori(citychunk_coords)
    local up, _ = halfchunk_ori(up_coords)
    local _, right = halfchunk_ori(right_coords)
    
    return {bottom, left, up, right}
end

-- Check if a position is too close to any road origin
local function is_too_close_to_road_origins(pos, road_origins, margin)
    for _, origin in ipairs(road_origins) do
        local dist = math.sqrt(
            (pos.x - origin.x)^2 + 
            (pos.z - origin.z)^2
        )
        if dist < margin then
            return true
        end
    end
    return false
end

-- Calculate deterministic connection points along a border using grid alignment
-- Uses the actual border position for seeding so adjacent chunks get same points
-- Points are placed at grid intersections and filtered against road origins
local function get_border_connection_points(citychunk_origin, border_edge, spacing)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    local points = {}
    
    -- Get road origins to check for margin
    local road_origins = get_all_road_origins_for_chunk(citychunk_origin)
    
    -- Use the actual border coordinate for seeding
    local border_coord
    local start_coord, end_coord
    local is_x_border
    
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
    else -- z_max
        border_coord = max_pos.z
        start_coord = min_pos.x
        end_coord = max_pos.x
        is_x_border = false
    end
    
    -- Align start_coord to grid (find first grid line at or after start_coord)
    local grid_start = math.ceil(start_coord / border_grid_spacing) * border_grid_spacing
    
    -- Seed based on border coordinate (same for both adjacent chunks)
    -- This ensures deterministic but varied results per grid point
    local base_border_seed = mapgen_seed + border_coord * 73856093
    
    -- Generate points at grid intersections
    local coord = grid_start
    while coord <= end_coord do
        -- Skip points at the very edges (corners)
        if coord > start_coord and coord < end_coord then
            -- Create unique seed for this specific grid point
            local point_seed = base_border_seed + coord * 19349663
            math.randomseed(point_seed)
            
            -- Determine the candidate point position
            local candidate_point
            if is_x_border then
                candidate_point = vector.new(border_coord, min_pos.y, coord)
            else
                candidate_point = vector.new(coord, min_pos.y, border_coord)
            end
            
            -- Check if this grid point should have a connection point
            -- and if it's far enough from road origins
            if math.random() < border_point_probability then
                if not is_too_close_to_road_origins(candidate_point, road_origins, road_origin_margin) then
                    table.insert(points, candidate_point)
                end
            end
        end
        
        -- Move to next grid intersection
        coord = coord + border_grid_spacing
    end
    
    return points
end

-- Get the border edge a position is near
local function get_border_edge(pos, citychunk_origin, tolerance)
    local min_pos, max_pos = get_citychunk_bounds(citychunk_origin)
    
    local dist_x_min = math.abs(pos.x - min_pos.x)
    local dist_x_max = math.abs(pos.x - max_pos.x)
    local dist_z_min = math.abs(pos.z - min_pos.z)
    local dist_z_max = math.abs(pos.z - max_pos.z)
    
    local min_dist = math.min(dist_x_min, dist_x_max, dist_z_min, dist_z_max)
    
    if min_dist > tolerance then
        return nil, min_dist
    end
    
    if min_dist == dist_x_min then return "x_min", dist_x_min end
    if min_dist == dist_x_max then return "x_max", dist_x_max end
    if min_dist == dist_z_min then return "z_min", dist_z_min end
    return "z_max", dist_z_max
end

-- Find which border a direction vector points toward
local function get_direction_border(direction)
    if math.abs(direction.x) > math.abs(direction.z) then
        if direction.x > 0 then
            return "x_max"
        else
            return "x_min"
        end
    else
        if direction.z > 0 then
            return "z_max"
        else
            return "z_min"
        end
    end
end

-- Calculate where a line from start_pos in direction hits the border
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

-- Find the nearest connection point on a border
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

-- Try to snap a street endpoint to a border connection point
-- Also ensures the endpoint doesn't go beyond the citychunk boundary
local function snap_to_border_connection(start_pos, end_pos, direction, citychunk_origin, config)
    -- First, check if end_pos is outside citychunk and clamp it
    if not is_inside_citychunk(end_pos, citychunk_origin) then
        local border_intersection = get_citychunk_border_intersection(start_pos, end_pos, citychunk_origin)
        if border_intersection then
            end_pos = border_intersection
        else
            end_pos = clamp_to_citychunk(end_pos, citychunk_origin)
        end
    end
    
    -- Calculate where we'd hit the border
    local border_pos, border_edge, t = calculate_border_intersection(start_pos, direction, citychunk_origin)
    
    if not border_pos or not border_edge then
        return end_pos, false
    end
    
    local dist_to_border = vector.distance(start_pos, border_pos)
    local dist_to_end = vector.distance(start_pos, end_pos)
    
    -- Only snap if we're going to or past the border
    if dist_to_end < dist_to_border - config.border_snap_radius then
        return end_pos, false
    end
    
    -- Find nearest connection point on this border
    local connection_point, dist_to_connection = find_nearest_connection_point(
        border_pos, citychunk_origin, border_edge, config
    )
    
    if connection_point and dist_to_connection <= config.border_snap_radius then
        local new_length = vector.distance(start_pos, connection_point)
        if new_length >= config.min_segment_length then
            return connection_point, true
        end
    end
    
    -- If can't snap, just go to border if long enough
    if dist_to_border >= config.min_segment_length then
        return border_pos, false
    end
    
    return end_pos, false
end

--[[
    Grid-Aligned Street Origin Points
    
    Street origin points (where streets branch from roads) are placed at
    grid-aligned positions. This is done by finding where the road segments
    intersect with the global grid lines (every 80 nodes).
--]]

-- Find intersection point between a line segment and a grid line
-- Returns the intersection point or nil if no intersection
local function segment_grid_intersection(seg_start, seg_end, grid_coord, is_x_grid)
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
    
    -- Check if grid line is between segment endpoints
    if (start_coord < grid_coord and end_coord < grid_coord) or
       (start_coord > grid_coord and end_coord > grid_coord) then
        return nil
    end
    
    -- Handle case where segment is parallel to grid line
    if math.abs(end_coord - start_coord) < 1e-6 then
        return nil
    end
    
    -- Calculate interpolation parameter
    local t = (grid_coord - start_coord) / (end_coord - start_coord)
    
    -- Ensure t is within segment bounds (with small epsilon for floating point)
    if t < 0.01 or t > 0.99 then
        return nil
    end
    
    -- Calculate intersection point
    local other_coord = other_start + t * (other_end - other_start)
    local y_coord = seg_start.y + t * (seg_end.y - seg_start.y)
    
    if is_x_grid then
        return vector.new(grid_coord, y_coord, other_coord)
    else
        return vector.new(other_coord, y_coord, grid_coord)
    end
end

-- Find all grid intersection points along a path segment
local function find_segment_grid_intersections(seg_start, seg_end, grid_spacing_param)
    local intersections = {}
    
    -- Find X grid lines that intersect this segment
    local min_x = math.min(seg_start.x, seg_end.x)
    local max_x = math.max(seg_start.x, seg_end.x)
    local first_x_grid = math.ceil(min_x / grid_spacing_param) * grid_spacing_param
    
    local x_grid = first_x_grid
    while x_grid <= max_x do
        local intersection = segment_grid_intersection(seg_start, seg_end, x_grid, true)
        if intersection then
            table.insert(intersections, {
                pos = intersection,
                grid_coord = x_grid,
                is_x_grid = true
            })
        end
        x_grid = x_grid + grid_spacing_param
    end
    
    -- Find Z grid lines that intersect this segment
    local min_z = math.min(seg_start.z, seg_end.z)
    local max_z = math.max(seg_start.z, seg_end.z)
    local first_z_grid = math.ceil(min_z / grid_spacing_param) * grid_spacing_param
    
    local z_grid = first_z_grid
    while z_grid <= max_z do
        local intersection = segment_grid_intersection(seg_start, seg_end, z_grid, false)
        if intersection then
            table.insert(intersections, {
                pos = intersection,
                grid_coord = z_grid,
                is_x_grid = false
            })
        end
        z_grid = z_grid + grid_spacing_param
    end
    
    return intersections
end

-- Insert grid-aligned points into a path for street branching
-- This subdivides the path so that points exist at grid intersections
local function subdivide_path_to_grid(pth, grid_spacing_param)
    local segments = pth:all_segments()
    local points_to_insert = {}
    
    -- Collect all grid intersection points for all segments
    for seg_index, seg in ipairs(segments) do
        local intersections = find_segment_grid_intersections(
            seg.start_pos, seg.end_pos, grid_spacing_param
        )
        
        for _, int in ipairs(intersections) do
            -- Calculate distance from segment start for sorting
            local dist = vector.distance(seg.start_pos, int.pos)
            table.insert(points_to_insert, {
                pos = int.pos,
                segment_index = seg_index,
                distance_from_start = dist,
                start_point = seg.start_point,
                end_point = seg.end_point
            })
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
            local min_dist = 5  -- Minimum distance between points
            
            if vector.distance(pt_data.start_point.pos, pt_data.pos) < min_dist then
                too_close = true
            elseif vector.distance(pt_data.end_point.pos, pt_data.pos) < min_dist then
                too_close = true
            end
            
            if not too_close then
                local new_point = pcmg.point.new(pt_data.pos)
                pth:insert_between(pt_data.start_point, pt_data.end_point, new_point)
                table.insert(inserted_points, new_point)
            end
        end
    end
    
    return inserted_points
end

--[[
    Street Generation Utilities
--]]

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

local function segments_are_parallel(seg1_start, seg1_end, seg2_start, seg2_end)
    local dir1 = vector.direction(seg1_start, seg1_end)
    local dir2 = vector.direction(seg2_start, seg2_end)
    local angle = angle_between_2d(dir1, dir2)
    return angle < (math.pi / 6) or angle > (math.pi - math.pi / 6)
end

local function direction_parallel_to_segment(direction, seg_start, seg_end)
    local seg_dir = vector.direction(seg_start, seg_end)
    local angle = angle_between_2d(direction, seg_dir)
    return angle < (math.pi / 6) or angle > (math.pi - math.pi / 6)
end

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

local function is_local_path(path, local_paths)
    for _, lp in ipairs(local_paths) do
        if path == lp then return true end
    end
    return false
end

-- Find the segment in a path that contains the given position
-- Returns the segment and its index, or nil if not found
local function find_segment_containing_point(pth, pos, tolerance)
    tolerance = tolerance or 10
    local segments = pth:all_segments()
    
    for seg_idx, seg in ipairs(segments) do
        local seg_dir = vector.subtract(seg.end_pos, seg.start_pos)
        local seg_len_sq = seg_dir.x * seg_dir.x + seg_dir.z * seg_dir.z
        
        if seg_len_sq > 1e-6 then
            local to_pos = vector.subtract(pos, seg.start_pos)
            local t = (to_pos.x * seg_dir.x + to_pos.z * seg_dir.z) / seg_len_sq
            
            -- Check if t is within segment bounds
            if t >= -0.1 and t <= 1.1 then
                local closest = vector.new(
                    seg.start_pos.x + math.max(0, math.min(1, t)) * seg_dir.x,
                    seg.start_pos.y + math.max(0, math.min(1, t)) * (seg.end_pos.y - seg.start_pos.y),
                    seg.start_pos.z + math.max(0, math.min(1, t)) * seg_dir.z
                )
                local dist = vector.distance(pos, closest)
                
                if dist < tolerance then
                    return seg, seg_idx, t, dist
                end
            end
        end
    end
    
    return nil, nil, nil, nil
end

-- Insert an intersection point into a path at the given position
-- Returns the new point (or existing point if close enough), and whether it was inserted
local function insert_intersection_point(pth, pos, min_distance)
    min_distance = min_distance or 5
    
    -- Check if there's already a point close to this position
    local all_points = pth:all_points()
    for _, p in ipairs(all_points) do
        if vector.distance(p.pos, pos) < min_distance then
            return p, false  -- Return existing point, no insertion needed
        end
    end
    
    -- Find the segment containing this position
    local seg, seg_idx, t, dist = find_segment_containing_point(pth, pos, min_distance * 3)
    
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
    if t < 0.05 or t > 0.95 then
        if t < 0.05 then
            return seg.start_point, false
        else
            return seg.end_point, false
        end
    end
    
    -- Insert new point
    local new_point = pcmg.point.new(pos)
    pth:insert_between(seg.start_point, seg.end_point, new_point)
    return new_point, true
end

local function point_to_segment_distance(pos, seg_start, seg_end)
    local seg_dir = vector.subtract(seg_end, seg_start)
    local seg_len_sq = seg_dir.x * seg_dir.x + seg_dir.z * seg_dir.z
    
    if seg_len_sq < 1e-6 then
        return vector.distance(pos, seg_start)
    end
    
    local to_pos = vector.subtract(pos, seg_start)
    local t = (to_pos.x * seg_dir.x + to_pos.z * seg_dir.z) / seg_len_sq
    t = math.max(0, math.min(1, t))
    
    local closest = vector.new(
        seg_start.x + t * seg_dir.x,
        seg_start.y + t * seg_dir.y,
        seg_start.z + t * seg_dir.z
    )
    
    return vector.distance(pos, closest), closest
end

local function street_too_close_to_existing(start_pos, end_pos, direction, all_paths, parent_path, min_spacing)
    local street_length = vector.distance(start_pos, end_pos)
    local num_samples = math.max(3, math.floor(street_length / 30))
    
    for _, existing in ipairs(all_paths) do
        if existing == parent_path then goto continue_path end
        
        local existing_segments = existing:all_segments()
        
        for _, seg in ipairs(existing_segments) do
            if direction_parallel_to_segment(direction, seg.start_pos, seg.end_pos) then
                for i = 0, num_samples do
                    local t = i / num_samples
                    local sample = vector.new(
                        start_pos.x + t * (end_pos.x - start_pos.x),
                        start_pos.y + t * (end_pos.y - start_pos.y),
                        start_pos.z + t * (end_pos.z - start_pos.z)
                    )
                    
                    local dist = point_to_segment_distance(sample, seg.start_pos, seg.end_pos)
                    
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

--[[
    Intersection Detection and Creation
    
    These functions handle finding intersections between streets/roads
    and creating proper intersection points in both paths.
--]]

-- Calculate the intersection point between two line segments
-- Returns the intersection point or nil if segments don't intersect
local function calculate_segment_intersection(seg1_start, seg1_end, seg2_start, seg2_end)
    local d1x = seg1_end.x - seg1_start.x
    local d1z = seg1_end.z - seg1_start.z
    local d2x = seg2_end.x - seg2_start.x
    local d2z = seg2_end.z - seg2_start.z
    
    local cross = d1x * d2z - d1z * d2x
    
    -- Check if segments are parallel
    if math.abs(cross) < 1e-6 then
        return nil
    end
    
    local dx = seg2_start.x - seg1_start.x
    local dz = seg2_start.z - seg1_start.z
    
    local t1 = (dx * d2z - dz * d2x) / cross
    local t2 = (dx * d1z - dz * d1x) / cross
    
    -- Check if intersection is within both segments
    if t1 < 0.01 or t1 > 0.99 or t2 < 0.01 or t2 > 0.99 then
        return nil
    end
    
    -- Calculate intersection point
    local ix = seg1_start.x + t1 * d1x
    local iz = seg1_start.z + t1 * d1z
    local iy = (seg1_start.y + seg2_start.y) / 2  -- Average Y
    
    return vector.new(ix, iy, iz), t1, t2
end

-- Find all intersections between a new street segment and existing paths
-- Returns a list of intersection data sorted by distance from start
-- branch_point_pos is the position where the street branches from its parent (to skip that intersection)
local function find_segment_intersections(seg_start, seg_end, all_paths, config, branch_point_pos)
    local intersections = {}
    local branch_tolerance = config.branch_point_tolerance or 10
    
    for _, existing_path in ipairs(all_paths) do
        local existing_segments = existing_path:all_segments()
        
        for seg_idx, existing_seg in ipairs(existing_segments) do
            local int_pos, t1, t2 = calculate_segment_intersection(
                seg_start, seg_end,
                existing_seg.start_pos, existing_seg.end_pos
            )
            
            if int_pos then
                -- Skip if this is the branch point (where we connect to parent)
                local is_branch_point = false
                if branch_point_pos and vector.distance(int_pos, branch_point_pos) < branch_tolerance then
                    is_branch_point = true
                end
                
                -- Skip if segments are parallel (we handle overlaps separately)
                local is_parallel = segments_are_parallel(seg_start, seg_end, 
                                        existing_seg.start_pos, existing_seg.end_pos)
                
                if not is_branch_point and not is_parallel then
                    local dist_from_start = vector.distance(seg_start, int_pos)
                    
                    table.insert(intersections, {
                        pos = int_pos,
                        t1 = t1,  -- Parameter along new segment
                        t2 = t2,  -- Parameter along existing segment
                        distance = dist_from_start,
                        existing_path = existing_path,
                        existing_segment = existing_seg,
                        existing_segment_index = seg_idx
                    })
                end
            end
        end
    end
    
    -- Sort by distance from start of new segment
    table.sort(intersections, function(a, b)
        return a.distance < b.distance
    end)
    
    return intersections
end

-- Find all intersections for a complete street path against all existing paths
local function find_all_street_intersections(street, all_paths, local_paths, config, branch_point_pos)
    local all_intersections = {}
    local street_segments = street:all_segments()
    local cumulative_distance = 0
    
    for seg_idx, seg in ipairs(street_segments) do
        local seg_intersections = find_segment_intersections(
            seg.start_pos, seg.end_pos,
            all_paths, config, branch_point_pos
        )
        
        for _, int_data in ipairs(seg_intersections) do
            int_data.street_segment_index = seg_idx
            int_data.street_segment = seg
            int_data.total_distance = cumulative_distance + int_data.distance
            int_data.is_local = is_local_path(int_data.existing_path, local_paths)
            table.insert(all_intersections, int_data)
        end
        
        cumulative_distance = cumulative_distance + vector.distance(seg.start_pos, seg.end_pos)
    end
    
    -- Sort by total distance from street start
    table.sort(all_intersections, function(a, b)
        return a.total_distance < b.total_distance
    end)
    
    return all_intersections
end

-- Create intersection points in both the new street and existing paths
-- This ensures clean crossings with proper points in both paths
local function create_intersection_points(street, intersections, local_paths, config)
    local min_dist = config.min_intersection_point_distance or 5
    local created_points = {}
    
    -- Process intersections in reverse order (farthest first)
    -- to avoid invalidating segment references
    for i = #intersections, 1, -1 do
        local int_data = intersections[i]
        local pos = int_data.pos
        
        -- Check if we're too close to an already created point
        local too_close = false
        for _, created in ipairs(created_points) do
            if vector.distance(pos, created.pos) < min_dist then
                too_close = true
                break
            end
        end
        
        if not too_close then
            -- Insert point in the new street
            local street_point, street_inserted = insert_intersection_point(street, pos, min_dist)
            
            -- Always try to insert point in the existing path
            local existing_point = nil
            local existing_inserted = false
            
            if int_data.existing_path then
                existing_point, existing_inserted = insert_intersection_point(
                    int_data.existing_path, pos, min_dist
                )
            end
            
            if street_point then
                table.insert(created_points, {
                    pos = pos,
                    street_point = street_point,
                    existing_point = existing_point,
                    street_inserted = street_inserted,
                    existing_inserted = existing_inserted
                })
            end
        end
    end
    
    return created_points
end

-- Validate intersections - check if they're too close together or problematic
local function validate_intersections(intersections, config)
    local min_dist = config.min_intersection_point_distance or 5
    
    -- Check for intersections that are too close together
    for i = 1, #intersections - 1 do
        local dist = intersections[i + 1].total_distance - intersections[i].total_distance
        if dist < min_dist then
            return false, "intersections_too_close"
        end
    end
    
    return true, nil
end

local function find_merge_target(end_pos, direction, all_paths, parent_path, config, citychunk_origin)
    local best_path = nil
    local best_pos = nil
    local best_dist = config.merge_search_radius
    
    local search_end = vector.add(end_pos, vector.multiply(direction, config.merge_search_radius))
    
    -- Clamp search_end to citychunk boundaries
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
            local int_pos = calculate_segment_intersection(
                end_pos, search_end,
                seg.start_pos, seg.end_pos
            )
            
            if int_pos then
                -- Ensure intersection is inside citychunk
                if is_inside_citychunk(int_pos, citychunk_origin) or 
                   is_on_citychunk_border(int_pos, citychunk_origin) then
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

-- Create a street from a branching point with proper intersection handling
local function create_street(branch_point, direction, length, parent_path, all_paths, local_paths, citychunk_origin, config)
    local start_pos = branch_point.pos
    local end_pos = vector.add(start_pos, vector.multiply(direction, length))
    
    -- Round to grid
    end_pos.x = math.floor(end_pos.x + 0.5)
    end_pos.y = math.floor(end_pos.y + 0.5)
    end_pos.z = math.floor(end_pos.z + 0.5)
    
    -- Clamp end_pos to citychunk boundaries before any other processing
    if not is_inside_citychunk(end_pos, citychunk_origin) then
        local border_intersection = get_citychunk_border_intersection(start_pos, end_pos, citychunk_origin)
        if border_intersection then
            end_pos = border_intersection
        else
            end_pos = clamp_to_citychunk(end_pos, citychunk_origin)
        end
    end
    
    -- Try to snap to border connection point (this also handles boundary clamping)
    local snapped_end, did_snap = snap_to_border_connection(
        start_pos, end_pos, direction, citychunk_origin, config
    )
    end_pos = snapped_end
    
    -- Check minimum length
    local street_length = vector.distance(start_pos, end_pos)
    if street_length < config.min_segment_length then
        return nil, false
    end
    
    -- Check if proposed street would be too close to existing roads/streets (parallel)
    if street_too_close_to_existing(start_pos, end_pos, direction, all_paths, parent_path, config.min_street_spacing) then
        return nil, false
    end
    
    -- Pre-check intersections before creating the street
    local pre_intersections = find_segment_intersections(start_pos, end_pos, all_paths, config, start_pos)
    
    -- If there are too many close intersections, reject this street
    if #pre_intersections > 0 then
        -- Sort by distance
        table.sort(pre_intersections, function(a, b) return a.distance < b.distance end)
        
        -- Check if first intersection is too close to start
        if pre_intersections[1].distance < config.min_segment_length * 0.3 then
            -- Intersection too close to start, skip this street
            return nil, false
        end
        
        -- Check spacing between intersections
        for i = 1, #pre_intersections - 1 do
            local spacing = pre_intersections[i + 1].distance - pre_intersections[i].distance
            if spacing < config.min_intersection_point_distance then
                return nil, false
            end
        end
    end
    
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
        
        if cut_point and cut_dist >= config.min_segment_length then
            street:cut_off(cut_point)
            did_snap = false
        else
            return nil, false
        end
    end
    
    -- Check length after potential cutting
    if street:length() < config.min_segment_length then
        return nil, false
    end
    
    -- Try to merge into another path (only if not snapped to border)
    if not did_snap and math.random() < config.merge_probability then
        local merge_path, merge_pos = find_merge_target(
            street.finish.pos, direction, all_paths, parent_path, config, citychunk_origin)
        if merge_path and merge_pos then
            local new_length = vector.distance(start_pos, merge_pos)
            if new_length >= config.min_segment_length then
                if not street_too_close_to_existing(start_pos, merge_pos, direction, all_paths, parent_path, config.min_street_spacing) then
                    local new_finish = pcmg.point.new(merge_pos)
                    street:set_finish(new_finish)
                    
                    -- Insert intersection point in the merge target
                    insert_intersection_point(merge_path, merge_pos, config.min_intersection_point_distance)
                end
            end
        end
    end
    
    -- Find and create all intersection points
    local intersections = find_all_street_intersections(street, all_paths, local_paths, config, start_pos)
    
    -- Validate intersections
    local valid, reason = validate_intersections(intersections, config)
    if not valid then
        -- If intersections are problematic, we could either reject the street
        -- or try to adjust it. For now, we'll still create it but log the issue.
    end
    
    -- Create intersection points in both paths
    create_intersection_points(street, intersections, local_paths, config)
    
    return street, did_snap
end

-- Get grid-aligned branching points from a path
-- Points are placed where the path intersects grid lines
-- Only returns points that are inside the citychunk
local function get_grid_aligned_branch_points(pth, grid_spacing_param, citychunk_origin)
    -- First, subdivide the path to insert points at grid intersections
    subdivide_path_to_grid(pth, grid_spacing_param)
    
    local points = {}
    local all = pth:all_points()
    
    -- Skip start and finish points
    for i = 2, #all - 1 do
        local prev_pos = all[i - 1].pos
        local curr_pos = all[i].pos
        local next_pos = all[i + 1].pos
        
        -- Only include points that are inside the citychunk
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

-- Recursive street generation
local function generate_streets_recursive(parent_path, depth, all_paths, local_paths, citychunk_origin, config)
    local created = {}
    
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
    
    -- Use grid-aligned branch points instead of subdivision-based points
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
                
                -- Continue recursion even for border-connected streets
                -- (they might have room for side branches)
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

-- Generate all streets from main roads
local function generate_street_network(megapathpav, main_roads, citychunk_origin, config)
    local all_paths, local_paths = get_all_paths(megapathpav, main_roads)
    local all_streets = {}
    
    for _, road in ipairs(main_roads) do
        local streets = generate_streets_recursive(road, 0, all_paths, local_paths, citychunk_origin, config)
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
    local all_streets = generate_street_network(megapathpav, main_roads, megacanv.origin, config)
    
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
