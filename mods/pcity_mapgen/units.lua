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
    Master module for Perfect City coordinate systems and size definitions.
    
    This module provides:
    - Unit conversion functions between coordinate systems
    - Size definitions and constants (in units.sizes, read-only)
    
    Perfect City uses three coordinate systems:
    - Node: Individual block positions (1x1x1)
    - Mapchunk: Minetest's native chunks (can be non-cubic, specified in blocks)
    - Citychunk: Perfect City's larger chunks (typically 10x10 mapchunks)
--]]

local units = {}

-- Get mapchunk size using the new API (returns a vector in blocks)
local chunksize_blocks = core.get_mapgen_chunksize()
-- Convert blocks to nodes (each block is core.MAP_BLOCKSIZE nodes)
local mapchunk_size = vector.multiply(chunksize_blocks, core.MAP_BLOCKSIZE)
-- Calculate offset for chunk alignment (center alignment)
local mapchunk_offset = vector.new(
    -core.MAP_BLOCKSIZE * math.floor(chunksize_blocks.x / 2),
    -core.MAP_BLOCKSIZE * math.floor(chunksize_blocks.y / 2),
    -core.MAP_BLOCKSIZE * math.floor(chunksize_blocks.z / 2)
)
-- Citychunk size in mapchunks (same in all directions for now)
local citychunk_size = tonumber(core.settings:get("pcity_citychunk_size")) or 10

-- ============================================================
-- NODE <-> MAPCHUNK CONVERSIONS
-- ============================================================

-- Translates node position into mapchunk position.
function units.node_to_mapchunk(pos)
    local mapchunk_pos = vector.subtract(vector.floor(pos), mapchunk_offset)
    mapchunk_pos = vector.new(
        mapchunk_pos.x / mapchunk_size.x,
        mapchunk_pos.y / mapchunk_size.y,
        mapchunk_pos.z / mapchunk_size.z
    )
    return mapchunk_pos
end

-- Translates mapchunk position into node position (returns origin corner).
function units.mapchunk_to_node(mapchunk_pos)
    local pos = vector.new(
        mapchunk_pos.x * mapchunk_size.x,
        mapchunk_pos.y * mapchunk_size.y,
        mapchunk_pos.z * mapchunk_size.z
    )
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

-- ============================================================
-- SIZE DEFINITIONS
-- ============================================================

-- Create the sizes table with all size constants
local sizes_table = {}

-- Map divisions
sizes_table.node = {
    in_mapchunks = vector.new(
        1 / mapchunk_size.x,
        1 / mapchunk_size.y,
        1 / mapchunk_size.z
    ),
    in_citychunks = vector.new(
        1 / (mapchunk_size.x * citychunk_size),
        1 / (mapchunk_size.y * citychunk_size),
        1 / (mapchunk_size.z * citychunk_size)
    ),
}

local mapchunk_max = vector.new(
    mapchunk_size.x - 1,
    mapchunk_size.y - 1,
    mapchunk_size.z - 1
)
sizes_table.mapchunk = {
    in_nodes = mapchunk_size,
    in_citychunks = vector.new(
        1 / citychunk_size,
        1 / citychunk_size,
        1 / citychunk_size
    ),
    pos_min = vector.zero(),
    pos_max = mapchunk_max,
}

local citychunk_in_nodes = vector.multiply(mapchunk_size, citychunk_size)
local citychunk_max = vector.subtract(citychunk_in_nodes, 1)
sizes_table.citychunk = {
    in_nodes = citychunk_in_nodes,
    in_mapchunks = citychunk_size,
    pos_min = vector.zero(),
    pos_max = citychunk_max,
    -- Use 2x the largest mapchunk dimension for overgen margin
    overgen_margin = 2 * math.max(mapchunk_size.x, mapchunk_size.y, mapchunk_size.z)
}

-- Height of most rooms
sizes_table.room_height = 7

-- Levels of the layers of the city
sizes_table.ground_level = core.settings:get("mgflat_ground_level") or 8
sizes_table.city_max = sizes_table.ground_level + 20 * sizes_table.room_height -- 148
sizes_table.city_min = sizes_table.ground_level -- 8
sizes_table.basement_max = sizes_table.ground_level - 1 -- 7
sizes_table.basement_max = -12
sizes_table.hell_max_level = -13

-- Make the sizes table read-only using LuaJIT metamethods
local sizes_metatable = {
    __index = sizes_table,
    __newindex = function(t, k, v)
        error("Attempt to modify read-only sizes table (key: " .. tostring(k) .. ")", 2)
    end,
    __metatable = false  -- Hide the metatable
}

-- Create read-only proxy for sizes
units.sizes = setmetatable({}, sizes_metatable)

return units
