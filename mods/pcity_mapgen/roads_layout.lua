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

--[[
    Road origin points are points where road generation starts.
    Every citychunk has 4 origin points, 1 per edge.
    Road origin points are generated randomly somewhere on
    each edge, but can't get closer to citychunk corners
    than 'road_margin'.
--]]

-- Returns road origin points for the bottom (X) and left (Z) edges
-- of the citychunk.
local function halfchunk_ori(citychunk_coords)
    local origin = units.citychunk_to_node(citychunk_coords)
    local hash = pcmg.citychunk_hash(origin)
    local old_randomness = pcmg.save_randomness()
    math.randomseed(hash, mapgen_seed)
    local random_x = math.random(0 + road_margin, citychunk.in_nodes - 1 - road_margin)
    local x_edge_ori = origin + vector.new(random_x, 0, 0)
    local random_z = math.random(0 + road_margin, citychunk.in_nodes - 1 - road_margin)
    local z_edge_ori = origin + vector.new(0, 0, random_z)
    math.randomseed(old_randomness)
    return x_edge_ori, z_edge_ori
end

-- Returns all road origin points for the citychunk
function pcmg.citychunk_road_origins(citychunk_coords)
    local up_coords = citychunk_coords + vector.new(0, 0, 1)
    local right_coords = citychunk_coords + vector.new(1, 0, 0)
    local bottom, left = halfchunk_ori(citychunk_coords)
    local up, _ = halfchunk_ori(up_coords)
    local _, right = halfchunk_ori(right_coords)
    return {bottom, left, up, right}
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

-- Material IDs
local road_asphalt_id = materials_by_name["road_asphalt"]
local road_pavement_id = materials_by_name["road_pavement"]
local road_center_id = materials_by_name["road_center"]
local road_origin_id = materials_by_name["road_origin"]

local road_radius = 5
local pavement_radius = 8

local function draw_road(megacanv, points)
    local start = points[1]
    local finish = points[2]
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
local function draw_origins(megacanv, points)
    local start = points[1]
    local finish = points[2]
    megacanv:set_cursor(start)
    megacanv:draw_circle(1, road_origin_id)
    megacanv:set_cursor(finish)
    megacanv:draw_circle(1, road_origin_id)
end

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
        draw_origins(megacanv, points)
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
