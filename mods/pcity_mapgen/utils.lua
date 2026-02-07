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

local mod_name = minetest.get_current_modname()
local mod_path = minetest.get_modpath("pcity_mapgen")

local math = math
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units

-- By default chunksize is 5
local blocks_per_chunk = tonumber(minetest.get_mapgen_setting("chunksize"))
-- By default 80
local mapchunk_size = blocks_per_chunk * 16
-- By default -32
local mapchunk_offset = -16 * math.floor(blocks_per_chunk / 2)

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

-- Returns mapchunk coordinates of the mapchunk in mapchunk units.
-- Takes node position as pos.
function pcmg.mapchunk_coords(pos)
    local origin = vector.subtract(pos, mapchunk_offset)
    origin = vector.divide(origin, mapchunk_size)
    origin = vector.floor(origin)
    return origin
end

-- Returns citychunk coordinates of the citychunk in citychunk units.
-- Takes node position as pos.
function pcmg.citychunk_coords(pos)
    local mapchunk_pos = pcmg.mapchunk_coords(pos)
    local origin = vector.divide(mapchunk_pos, citychunk.in_mapchunks)
    origin = vector.floor(origin)
    return origin
end

-- Returs origin point of a mapchunk stated in absolute node position.
function pcmg.mapchunk_origin(pos)
    local coords = pcmg.mapchunk_coords(pos)
    return units.mapchunk_to_node(coords)
end

-- Returs terminus point of a mapchunk stated in absolute node position.
function pcmg.mapchunk_terminus(pos)
    local origin = pcmg.citychunk_origin(pos)
    local t = mapchunk.in_nodes
    return origin + vector.new(t, t, t)
end

-- Returs origin point of a citychunk stated in absolute node position.
function pcmg.citychunk_origin(pos)
    local coords = pcmg.citychunk_coords(pos)
    return units.citychunk_to_node(coords)
end

-- Returs terminus point of a citychunk stated in absolute node position.
function pcmg.citychunk_terminus(pos)
    local origin = pcmg.citychunk_origin(pos)
    local t = citychunk.in_nodes - 1
    return origin + vector.new(t, t, t)
end

-- Returns mapchunk hash for a given position
function pcmg.mapchunk_hash(pos)
    local origin = pcmg.mapchunk_origin(pos)
    return minetest.hash_node_position(origin)
end

-- Returns citychunk hash for a given position
function pcmg.citychunk_hash(pos)
    local origin = pcmg.citychunk_origin(pos)
    return minetest.hash_node_position(origin)
end

-- Returns node position relative to citychunk origin point.
-- citychunk pos is in citychunks
function pcmg.node_citychunk_relative_pos(pos)
    local pos = units.citychunk_to_node(citychunk_pos)
    local origin = pcmg.citychunk_origin(pos)
    return pos - origin
end

-- Returns citychunk origins of neighboring citychunks
-- pos is position of any node from a citychunk
function pcmg.citychunk_neighbors(pos)
    local coords = pcmg.citychunk_coords(pos)
    local neighbors = {}
    for x = -1, 1 do
        for z = -1, 1 do
            local neighbor = coords + vector.new(x, 0, z)
            if x ~= 0 or z ~= 0 then
                table.insert(neighbors, units.citychunk_to_node(neighbor))
            end
        end
    end
    return neighbors
end

local mapgen_seed = minetest.get_mapgen_setting("seed")

function pcmg.set_randomseed(citychunk_origin)
    local coords = pcmg.citychunk_coords(citychunk_origin)
    local seed = bit.tobit(mapgen_seed)
    seed = bit.rol(seed, coords.x)
    if seed % 2 == 0 then
        seed = bit.bxor(seed, bit.tobit(mapgen_seed))
    end
    seed = bit.rol(seed, coords.z)
    math.randomseed(math.abs(seed))
end

-- splits a vector into a table of smaller vectors
-- nr is the number of new vectors
function vector.split(v, nr)
    local new_segments = {}
    local seg_nr = math.floor(nr)
    if seg_nr >= 1 then
        local new_v = vector.divide(v, seg_nr)
        for i = 1, seg_nr do
            table.insert(new_segments, new_v)
        end
        return new_segments
    else
        -- return only one segment
        return {v}
    end
end

function vector.modf(v)
    local x_int, x_frac = math.modf(v.x)
    local y_int, y_frac = math.modf(v.y)
    local z_int, z_frac = math.modf(v.z)
    return vector.new(x_int, y_int, z_int),
        vector.new(x_frac, y_frac, z_frac)
end

function vector.sign(v)
    return vector.apply(v, math.sign)
end

function vector.ceil(v)
    return vector.apply(v, math.ceil)
end

function vector.abs(v)
    return vector.apply(v, math.abs)
end

function table.better_length(t)
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
    end
    return count
end

function vector.create(f, ...)
    return vector.new(f(...), f(...), f(...))
end

function vector.random(...)
    return vector.create(math.random, ...)
end

-- Calculates an average from multiple vectors.
function vector.average(...)
    local vectors = {...}
    local avg = vectors[1]
    for i = 2, #vectors do
        avg = (avg + vectors[i]) / 2
    end
    return avg
end

function pcmg.random_pos_in_citychunk(citychunk_origin)
    local point = citychunk_origin + vector.random(0, citychunk.in_nodes - 1)
    return point
end

local function print_table(t, ret, name)
    table.insert(ret, string.format("%s: \n {\n", name))
    for k, v in pairs(t) do
        if type(v) ~= "table" and type(v) ~= "function" then
            table.insert(ret, string.format("\t %s = %s , \n", k, v))
        else
            table.insert(ret, string.format("\t %s = <%s> , \n", k, type(v)))
        end
    end
    table.insert(ret, "}\n")
end

-- Dumps information about an object as a formatted string. Doesn't
-- follow any references so it is both safe and fast for printing big
-- objects with circular references. Prints names of keys in the
-- object and its metatable and prints types of the values.
function shallow_dump(obj)
    local ret = {"\n"}
    table.insert(ret, string.format("type: %s \n", type(obj)))
    if type(obj) == "table" then
        print_table(obj, ret, "object")
    else
        table.insert(ret, string.format("value: %s \n", obj))
    end
    local mt = getmetatable(obj)
    if mt then
        print_table(mt, ret, "metatable")
    end
    return string.format("\n OBJECT START %s OBJECT END", table.concat(ret, " "))
end
