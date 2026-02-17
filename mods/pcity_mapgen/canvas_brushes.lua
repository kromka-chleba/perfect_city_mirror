--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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
local math = math
local vector = vector
local pcmg = pcity_mapgen
local units = dofile(mod_path.."/units.lua")

-- Sizes of map division units
local node = units.sizes.node
local mapchunk = units.sizes.mapchunk
local citychunk = units.sizes.citychunk

-------------------------------------------------------------------------
-- Canvas Shapes/Brushes
-------------------------------------------------------------------------

pcmg.canvas_shapes = {}
local cs = pcmg.canvas_shapes
cs.cache = {}

--- Generate a hash for a shape to use for caching
-- Creates a base64-encoded hash from the shape name and arguments.
-- @param shape_name string The name of the shape
-- @param args table The arguments used to create the shape
-- @return string Base64-encoded hash
function cs.cheap_hash(shape_name, args)
    local data = args
    table.insert(data, 1, shape_name)
    local serialized = core.serialize(data)
    return core.encode_base64(serialized)
end

--- Create a rectangular shape
-- Returns a cached shape if previously created with the same arguments.
-- @param x_side number Width of the rectangle
-- @param z_side number Depth of the rectangle
-- @param material_id number Material ID for the rectangle
-- @param centered boolean If true, center the rectangle around the origin
-- @return table Array of positions representing the rectangle
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

--- Create a circular shape centered at origin
-- Creates a shape for circle with diameter of 2 * radius + 1.
-- The circle is attached to the cursor by the centermost node.
-- @param radius number Radius of the circle
-- @param material_id number Material ID for the circle
-- @return table Array of cells with pos and material fields
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

--- Convert shape positions to hash table
-- @param shape table Array of cells with pos field
-- @return table Hash table mapping position hashes to cells
local function hash_shape_positions(shape)
    local hashed = {}
    for _, cell in pairs(shape) do
        local hash = core.hash_node_position(cell.pos)
        hashed[hash] = cell
    end
    return hashed
end

--- Convert hash table back to shape array
-- @param hashed table Hash table mapping position hashes to cells
-- @return table Array of cells
local function unhash_shape_positions(hashed)
    local unhashed = {}
    for hash, cell in pairs(hashed) do
        table.insert(unhashed, cell)
    end
    return unhashed
end

--- Create a line shape from origin along a vector
-- @param vec vector Direction and length of the line
-- @param material_id number Material ID for the line
-- @return table Hash table mapping position hashes to cells
function cs.make_line(...)
    local vec, material_id = ...
    local args = {...}
    local hash = cs.cheap_hash("line", args)
    if cs.cache[hash] then
        return cs.cache[hash]
    end
    local samples = vector.split(vec, vector.length(vec) * 3)
    local current_pos = vector.new(0, 0, 0)
    local current_hash = core.hash_node_position(current_pos)
    local cells = {}
    for _, vec in pairs(samples) do
        current_pos = current_pos + vec
        local pos = vector.floor(current_pos)
        current_hash = core.hash_node_position(pos)
        cells[current_hash] = {pos = pos, material = material_id}
    end
    cs.cache[hash] = unhash_shape_positions(cells)
    return cells
end

--- Combine two shapes into one
-- Overlapping positions from shape2 will override those from shape1.
-- @param shape1 table First shape array
-- @param shape2 table Second shape array
-- @return table Combined shape array
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

--- Create a new canvas brush
-- @param ... table Variable number of shape arrays
-- @return table Canvas brush object
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

--- Get the current shape from the brush
-- If animate is enabled, advances to the next shape.
-- @return table Current shape array
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
