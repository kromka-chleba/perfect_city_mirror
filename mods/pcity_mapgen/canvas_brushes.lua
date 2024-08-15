--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

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
local vector = vector
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

-------------------------------------------------------------------------
-- Canvas Shapes/Brushes
-------------------------------------------------------------------------

pcmg.canvas_shapes = {}
local cs = pcmg.canvas_shapes
cs.cache = {}

function cs.cheap_hash(shape_name, args)
    local data = args
    table.insert(data, 1, shape_name)
    local serialized = minetest.serialize(data)
    return minetest.encode_base64(serialized)
end

function cs.make_rectangle(...)
    local x_side, z_side, material_id, centered = ...
    local args = {...}
    local hash = cs.cheap_hash("rectangle", args)
    if cs.cache[hash] then
        return cs.cache[hash]
    end
    local positions = {}
    for x = 0, x_side - 1 do
        for z = 0, z_side - 1 do
            table.insert(positions, vector.new(x, 0, z))
        end
    end
    if centered then
        local center = vector.new(
            math.floor(x_side / 2),
            0,
            math.floor(z_side / 2)
        )
        for i = 1, #positions do
            positions[i] = positions[i] - center
        end
    end
    local rectangle = {}
    for _, pos in pairs(positions) do
        table.insert(rectangle, {pos = pos, material = material_id})
    end
    cs.cache[hash] = positions
    return positions
end

-- Creates a shape for circle with with diameter of
-- 2 * 'radius' + 1. The circle is attached to the
-- cursor by the centermost node.
function cs.make_circle(...)
    local radius, material_id = ...
    local args = {...}
    local hash = cs.cheap_hash("circle", args)
    if cs.cache[hash] then
        return cs.cache[hash]
    end
    local square = {}
    for x = -radius, radius do
        for z = -radius, radius do
            table.insert(square, vector.new(x, 0, z))
        end
    end
    local center = vector.new(0, 0, 0)
    -- square to circle
    local circle = {}
    for _, pos in pairs(square) do
        local v = pos - center
        if vector.length(v) <= radius then
            table.insert(circle, {pos = pos, material = material_id})
        end
    end
    cs.cache[hash] = circle
    return circle
end

local function hash_shape_positions(shape)
    local hashed = {}
    for _, cell in pairs(shape) do
        local hash = minetest.hash_node_position(cell.pos)
        hashed[hash] = cell
    end
    return hashed
end

local function unhash_shape_positions(hashed)
    local unhashed = {}
    for hash, cell in pairs(hashed) do
        table.insert(unhashed, cell)
    end
    return unhashed
end

function cs.make_line(...)
    local vec, material_id = ...
    local args = {...}
    local hash = cs.cheap_hash("line", args)
    if cs.cache[hash] then
        return cs.cache[hash]
    end
    local samples = vector.split(vec, vector.length(vec) * 3)
    local current_pos = vector.new(0, 0, 0)
    local current_hash = minetest.hash_node_position(current_pos)
    local cells = {}
    for _, vec in pairs(samples) do
        current_pos = current_pos + vec
        local pos = vector.floor(current_pos)
        current_hash = minetest.hash_node_position(pos)
        cells[current_hash] = {pos = pos, material = material_id}
    end
    cs.cache[hash] = unhash_shape_positions(cells)
    return cells
end

function cs.combine_shapes(shape1, shape2)
    local hashed_1 = hash_shape_positions(shape1)
    local hashed_2 = hash_shape_positions(shape2)
    local hashed_new = table.copy(hashed_1)
    for hash, cell in pairs(hashed_2) do
        hashed_new[hash] = cell
    end
    return unhash_shape_positions(hashed_new)
end

pcmg.canvas_brush = {}
local canvas_brush = pcmg.canvas_brush
canvas_brush.__index = canvas_brush

local shape_cache = {}

function canvas_brush.new(...)
    local shapes = {...}
    local brush = {}
    --brush.center = vector.new(0, 0, 0)
    brush.shapes = shapes
    brush.current = 1
    brush.animate = false
    brush.random_order = false
    return setmetatable(brush, canvas_brush)
end

function canvas_brush:get_shape()
    local index = self.current
    if self.animate then
        if self.random_order then
            self.current = math.random(1, #self.shapes)
        elseif self.current < #self.shapes then
            self.current = self.current + 1
        else
            self.current = 1
        end
    end
    return self.shapes[index]
end
