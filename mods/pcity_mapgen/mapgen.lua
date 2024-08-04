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
local ms = mapchunk_shepherd
pcity_mapgen = {}
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units
local math = math
local mlib = dofile(mod_path.."/mlib.lua")
local sizes = dofile(mod_path.."/sizes.lua")

dofile(mod_path.."/utils.lua")
dofile(mod_path.."/paths.lua")
dofile(mod_path.."/pathpaver.lua")
dofile(mod_path.."/megapathpaver.lua")
dofile(mod_path.."/canvas_brushes.lua")
dofile(mod_path.."/canvas.lua")
dofile(mod_path.."/megacanvas.lua")
dofile(mod_path.."/roads_layout.lua")
dofile(mod_path.."/roads_mapgen.lua")

--[[
    For details see comments in utils.lua.
    In mapchunk coords the map spans from -386 to +386
    in all directions.
    Given that pos1 = {-32, -32, -32} and pos2 = {47, 47, 47}
    then the chunk contained in the volume pos1 to pos2 is
    the 0th chunk with mapchunk coordinates x/y/z {0, 0, 0}.
    This means the map is 386 + 386 + 1 = 773 mapchunks wide.
    That's a prime number so I can't divide the map evenly.
--]]

--[[
    The grid of edges is a grid that separates citychunks.
    It's z = 0, x = 0 coordinates start in the mapchunk_offset
    point (by default z/y/x = -32).
--]]

--[[
    Here's a sketch. Squares are citychunks.
    The bottom left point on the grid specifies citychunk coordinates.

    Z+
    ^
    |
    |
    |____ ____
    |1,0 |1,1 |
    |____|____|
    |0,0 |0,1 |
    |____|____|_________> X+
--]]

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

local mapgen_seed = minetest.get_mapgen_setting("seed")

minetest.log("error", mapgen_seed)

local grass_id = minetest.get_content_id("pcity_nodes:grass")
local concrete_id = minetest.get_content_id("pcity_nodes:concrete")
local bricks_id = minetest.get_content_id("pcity_nodes:bricks_red")
local yellow_id = minetest.get_content_id("pcity_nodes:roughcast_yellow")


-- Draws a grid to visualize mapchunks, citychunks and overgeneration
local function helper_grid(mapgen_args)
    local vm, pos_min, pos_max, blockseed = unpack(mapgen_args)

    -- Read data into LVM
    local data = vm:get_data()
    local emin, emax = vm:get_emerged_area()
    local va = VoxelArea(emin, emax)

    for i = 1, #data do
        local pos = va:position(i)
        local chunk_pos = pos - pos_min
        local x = chunk_pos.x
        local z = chunk_pos.z
        local y = chunk_pos.y
        if x >= 0 and x < mapchunk.in_nodes and
            z >= 0 and z < mapchunk.in_nodes and
            pos.y == sizes.ground_level
        then
            if (x == 0 or x == mapchunk.in_nodes - 1 or
                z == 0 or z == mapchunk.in_nodes - 1) and
                data[i] == grass_id then
                -- draw mapchunk borders
                data[i] = concrete_id
            end
            if (x == 16 or x == mapchunk.in_nodes - 16 - 1 or
                z == 16 or z == mapchunk.in_nodes - 16 - 1) then
                -- draw mapchunk overgeneration area
                data[i] = bricks_id
            end
            local mapchunk_pos = units.node_to_mapchunk(pos)
            local citychunk_pos = units.mapchunk_to_citychunk(mapchunk_pos)
            local _, x_fp = math.modf(citychunk_pos.x)
            local _, z_fp = math.modf(citychunk_pos.z)
            if x_fp == 0 or z_fp == 0 then
                -- draw citychunk border
                data[i] = yellow_id
            end
        end
    end

    -- Write data
    vm:set_data(data)
end

local road_canvas_cache = pcmg.megacanvas.cache.new()
local pathpaver_cache = pcmg.megapathpaver.cache.new()

local function mapgen(vm, pos_min, pos_max, blockseed)
    local t1 = minetest.get_us_time()
    local mapgen_args = {vm, pos_min, pos_max, blockseed}
    if pos_max.y >= sizes.ground_level and sizes.ground_level >= pos_min.y then
        helper_grid(mapgen_args)
        local citychunk_origin = pcmg.citychunk_origin(pos_min)
        local hash = pcmg.citychunk_hash(pos_min)
        if not road_canvas_cache.complete[hash] then
            local megacanv = pcmg.megacanvas.new(citychunk_origin, road_canvas_cache)
            pcmg.generate_roads(megacanv, pathpaver_cache)
        end
        local canvas = road_canvas_cache.citychunks[hash]
        pcmg.write_roads(mapgen_args, canvas)
        --minetest.log("error", string.format("elapsed time: %g ms", (minetest.get_us_time() - t1) / 1000))
    end
end

minetest.register_on_generated(mapgen)
