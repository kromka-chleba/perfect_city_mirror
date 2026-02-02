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
    Controls how streets branch from main roads.
--]]
local street_config = {
    -- Main road settings
    main_road_segment_length = 10,
    
    -- Street branching settings
    min_branch_distance = 30,      -- Minimum distance between branches
    max_branch_distance = 60,      -- Maximum distance between branches
    branch_probability = 0.7,      -- Probability of creating a branch at valid point
    
    -- Street length settings
    min_street_length = 40,
    max_street_length = 120,
    
    -- Secondary street settings (branches from streets)
    secondary_branch_probability = 0.4,
    min_secondary_length = 20,
    max_secondary_length = 60,
    
    -- Geometry settings
    street_segment_length = 8,
    wave_amplitude = 15,
    wave_density = 3,
}

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
    local start_point = pcmg.point.new(start)
    local finish_point = pcmg.point.new(finish)
    local path = pcmg.path.new(start_point, finish_point)
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
    Street Generation Algorithm
    Creates branching streets from main roads using the Path API.
    Streets branch off from main roads at branching points and can
    further subdivide into smaller streets.
--]]

-- Calculate perpendicular direction for branching
local function get_perpendicular_direction(from_pos, to_pos)
    local dir = vector.direction(from_pos, to_pos)
    -- Rotate 90 degrees in the XZ plane
    -- Randomly choose left or right
    if math.random() > 0.5 then
        return vector.new(-dir.z, 0, dir.x)
    else
        return vector.new(dir.z, 0, -dir.x)
    end
end

-- Find suitable branching points along a path
local function find_branching_points(pth, config)
    local branching_points = {}
    local last_branch_distance = 0
    local min_dist = config.min_branch_distance
    local max_dist = config.max_branch_distance
    
    local all_points = pth:all_points()
    local current_distance = 0
    
    for i = 2, #all_points do
        local prev_pos = all_points[i - 1].pos
        local curr_pos = all_points[i].pos
        local segment_length = vector.distance(prev_pos, curr_pos)
        current_distance = current_distance + segment_length
        
        -- Check if we've traveled enough distance since last branch
        local distance_since_branch = current_distance - last_branch_distance
        
        if distance_since_branch >= min_dist then
            -- Probability increases as we get further from min distance
            local branch_chance = config.branch_probability
            if distance_since_branch >= max_dist then
                branch_chance = 1.0  -- Force a branch
            end
            
            if math.random() < branch_chance then
                -- Don't branch at start or finish
                if all_points[i] ~= pth.start and all_points[i] ~= pth.finish then
                    table.insert(branching_points, {
                        point = all_points[i],
                        direction = get_perpendicular_direction(prev_pos, curr_pos)
                    })
                    last_branch_distance = current_distance
                end
            end
        end
    end
    
    return branching_points
end

-- Create a street branch from a point on the main road
local function create_street_branch(branch_point, direction, length, config)
    -- Calculate the end position of the street
    local start_pos = branch_point.pos
    local end_pos = vector.add(start_pos, vector.multiply(direction, length))
    
    -- Use the point:branch() method to create a new path
    local finish_point = pcmg.point.new(end_pos)
    local street = branch_point:branch(finish_point)
    
    -- Apply some curvature to make streets more interesting
    if math.random() > 0.5 then
        street:make_wave(
            math.floor(length / config.street_segment_length),
            config.wave_amplitude,
            config.wave_density
        )
    else
        street:make_slanted(config.street_segment_length)
    end
    
    return street
end

-- Create secondary streets branching from primary streets
local function create_secondary_streets(street, config)
    local secondary_streets = {}
    
    if not pcmg.path.check(street) then
        return secondary_streets
    end
    
    -- Only create secondary branches on longer streets
    if street:length() < config.min_street_length then
        return secondary_streets
    end
    
    local branching_points = find_branching_points(street, {
        min_branch_distance = config.min_secondary_length,
        max_branch_distance = config.max_secondary_length,
        branch_probability = config.secondary_branch_probability,
    })
    
    for _, bp in ipairs(branching_points) do
        local length = math.random(config.min_secondary_length, config.max_secondary_length)
        local secondary = create_street_branch(bp.point, bp.direction, length, config)
        table.insert(secondary_streets, secondary)
    end
    
    return secondary_streets
end

-- Generate streets from a single main road
local function generate_streets_from_road(main_road, config)
    config = config or street_config
    local primary_streets = {}
    local secondary_streets = {}
    
    -- Subdivide main road if needed for more potential branch points
    if not main_road:has_intermediate() then
        main_road:subdivide(config.main_road_segment_length)
    end
    
    -- Find branching points on the main road
    local branching_points = find_branching_points(main_road, config)
    
    -- Create primary streets at each branching point
    for _, bp in ipairs(branching_points) do
        local length = math.random(config.min_street_length, config.max_street_length)
        local street = create_street_branch(bp.point, bp.direction, length, config)
        table.insert(primary_streets, street)
        
        -- Create secondary streets branching from this street
        local secondaries = create_secondary_streets(street, config)
        for _, sec_street in ipairs(secondaries) do
            table.insert(secondary_streets, sec_street)
        end
    end
    
    return primary_streets, secondary_streets
end

-- Generate complete street network from all main roads
local function generate_street_network(megacanv, main_roads, config)
    config = config or street_config
    local all_primary_streets = {}
    local all_secondary_streets = {}
    
    pcmg.set_randomseed(megacanv.origin)
    
    for _, road in ipairs(main_roads) do
        local primary, secondary = generate_streets_from_road(road, config)
        for _, street in ipairs(primary) do
            table.insert(all_primary_streets, street)
        end
        for _, street in ipairs(secondary) do
            table.insert(all_secondary_streets, street)
        end
    end
    
    math.randomseed(os.time())
    return all_primary_streets, all_secondary_streets
end

-- Draw all streets with appropriate shapes
local function draw_streets(megacanv, primary_streets, secondary_streets)
    -- Draw primary streets
    for _, street in ipairs(primary_streets) do
        megacanv:draw_path(street_shape, street, "straight")
        megacanv:draw_path_points(midpoint_shape, street)
    end
    
    -- Draw secondary streets (narrower)
    for _, street in ipairs(secondary_streets) do
        megacanv:draw_path(secondary_street_shape, street, "straight")
    end
end

-- Complete street generation and drawing pipeline
local function generate_and_draw_streets(megacanv, megapathpav, main_roads, config)
    -- Generate street network
    local primary_streets, secondary_streets = 
        generate_street_network(megacanv, main_roads, config)
    
    -- Save streets to pathpaver for collision detection
    for _, street in ipairs(primary_streets) do
        megapathpav:save_path(street)
    end
    for _, street in ipairs(secondary_streets) do
        megapathpav:save_path(street)
    end
    
    -- Draw all streets
    draw_streets(megacanv, primary_streets, secondary_streets)
    
    return primary_streets, secondary_streets
end

local function road_generator(megacanv, pathpaver_cache)
    megacanv:set_metastore(road_metastore)
    local road_origins = pcmg.citychunk_road_origins(megacanv.origin)
    local connected_points = connect_road_origins(megacanv.origin, road_origins)
    local megapathpav = pcmg.megapathpaver.new(megacanv.origin, pathpaver_cache)
    
    -- Build main roads
    local main_roads = {}
    for _, points in ipairs(connected_points) do
        local start = points[1]
        local finish = points[2]
        local path = build_road(megapathpav, start, finish)
        megapathpav:save_path(path)
        table.insert(main_roads, path)
        draw_points(megacanv, road_origins)
    end
    
    -- Draw main roads
    for _, path in pairs(megapathpav.paths) do
        megacanv:draw_path(road_shape, path, "straight")
        megacanv:draw_path_points(midpoint_shape, path)
    end
    
    -- Generate and draw branching streets from main roads
    generate_and_draw_streets(megacanv, megapathpav, main_roads, street_config)
end

function pcmg.generate_roads(megacanv, pathpaver_cache)
    local t1 = minetest.get_us_time()
    megacanv:generate(road_generator, 1, pathpaver_cache)
    --minetest.log("error", string.format("Overgen time: %g ms", (minetest.get_us_time() - t1) / 1000))
end