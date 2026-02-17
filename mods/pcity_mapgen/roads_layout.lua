--[[
    This is a part of "Perfect City".
    Copyright (C) 2023-2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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
local pcmg = pcity_mapgen
local math = math
local units = dofile(mod_path.."/units.lua")
local _, materials_by_name = dofile(mod_path.."/canvas_ids.lua")
local canvas_shapes = pcmg.canvas_shapes
local canvas_brush = pcmg.canvas_brush
local path_utils = pcmg.path_utils

-- Get mapgen seed for deterministic random generation
local mapgen_seed = tonumber(core.get_mapgen_setting("seed")) or 0

-- Sizes of map division units
local node = units.sizes.node
local mapchunk = units.sizes.mapchunk
local citychunk = units.sizes.citychunk

-- Grid spacing for all road/street points (1 mapchunk = 80 nodes)
local grid_spacing = 80

-- Border connection point configuration
local border_grid_spacing = grid_spacing
local border_point_probability = 0.6
local road_origin_margin = 80

--- Set random seed based on position and salt
-- @param pos vector Position to use for seed calculation
-- @param salt number Optional salt value (default: 0)
local function set_position_seed(pos, salt)
    salt = salt or 0
    local seed = mapgen_seed + 
                 pos.x * 73856093 + 
                 pos.y * 19349663 + 
                 pos.z * 83492791 + 
                 salt
    math.randomseed(seed)
end

--- Set random seed for a citychunk
-- @param citychunk_origin vector Origin position of citychunk
-- @param salt number Optional salt value
local function set_citychunk_seed(citychunk_origin, salt)
    set_position_seed(citychunk_origin, salt)
end

-- ============================================================
-- ROAD ORIGIN GENERATION
-- ============================================================

--- Get all grid-aligned points along a citychunk border
-- @param citychunk_origin vector Origin position of citychunk
-- @param border_edge string Border edge ("x_min", "x_max", "z_min", or "z_max")
-- @return table Array of grid-aligned positions on the border
local function get_grid_points_on_border(citychunk_origin, border_edge)
    local min_x = citychunk_origin.x
    local max_x = citychunk_origin.x + citychunk.in_nodes.x - 1
    local min_z = citychunk_origin.z
    local max_z = citychunk_origin.z + citychunk.in_nodes.z - 1
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

--- Get a random grid-aligned road origin point on a border edge
-- Returns a random grid-aligned road origin point for the given border edge.
-- @param citychunk_origin vector Origin position of citychunk
-- @param border_edge string Border edge ("x_min", "x_max", "z_min", or "z_max")
-- @param salt number Salt value for deterministic randomness
-- @return vector Grid-aligned position on the border
local function get_road_origin_on_border(citychunk_origin, border_edge, salt)
    local grid_points = get_grid_points_on_border(citychunk_origin, border_edge)
    
    if #grid_points == 0 then
        local min_x = citychunk_origin.x
        local max_x = citychunk_origin.x + citychunk.in_nodes.x - 1
        local min_z = citychunk_origin.z
        local max_z = citychunk_origin.z + citychunk.in_nodes.z - 1
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
        border_coord = citychunk_origin.x + citychunk.in_nodes.x - 1
    elseif border_edge == "z_min" then
        border_coord = citychunk_origin.z
    else
        border_coord = citychunk_origin.z + citychunk.in_nodes.z - 1
    end
    
    local border_seed = mapgen_seed + border_coord * 73856093 + salt * 83492791
    math.randomseed(border_seed)
    
    local index = math.random(1, #grid_points)
    return grid_points[index]
end

--- Get road origins for two edges of a citychunk
-- @param citychunk_coords vector Citychunk coordinates
-- @return vector, vector X-edge origin and Z-edge origin positions
local function halfchunk_ori(citychunk_coords)
    local origin = units.citychunk_to_node(citychunk_coords)
    local x_edge_ori = get_road_origin_on_border(origin, "z_min", 1)
    local z_edge_ori = get_road_origin_on_border(origin, "x_min", 2)
    return x_edge_ori, z_edge_ori
end

--- Get road origin points for a citychunk
-- Returns four road origin points for connection with neighbors.
-- @param citychunk_origin vector Origin position of citychunk
-- @return table Array of four road origin positions
function pcmg.citychunk_road_origins(citychunk_origin)
    local citychunk_coords = pcmg.citychunk_coords(citychunk_origin)
    local up_coords = citychunk_coords + vector.new(0, 0, 1)
    local right_coords = citychunk_coords + vector.new(1, 0, 0)
    local bottom, left = halfchunk_ori(citychunk_coords)
    local up, _ = halfchunk_ori(up_coords)
    local _, right = halfchunk_ori(right_coords)
    return {bottom, left, up, right}
end

--- Connect road origins in random pairs
-- @param citychunk_origin vector Origin position of citychunk
-- @param road_origins table Array of road origin positions
-- @return table Array of point pairs to connect
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

-- ============================================================
-- DRAWING UTILITIES
-- ============================================================

--- Draw road origin points on the canvas
-- @param megacanv table Megacanvas object
-- @param points table Array of point positions to draw
local function draw_points(megacanv, points)
    for _, pt in pairs(points) do
        megacanv:set_all_cursors(pt)
        megacanv:draw_shape(origin_shape)
    end
end

local road_metastore = pcmg.metastore.new()


-- ============================================================
-- ROAD BUILDING
-- ============================================================

--- Build a simple road path between two points
-- Builds a simple road path between start and finish points.
-- Note: Collision detection has been removed as part of simplification.
-- The path is created using make_slanted(), which creates an L-shaped path
-- with one horizontal segment and one vertical segment when start/finish
-- are not axis-aligned, or a single straight segment when they are aligned.
-- @param start vector Start position
-- @param finish vector End position
-- @return table Path object
local function build_road(start, finish)
    local start_point = pcmg.point.new(start)
    local finish_point = pcmg.point.new(finish)
    local guide_path = pcmg.path.new(start_point, finish_point)
    guide_path:make_slanted()
    return guide_path
end


-- ============================================================
-- MAIN GENERATION
-- ============================================================

--- Generate roads for a citychunk
-- @param megacanv table Megacanvas object
-- @param pathpaver_cache table Cache for pathpavers
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
        local pth = build_road(start, finish)
        megapathpav:save_path(pth)
        table.insert(main_roads, pth)
        draw_points(megacanv, road_origins)
    end
    
    for _, pth in pairs(megapathpav.paths) do
        megacanv:draw_path(road_shape, pth, "straight")
        megacanv:draw_path_points(midpoint_shape, pth)
    end
end

--- Generate roads for a citychunk using megacanvas
-- @param megacanv table Megacanvas object
-- @param pathpaver_cache table Cache for pathpavers
function pcmg.generate_roads(megacanv, pathpaver_cache)
    local t1 = core.get_us_time()
    megacanv:generate(road_generator, 1, pathpaver_cache)
end
