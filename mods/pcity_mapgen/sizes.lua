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

--[[
    Size definitions and constants for Perfect City map divisions.
    
    For unit conversion functions, see units.lua.
--]]

local mod_path = core.get_modpath("pcity_mapgen")

local sizes = {}

-- Load unit conversion functions
sizes.units = dofile(mod_path.."/units.lua")

-- By default chunksize is 5
local blocks_per_chunk = tonumber(core.get_mapgen_setting("chunksize"))
-- By default 80
local mapchunk_size = blocks_per_chunk * 16
-- By default -32
local mapchunk_offset = -16 * math.floor(blocks_per_chunk / 2)
-- Citychunk size in mapchunks
local citychunk_size = tonumber(core.settings:get("pcity_citychunk_size")) or 10


-- Map divisions

sizes.node = {
    in_mapchunks = 1 / mapchunk_size,
    in_citychunks = 1 / (mapchunk_size * citychunk_size),
}
local mapchunk_max = mapchunk_size - 1
sizes.mapchunk = {
    in_nodes = mapchunk_size,
    in_citychunks = 1 / citychunk_size,
    pos_min = vector.zero(),
    pos_max = vector.new(mapchunk_max, mapchunk_max, mapchunk_max),
}
local citychunk_in_nodes = citychunk_size * mapchunk_size
local citychunk_max = citychunk_in_nodes - 1
sizes.citychunk = {
    in_nodes = citychunk_in_nodes,
    in_mapchunks = citychunk_size,
    pos_min = vector.zero(),
    pos_max = vector.new(citychunk_max, citychunk_max, citychunk_max),
    overgen_margin = 2 * sizes.mapchunk.in_nodes or
        citychunk_size < 3 and sizes.mapchunk.in_nodes
}

-- Height of most rooms
sizes.room_height = 7

-- Levels of the layers of the city
sizes.ground_level = core.settings:get("mgflat_ground_level") or 8
sizes.city_max = sizes.ground_level + 20 * sizes.room_height -- 148
sizes.city_min = sizes.ground_level -- 8
sizes.basement_max = sizes.ground_level - 1 -- 7
sizes.basement_max = -12
sizes.hell_max_level = -13

return sizes
