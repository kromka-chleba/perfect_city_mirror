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
local canvas_shapes = pcmg.canvas_shapes
local canvas_brush = pcmg.canvas_brush

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
    pcmg.set_randomseed(origin)
    local random_x = math.random(0 + road_margin, citychunk.in_nodes - 1 - road_margin)
    local x_edge_ori = origin + vector.new(random_x, 0, 0)
    local random_z = math.random(0 + road_margin, citychunk.in_nodes - 1 - road_margin)
    local z_edge_ori = origin + vector.new(0, 0, random_z)
    math.randomseed(os.time())
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

-- Takes a table of road origin points from which it picks 2 randomly
-- and puts the pair into a table. It repeats the process until
-- all origins are in pairs. If an odd number of origins is in the
-- table it ignores the last.
-- Example:
-- input: {p1, p2, p3, p4, p5}
-- output: {{p1, p3}, {p2, p4}} (p5 got skipped)
local function connect_road_origins(citychunk_origin, road_origins)
    local points = {}
    for _, origin in pairs(road_origins) do
        -- copy the table to avoid "fun" in other parts of the code
        table.insert(points, vector.new(origin))
    end
    pcmg.set_randomseed(citychunk_origin)
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
    math.randomseed(os.time())
    return point_pairs
end

-- Material IDs
local road_asphalt_id = materials_by_name["road_asphalt"]
local road_pavement_id = materials_by_name["road_pavement"]
local road_center_id = materials_by_name["road_center"]
local road_origin_id = materials_by_name["road_origin"]

local road_radius = 5
local pavement_radius = 8

local road_shape = canvas_shapes.combine_shapes(
    canvas_shapes.make_circle(pavement_radius, road_pavement_id),
    canvas_shapes.make_circle(road_radius, road_asphalt_id)
)

-- for testing overgeneration
local function draw_points(megacanv, points)
    for _, point in pairs(points) do
        megacanv:set_all_cursors(point)
        megacanv:draw_circle(1, road_origin_id)
        --megacanv:draw_shape(road_shape)
    end
end

local function draw_road(megacanv, start, finish)
    local path = pcmg.path.new(start, finish)
    path:make_slanted()
    local points = path:all_positions()
    megacanv:draw_path(road_shape, path, "straight")
    draw_points(megacanv, points)
end

local function draw_straight_road(megacanv, start, finish)
    local path = pcmg.path.new(start, finish)
    --path:split(20)
    megacanv:draw_path(road_shape, path, "straight")
    --local points = path:all_points()
    --draw_points(megacanv, points)
end

local function draw_wobbly_road(megacanv, start, finish)
    pcmg.set_randomseed(megacanv.origin)
    megacanv:draw_wobbly(road_shape, start, finish)
    math.randomseed(os.time())
end

local function draw_waved_road(megacanv, start, finish)
    pcmg.set_randomseed(megacanv.origin)
    local path = pcmg.path.new(start, finish)
    path:make_wave(50, 30, 5)
    megacanv:draw_path(road_shape, path, "straight")
    math.randomseed(os.time())
end

-- Draws random circles with asphalt and pavement
-- 'nr' is the number of random circles to draw in the citychunk.
-- Useful for testing.
local function draw_random_dots(megacanv, nr)
    local nr = nr or 100
    pcmg.set_randomseed(megacanv.origin)
    megacanv:draw_random(road_shape, nr)
    math.randomseed(os.time())
end

local function draw_random_lines(megacanv, nr)
    local nr = nr or 100
    pcmg.set_randomseed(megacanv.origin)
    for x = 1, nr do
        local point = pcmg.random_pos_in_citychunk(megacanv.origin)
        megacanv:set_all_cursors(point)
        local v = vector.random(-30, 30)
        local line = canvas_shapes.make_line(v, road_center_id)
        megacanv:draw_shape(line)
    end
    math.randomseed(os.time())
end

local function road_generator(megacanv)
    local road_origins = pcmg.citychunk_road_origins(megacanv.central.origin)
    local connected_points = connect_road_origins(megacanv.central.origin, road_origins)
    for _, points in ipairs(connected_points) do
        local start = points[1]
        local finish = points[2]
        draw_road(megacanv, start, finish)
        --draw_wobbly_road(megacanv, start, finish)
        --draw_waved_road(megacanv, start, finish)
        --draw_straight_road(megacanv, start, finish)
    end
    --draw_points(megacanv, road_origins)
    --draw_random_dots(megacanv, 100)
    --draw_random_lines(megacanv, 10)
end

-- cache for canvas data, see megacanvas.lua
local canvas_cache = pcmg.canvas_cache.new()

function pcmg.citychunk_road_canvas(citychunk_origin)
    local t1 = minetest.get_us_time()
    local hash = pcmg.citychunk_hash(citychunk_origin)
    if not canvas_cache.complete[hash] then
        local megacanv = pcmg.megacanvas.new(citychunk_origin, canvas_cache)
        megacanv:generate(road_generator)
        minetest.log("error", string.format("Overgen time: %g ms", (minetest.get_us_time() - t1) / 1000))
    end
    return canvas_cache.citychunks[hash]
end
