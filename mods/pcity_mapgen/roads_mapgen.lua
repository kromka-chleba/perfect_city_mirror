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

-- node IDs
local asphalt_id = minetest.get_content_id(road_definition.floor)
local pavement_id = minetest.get_content_id(road_definition.pavement)
local blue_id = minetest.get_content_id("pcity_nodes:roughcast_blue")
local green_id = minetest.get_content_id("pcity_nodes:roughcast_green")

-- canvas material IDs
local blank_id = materials_by_name["blank"]
local road_asphalt_id = materials_by_name["road_asphalt"]
local road_pavement_id = materials_by_name["road_pavement"]
local road_center_id = materials_by_name["road_center"]
local road_origin_id = materials_by_name["road_origin"]

function pcmg.write_roads(mapgen_args, canv)
    local t1 = minetest.get_us_time()
    local vm, pos_min, pos_max, blockseed = unpack(mapgen_args)
    local citychunk_origin = pcmg.citychunk_origin(pos_min)
    local data = vm:get_data()
    local emin, emax = vm:get_emerged_area()
    local va = VoxelArea(emin, emax)

    local array_min, array_max = canv:mapchunk_indices(pos_min, pos_max)
    for x = array_min.x, array_max.x do
        for z = array_min.z, array_max.z do
            local cell_id = canv.array[x][z]
            if cell_id ~= blank_id then
                local abs_pos = pos_min + vector.new(x, 0, z) - array_min
                abs_pos.y = sizes.ground_level
                local i = va:indexp(abs_pos)
                if cell_id == road_asphalt_id then
                    data[i] = asphalt_id
                elseif cell_id == road_pavement_id then
                    data[i] = pavement_id
                elseif cell_id == road_center_id then
                    data[i] = blue_id
                elseif cell_id == road_origin_id then
                    data[i] = green_id
                end
            end
        end
    end

    -- Write data
    vm:set_data(data)
    --minetest.log("error", string.format("chunk writing time: %g ms", (minetest.get_us_time() - t1) / 1000))
end
