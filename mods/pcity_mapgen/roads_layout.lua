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
local road_midpoint_id = materials_by_name["road_midpoint"]

local road_radius = 9
local pavement_radius = 13

local road_shape = canvas_shapes.combine_shapes(
    canvas_shapes.make_circle(pavement_radius, road_pavement_id),
    canvas_shapes.make_circle(road_radius, road_asphalt_id)
)

local midpoint_shape = pcmg.canvas_shapes.make_circle(1, road_midpoint_id)
local origin_shape = pcmg.canvas_shapes.make_circle(1, road_origin_id)

-- for testing overgeneration
local function draw_points(megacanv, points)
    for _, point in pairs(points) do
        megacanv:set_all_cursors(point)
        megacanv:draw_shape(origin_shape)
    end
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

local road_metastore = pcmg.metastore.new()

-- local function build_road(megapathpav, start, finish)
--     local guide_path = pcmg.path.new(start, finish)
--     guide_path:make_slanted(10)
--     local colliding
--     for _, p in guide_path.start:iterator() do
--         local collisions = megapathpav:colliding_points(p.pos, 30, true)
--         if next(collisions) then
--             colliding = collisions
--             guide_path:cut_off(p)
--         end
--     end
--     if colliding then
--         local _, col = next(colliding)
--         guide_path:shorten(4)
--         local extension =
--             pcmg.path.new(guide_path.finish.pos, col.pos)
--         extension:make_slanted(10)
--         guide_path:merge(extension)
--         local branch = col:branch(finish)
--         branch:make_slanted(10)
--         -- road_metastore:set(branch, "style", "wobbly")
--     end
--     return guide_path
-- end

local function build_road(megapathpav, start, finish)
    local guide_path = pcmg.path.new(start, finish)
    guide_path:make_slanted()
    local current_point = guide_path.start
    for nr, p in guide_path.start:iterator() do
        local colliding =
            megapathpav:colliding_segments(current_point.pos, p.pos, 1)
        if next(colliding) then
            guide_path:insert(colliding[1].intersections[1], nr)
        end
        current_point = p
    end
    return guide_path
end

local function road_generator(megacanv, pathpaver_cache)
    megacanv:set_metastore(road_metastore)
    local road_origins = pcmg.citychunk_road_origins(megacanv.origin)
    local connected_points = connect_road_origins(megacanv.origin, road_origins)
    local megapathpav = pcmg.megapathpaver.new(megacanv.origin, pathpaver_cache)
    for _, points in ipairs(connected_points) do
        local start = points[1]
        local finish = points[2]
        local path = build_road(megapathpav, start, finish)
        megapathpav:save_path(path)
        draw_points(megacanv, road_origins)
    end
    for _, path in pairs(megapathpav.paths) do
        -- for _, p in path.start:iterator() do
        --     if math.random() > 0.5 then
        --         road_metastore:set(p, "style", "wobbly")
        --     end
        -- end
        megacanv:draw_path(road_shape, path, "straight")
        megacanv:draw_path_points(midpoint_shape, path)
    end
end

function pcmg.generate_roads(megacanv, pathpaver_cache)
    local t1 = minetest.get_us_time()
    megacanv:generate(road_generator, 1, pathpaver_cache)
    minetest.log("error", string.format("Overgen time: %g ms", (minetest.get_us_time() - t1) / 1000))
end
