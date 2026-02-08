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
    Unit conversion functions for Perfect City coordinate systems.
    
    Perfect City uses three coordinate systems:
    - Node: Individual block positions (1x1x1)
    - Mapchunk: Minetest's native chunks (typically 80x80x80 nodes)
    - Citychunk: Perfect City's larger chunks (typically 10x10 mapchunks)
--]]

local units = {}

-- By default chunksize is 5
local blocks_per_chunk = tonumber(core.get_mapgen_setting("chunksize"))
-- By default 80
local mapchunk_size = blocks_per_chunk * 16
-- By default -32
local mapchunk_offset = -16 * math.floor(blocks_per_chunk / 2)
-- Citychunk size in mapchunks
local citychunk_size = tonumber(core.settings:get("pcity_citychunk_size")) or 10

-- ============================================================
-- NODE <-> MAPCHUNK CONVERSIONS
-- ============================================================

-- Translates node position into mapchunk position.
function units.node_to_mapchunk(pos)
    local mapchunk_pos = vector.subtract(vector.floor(pos), mapchunk_offset)
    mapchunk_pos = vector.divide(mapchunk_pos, mapchunk_size)
    return mapchunk_pos
end

-- Translates mapchunk position into node position (returns origin corner).
function units.mapchunk_to_node(mapchunk_pos)
    local pos = vector.multiply(mapchunk_pos, mapchunk_size)
    pos = vector.add(pos, mapchunk_offset)
    pos = vector.round(pos) -- round to avoid fp garbage
    return pos
end

-- ============================================================
-- MAPCHUNK <-> CITYCHUNK CONVERSIONS
-- ============================================================

-- Translates mapchunk position to citychunk position.
function units.mapchunk_to_citychunk(mapchunk_pos)
    local citychunk_pos = vector.divide(mapchunk_pos, citychunk_size)
    return citychunk_pos
end

-- Translates citychunk position to mapchunk position (returns origin corner).
function units.citychunk_to_mapchunk(citychunk_pos)
    local mapchunk_pos = vector.multiply(citychunk_pos, citychunk_size)
    return mapchunk_pos
end

-- ============================================================
-- CITYCHUNK <-> NODE CONVERSIONS
-- ============================================================

-- Translates citychunk position to node position (returns origin corner).
function units.citychunk_to_node(citychunk_pos)
    local mapchunk_pos = units.citychunk_to_mapchunk(citychunk_pos)
    return units.mapchunk_to_node(mapchunk_pos)
end

return units
