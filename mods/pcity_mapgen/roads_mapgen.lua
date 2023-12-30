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
local math = math
local mlib = dofile(mod_path.."/mlib.lua")
local sizes = dofile(mod_path.."/sizes.lua")
local _, materials_by_name = dofile(mod_path.."/canvas_ids.lua")
local units = sizes.units

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

-- Road/Street widths in Poland:
-- https://moto.infor.pl/prawo-na-drodze/ciekawostki/5472448,Jaka-szerokosc-maja-drogi-w-Polsce.html

-- node = 0.51 m
-- one lane is 3 m and we have two
-- so 6 m = ~12 nodes

local street_definition = {
    width = 6, --lane width
    floor = "pcity_nodes:asphalt",
    curb = "pcity_nodes:curb_road",
    curb_corner = "pcity_nodes:curb_road_corner",
}

local road_definition = {
    width = 10, --lane width
    floor = "pcity_nodes:asphalt",
    curb = "pcity_nodes:curb_road",
    curb_corner = "pcity_nodes:curb_road_corner",
    pavement = "pcity_nodes:pavement",
}

local mapgen_seed = minetest.get_mapgen_setting("seed")

local function road_segment_range(p1, p2)
    local min, max = vector.sort(p1, p2)
    -- minetest.log("error", "min: "..dump(min))
    -- minetest.log("error", "max: "..dump(max))
    local v = vector.subtract(p2, p1)
    if v.z == 0 and v.x == 0 then
        -- minetest.log("error", "Road has no length: "..dump(v))
    elseif v.z == 0 then
        -- Road goes along Z
        min = min - vector.new(road_definition.width, 0, road_definition.width)
        max = max + vector.new(road_definition.width, 0, road_definition.width)
    elseif v.x == 0 then
        -- Road goes along X
        min = min - vector.new(road_definition.width, 0, road_definition.width)
        max = max + vector.new(road_definition.width, 0, road_definition.width)
    else
        minetest.log("error", "Road has wrong direction: "..dump(v))
    end
    return {min = min, max = max}
end

local function get_ranges(roads)
    local ranges = {}
    for _, road in pairs(roads) do
        local points = pcmg.path.points(road)
        for i = 1, #points do
            points[i] = units.citychunk_to_node(points[i])
            points[i] = vector.new(points[i].x, sizes.ground_level, points[i].z)
        end
        local p1 = points[1]
        for i = 2, #points do
            local p2 = points[i]
            table.insert(ranges, road_segment_range(p1, p2))
            p1 = p2
        end
    end
    return ranges
end

-- node IDs
local asphalt_id = minetest.get_content_id(road_definition.floor)
local pavement_id = minetest.get_content_id(road_definition.pavement)

-- canvas material IDs
local road_asphalt_id = materials_by_name["road_asphalt"]
local road_pavement_id = materials_by_name["road_pavement"]

function pcmg.generate_roads(mapgen_args, canv)
    --local t1 = minetest.get_us_time()
    local vm, pos_min, pos_max, blockseed = unpack(mapgen_args)
    local hash = pcmg.mapchunk_hash(pos_min)
    local data = vm:get_data()
    local emin, emax = vm:get_emerged_area()
    local va = VoxelArea(emin, emax)

    local chunk = canv.chunks[hash]
    for x, row in pairs(chunk) do
        for z, cell_id in pairs(row) do
            local new_pos = vector.new(pos_min.x, sizes.ground_level, pos_min.z)
            new_pos = new_pos + vector.new(x - 1, 0, z - 1)
            local i = va:indexp(new_pos)
            if cell_id == road_asphalt_id then
                data[i] = asphalt_id
            elseif cell_id == road_pavement_id then
                data[i] = pavement_id
            end
        end
    end

    -- Write data
    vm:set_data(data)
    --minetest.log("error", string.format("elapsed time: %g ms", (minetest.get_us_time() - t1) / 1000))
end

local green_id = minetest.get_content_id("pcity_nodes:roughcast_green")

function pcmg.draw_road_origins(mapgen_args, points)
    local positions = {}
    for _, point in pairs(points) do
        local pos = units.citychunk_to_node(point)
        pos = vector.new(pos.x, sizes.ground_level, pos.z)
        table.insert(positions, pos)
    end
    local ranges = {}
    for _, point in pairs(positions) do
        local range = {
            min = vector.subtract(point, vector.new(3, 0, 3)),
            max = vector.add(point, vector.new(3, 0, 3)),
        }
        table.insert(ranges, range)
    end

    local vm, pos_min, pos_max, blockseed = unpack(mapgen_args)
    -- Read data into LVM
    local data = vm:get_data()
    local emin, emax = vm:get_emerged_area()
    local va = VoxelArea(emin, emax)

    for i = 1, #data do
        local pos = va:position(i)
        if pos.y == sizes.ground_level then
            for _, range in pairs(ranges) do
                if vector.in_area(pos, range.min, range.max) then
                    data[i] = green_id
                end
            end
        end
    end
    -- Write data
    vm:set_data(data)
end
