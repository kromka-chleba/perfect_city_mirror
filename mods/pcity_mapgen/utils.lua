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

local math = math
local mlib = dofile(mod_path.."/mlib.lua")
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units

-- By default chunksize is 5
local blocks_per_chunk = tonumber(minetest.get_mapgen_setting("chunksize"))
-- By default 80
local mapchunk_size = blocks_per_chunk * 16
-- By default -32
local mapchunk_offset = -16 * math.floor(blocks_per_chunk / 2)
-- Citychunk size in mapchunks
local citychunk_size = 10

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
    local origin = vector.divide(mapchunk_pos, citychunk_size)
    origin = vector.floor(origin)
    return origin
end

-- Returs origin point of a mapchunk in node position.
function pcmg.mapchunk_origin(pos)
    local coords = pcmg.mapchunk_coords(pos)
    return units.mapchunk_to_node(coords)
end

-- Returs origin point of a citychunk in node position.
function pcmg.citychunk_origin(pos)
    local coords = pcmg.citychunk_coords(pos)
    return units.citychunk_to_node(coords)
end

-- Returns mapchunk hash for a given position
function pcmg.mapchunk_hash(pos)
    local coords = pcmg.mapchunk_coords(pos)
    return minetest.hash_node_position(coords)
end

-- Returns citychunk hash for a given position
function pcmg.citychunk_hash(pos)
    local coords = pcmg.citychunk_coords(pos)
    return minetest.hash_node_position(coords)
end

-- Returns node position relative to citychunk origin point.
-- citychunk pos is in citychunks
function pcmg.node_citychunk_relative_pos(citychunk_pos)
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

-- Returns a polygon in mlib format:
-- { x1, z1, x2, z2, x3, z3, ... }
-- for a given mapchunk in citychunk units
function pcmg.mapchunk_polygon(origin)
    local citychunk_coords = units.mapchunk_to_citychunk(origin)
    local mic = mapchunk.in_citychunks
    local p1 = citychunk_coords
    local p2 = vector.add(citychunk_coords, vector.new(mic, 0, 0))
    local p3 = vector.add(citychunk_coords, vector.new(mic, 0, mic))
    local p4 = vector.add(citychunk_coords, vector.new(0, 0, mic))
    return {p1.x, p1.z, p2.x, p2.z, p3.x, p3.z, p4.x, p4.z}
end

-- Translates mlib format {x1, z1, x2, z2 ...} into minetest vectors.
function pcmg.mlib_to_vector(tab)
    local points = {}
    for _, point in ipairs(tab) do
        local p = vector.new(point[1], 0, point[2])
        table.insert(points, p)
    end
    return points
end

-- Trims a segment to mapchunk borders.
-- Returns a table with two points that are both in the mapchunk.
-- Returns nil if the segment is out of the mapchunk.
-- mapchunk_poly is a square (polygon) in mlib format as returned by mapchunk_polygon.
-- p1, p2 are points of the segment to be trimmed.
-- The function preserves the order of points in the path.
function pcmg.trim_segment_to_mapchunk(mapchunk_poly, p1, p2)
    if not mlib.polygon.isSegmentInside(p1.x, p1.z, p2.x, p2.z, mapchunk_poly) then
        -- return nil if segment is not inside the mapchunk
        return
    end
    local new_points = mlib.polygon.getSegmentIntersection(
        p1.x, p1.z, p2.x, p2.z, mapchunk_poly)
    if not new_points then
        -- no intersections, the segment doesn't touch borders
        return {p1, p2}
    end
    new_points = pcmg.mlib_to_vector(new_points)
    local p3, p4 = unpack(new_points)
    local old_direction = vector.direction(p1, p2)
    if p3 and p4 then
        -- two intersections
        local p3_to_p4 = vector.direction(p3, p4)
        if vector.equals(old_direction, p3_to_p4) then
            return {p3, p4}
        else
            return {p4, p3}
        end
    else
        -- one intersection, must be between p1 and p2
        local p3_to_p2 = vector.direction(p3, p2)
        if vector.equals(old_direction, p3_to_p2) then
            return {p3, p2}
        else
            return {p1, p3}
        end
    end
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

-- Return edge descriptions for the citychunk.
-- Edges can have two types: "x" - the edge goes along
-- the x-axis, "z" - the edge goes along the z-axis.
-- nr (number) of the edge is the position on the axis
-- perpendicular to the axis type, e.g. "x" edge the nr
-- is the z coordinate and vice versa
function pcmg.citychunk_edges(citychunk_coords)
    local x = citychunk_coords.x
    local z = citychunk_coords.z
    local edges = {
        {type = "x_bottom", nr = z, origin = x},     -- bottom
        {type = "x_top", nr = z + 1, origin = x},    -- top
        {type = "z_left", nr = x, origin = z},       -- left
        {type = "z_right", nr = x + 1, origin = z},  -- right
    }
    return edges
end

function pcmg.save_randomness()
    return math.floor(math.random() * 10e20)
end

function vector.modf(v)
    local x_int, x_frac = math.modf(v.x)
    local y_int, y_frac = math.modf(v.y)
    local z_int, z_frac = math.modf(v.z)
    return vector.new(x_int, y_int, z_int),
        vector.new(x_frac, y_frac, z_frac)
end

function math.sign(n)
    if n >= 0 then
        return 1
    else
        return -1
    end
end

function vector.sign(v)
    return vector.apply(v, math.sign)
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
