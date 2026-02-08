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
local units = dofile(mod_path.."/units.lua")
local math = math

pcmg.debug = {}

-- Sizes of map division units
local node = units.sizes.node
local mapchunk = units.sizes.mapchunk
local citychunk = units.sizes.citychunk

-- Node IDs
local grass_id = core.get_content_id("pcity_nodes:grass")
local concrete_id = core.get_content_id("pcity_nodes:concrete")
local bricks_id = core.get_content_id("pcity_nodes:bricks_red")
local yellow_id = core.get_content_id("pcity_nodes:roughcast_yellow")

-- Draws a grid to visualize mapchunks, citychunks and overgeneration
function pcmg.debug.helper_grid(mapgen_args)
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
        if x >= 0 and x < mapchunk.in_nodes.x and
            z >= 0 and z < mapchunk.in_nodes.z and
            pos.y == units.sizes.ground_level
        then
            if (x == 0 or x == mapchunk.in_nodes.x - 1 or
                z == 0 or z == mapchunk.in_nodes.z - 1) and
                data[i] == grass_id then
                -- draw mapchunk borders
                data[i] = concrete_id
            end
            if (x == 16 or x == mapchunk.in_nodes.x - 16 - 1 or
                z == 16 or z == mapchunk.in_nodes.z - 16 - 1) then
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
