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
local mlib = dofile(mod_path.."/mlib.lua")
local sizes = dofile(mod_path.."/sizes.lua")
local _, materials_by_name = dofile(mod_path.."/canvas_ids.lua")
local units = sizes.units

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

--[[
    Road origins shouldn't be to close to each other so
    setting a minimal distance from the start and end points
    of the edge makes sense.
--]]
local road_margin = 40
if citychunk.in_mapchunks == 1 then
    road_margin = 15
end
    math.floor(1/5 * citychunk.in_nodes)

local mapgen_seed = minetest.get_mapgen_setting("seed")

--[[ Generates a random point on an edge of the citychunk.
    The point can have any value between [0 + road_margin; 799 - road_margin]
    assuming standard mapchunk size of 80 nodes and citychunk size of 10 mapchunks.
    Usage:
    edge_nr specifies an edge along Z or X axis,
    start specifies the minimal position belonging to
    the citychunk along the axis. So a citychunk starts
    at start and ends at start + 1 along the axis.
    This function returns position (number) of the point on the axis.
--]]
local function road_origin(edge)
    -- a seed to make roads reproducible
    local citychunk_seed = math.floor(edge.nr+edge.origin)
    local old_randomness = pcmg.save_randomness()
    math.randomseed(citychunk_seed, mapgen_seed)
    local offset = math.random(0 + road_margin, citychunk.in_nodes - 1 - road_margin) * node.in_citychunks
    math.randomseed(old_randomness)
    if edge.type == "x_bottom" then
        return vector.new(edge.origin + offset, 0, edge.nr)
    elseif edge.type == "x_top" then
        return vector.new(edge.origin + offset, 0, edge.nr - node.in_citychunks)
    elseif edge.type == "z_left" then
        return vector.new(edge.nr, 0, edge.origin + offset)
    elseif edge.type == "z_right" then
        return vector.new(edge.nr - node.in_citychunks, 0, edge.origin + offset)
    else
        assert(false, "Mapgen: edge type \""..
               edge.type.."\" is not a proper edge type!")
    end
end

-- Rreturns citychunk grid coordinates of road origin points in a given citychunk.
-- A road origin point is a point on an edge of a citychunk where a road
-- starts being generated.
-- Grid coordinates are expressed in citychunks.
function pcmg.citychunk_road_origins(citychunk_coords)
    local edges = pcmg.citychunk_edges(citychunk_coords)
    local points = {}
    for _, edge in pairs(edges) do
        table.insert(points, road_origin(edge))
    end
    return points
end

--[[
    Roads should initially be perpendicular to the citychunk edge.
--]]

-- Takes a table of road origin points from which it picks 2 randomly
-- and puts the pair into a table. It repeats the process until
-- all origins are in pairs. If an odd number of origins is in the
-- table it ignores the last.
-- Example:
-- input: {p1, p2, p3, p4, p5}
-- output: {{p1, p3}, {p2, p4}} (p5 got skipped)
local function connect_road_origins(origins)
    local points = {}
    for _, origin in pairs(origins) do
        -- copy the table to avoid "fun" in other parts of the code
        table.insert(points, vector.new(origin))
    end
    local old_randomness = pcmg.save_randomness()
    local citychunk_seed = mapgen_seed
    for _, point in pairs(points) do
        citychunk_seed = citychunk_seed*point.z*point.x
    end
    citychunk_seed = math.floor(citychunk_seed)
    math.randomseed(citychunk_seed)
    if #points % 2 ~= 0 then
        -- remove one point if for some reason the number of points was odd
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
    math.randomseed(old_randomness)
    return point_pairs
end

-- Checks if two points are on adjacent (or opposite) edges
-- of a mapchunk. This assumes the points belong to the edges
-- of the mapchunk.
local function adjacent_walls(p1, p2)
    local _, p1_rest = vector.modf(p1)
    local _, p2_rest = vector.modf(p2)
    if p1 == p2 then
        return false
    end
    if (p1_rest.x == 0 and p2_rest.x == 0 or
        p1_rest.z == 0 and p2_rest.z == 0) then
        return false
    elseif p1_rest.x == 0 and p2_rest.z == 0 or
        p1_rest.z == 0 and p2_rest.x == 0 then
        return true
    end
end

-- checks if the point lies on an x edge (edge with integer x value)
local function point_on_x_edge(p1)
    local _, p1_rest = vector.modf(p1)
    if p1_rest.x == 0 and p1_rest.z ~= 0 then
        return true
    end
    return false
end

local function segment_number(adjacent, start_z, x_component, z_component)
    local min_segment_length = 4 * 16 * sizes.node.in_citychunks
    local x_nr = math.ceil(vector.length(x_component) / min_segment_length)
    local z_nr = math.ceil(vector.length(z_component) / min_segment_length)
    -- the shorter component determines the number of segments
    if x_nr > z_nr then
        x_nr = z_nr
    elseif x_nr < z_nr then
        z_nr = x_nr
    end
    if not adjacent then
        -- to get to the opposite side you need N segments parallel
        -- to the starting edge and N + 1 segments perpendicular to the edge
        if start_z then
            z_nr = z_nr + 1
        else
            x_nr = x_nr + 1
        end
    end
    return x_nr, z_nr
end

local function point_on_edge(point)
    local _, p_rest = vector.modf(point)
    p_rest = vector.abs(p_rest)
    if p_rest.x == 0 or p_rest.z == 0 then
        return true
    end
    -- top z edge
    if p_rest.x == 1 - node.in_citychunks or
        p_rest.x == node.in_citychunks then
        return true
    end
    -- top z edge
    if p_rest.z == 1 - node.in_citychunks or
        p_rest.z == node.in_citychunks then
        return true
    end
    minetest.log("error", "Rest: "..dump(p_rest))
    minetest.log("error", "1 - node.in_citychunks: "..dump(1 - node.in_citychunks))
    minetest.log("error", "1 - node.in_citychunks: "..dump(node.in_citychunks))
    return false
end

function pcmg.check_road_points(road_points)
    local connected_points = connect_road_origins(road_points)
    for _, points in ipairs(connected_points) do
        local start = points[1]
        local finish = points[2]
        local v = finish - start
        local function print_points()
            minetest.log("error", "Start: "..dump(start))
            minetest.log("error", "Finish: "..dump(finish))
            minetest.log("error", "Vector: "..dump(v))
        end
        if vector.length(v) == 0 then
            minetest.log("error", "Road points are equal!")
            print_points()
        elseif (v.x == 0 or v.z == 0) and vector.length(v) < 1 - node.in_citychunks then
            minetest.log("error", "Road goes straight but too short to reach citychunk border!")
            print_points()
        elseif not (point_on_edge(start) and point_on_edge(finish)) then
            minetest.log("error", "One point does not lie on the citychunk border!")
            print_points()
        elseif vector.length(v) < sizes.mapchunk.in_citychunks then
            minetest.log("error", "Road shorter than a mapchunk!")
            print_points()
        end
    end
end

local road_asphalt_id = materials_by_name["road_asphalt"]
local road_pavement_id = materials_by_name["road_pavement"]

local road_radius = 5
local pavement_radius = 8

local function draw_road(megacanv, points)
    local start = units.citychunk_to_node(points[1])
    local finish = units.citychunk_to_node(points[2])
    local vec = vector.round(finish - start)
    local step = vector.sign(vec)
    local step_x = vector.new(step.x, 0, 0)
    local step_z = vector.new(0, 0, step.z)
    local moves_x = math.abs(vec.x)
    local moves_z = math.abs(vec.z)

    megacanv:set_cursor(start)
    megacanv:draw_circle(road_radius, road_asphalt_id)
    megacanv:draw_circle(pavement_radius, road_pavement_id)

    while (moves_x > 0 or moves_z > 0) do
        if moves_x > 0 then
            megacanv:move_cursor(step_x)
            megacanv:draw_circle(road_radius, road_asphalt_id)
            megacanv:draw_circle(pavement_radius, road_pavement_id)
            moves_x = moves_x - 1
        end
        if moves_z > 0 then
            megacanv:move_cursor(step_z)
            megacanv:draw_circle(road_radius, road_asphalt_id)
            megacanv:draw_circle(pavement_radius, road_pavement_id)
            moves_z = moves_z - 1
        end
    end
end

-- for testing overgeneration
local function draw_huge(megacanv, points)
    local start = units.citychunk_to_node(points[1])
    local finish = units.citychunk_to_node(points[2])
    megacanv:set_cursor(start)
    megacanv:draw_circle(60, road_asphalt_id)
    megacanv:set_cursor(finish)
    megacanv:draw_circle(65, road_pavement_id)
end

local road_center_id = materials_by_name["road_center"]

-- Draws random circles with asphalt and pavement
-- 'nr' is the number of random circles to draw in the citychunk.
-- Useful for testing.
local function draw_random_dots(megacanv, nr)
    local nr = nr or 100
    local hash = pcmg.citychunk_hash(megacanv.origin)
    local citychunk_seed = hash
    local old_randomness = pcmg.save_randomness()
    math.randomseed(mapgen_seed, citychunk_seed)
    for x = 1, nr do
        local point = pcmg.random_pos_in_citychunk(megacanv.origin)
        megacanv:set_cursor(point)
        megacanv:draw_circle(18, road_pavement_id)
        megacanv:draw_circle(15, road_asphalt_id)
        megacanv:draw_circle(1, road_center_id)
    end
    math.randomseed(old_randomness)
end

-- cache for canvas data
-- it has 'citychunks' and 'complete' fields
local canvas_cache = {
    complete = {},
    partially_complete = {},
    citychunks = {},
}

local function road_generator(megacanv)
    local t1 = minetest.get_us_time()
    local citychunk_coords = pcmg.citychunk_coords(megacanv.central.origin)
    local road_points = pcmg.citychunk_road_origins(citychunk_coords)
    local connected_points = connect_road_origins(road_points)
    for _, points in ipairs(connected_points) do
        draw_road(megacanv, points)
        --draw_huge(megacanv, points)
        --draw_random_dots(megacanv, 400)
    end
    --minetest.log("error", string.format("Single citychunk: %g ms", (minetest.get_us_time() - t1) / 1000))
end

function pcmg.citychunk_road_canvas(citychunk_origin)
    local t1 = minetest.get_us_time()
    local hash = pcmg.citychunk_hash(citychunk_origin)
    if not canvas_cache.complete[hash] then
        local megacanv = pcmg.megacanvas.new(citychunk_origin, canvas_cache)
        megacanv:generate(road_generator, 1)
        minetest.log("error", string.format("Overgen time: %g ms", (minetest.get_us_time() - t1) / 1000))
    end
    return canvas_cache.citychunks[hash]
end
