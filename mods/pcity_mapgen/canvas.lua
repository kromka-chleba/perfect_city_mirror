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

local mod_name = minetest.get_current_modname()
local mod_path = minetest.get_modpath("pcity_mapgen")
local math = math
local vector = vector
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units
local canvas_shapes = pcmg.canvas_shapes

local materials_by_id, materials_by_name = dofile(mod_path.."/canvas_ids.lua")

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

-------------------------------------------------------------------------
-- Canvas
-------------------------------------------------------------------------

--[[
    ** Overview **
    Canvas is a data type for storing and processing 2D citychunk (node) data.
    Canvas is meant to be a blueprint that provides a layer of abstraction between
    map planning and actual mapgen. The main use case is generating complex map
    layouts, for example a layout of a city.
    canvas.array[x][z] is a 2D array that stores material IDs (see canvas_ids.lua)
    that correspond to nodes, node groups or more abstract concepts (like building
    placeholders). Each element of the array is called a "cell" and stores data for
    one node. The canvas array is the size of a citychunk.
    Canvas has a built-in cursor that points to a position where data can be read/written.
    The cursor can be moved around and set to an arbitrary position in the citychunk,
    but also in a slightly bigger area called "canvas margin" that includes parts
    of surrounding citychunks. This design allows for overgeneration, but doesn't
    provide it directly as the canvas can only write/read its own cells that are contained
    in the citychunk. Real overgeneration is provided by Megacanvas (see megacanvas.lua).

    Also see the comment on the bottom of the file, if tempted to add more features
    to the canvas.
--]]

pcmg.canvas = {}
local canvas = pcmg.canvas
canvas.__index = canvas

local blank_id = 1

--[[
    Canvas margin is the area around aroud the citychunk
    where writing/reading to/from the canvas is still active.
    This allows writing to the citychunk even if the shape
    is partially outside the canvas.
    This means overgeneration will only work for nodes in that area.
--]]
local canvas_margin = sizes.citychunk.overgen_margin
local canvas_size = citychunk.in_nodes
local margin_vector = vector.new(1, 1, 1) * canvas_margin
local margin_min = citychunk.pos_min - margin_vector
local margin_max = citychunk.pos_max + margin_vector

-- Creates a blank citychunk array
local function new_blank()
    local blank_template = {}
    for x = 1, canvas_size + 2 * canvas_margin do
        blank_template[x] = {}
        for z = 1, canvas_size + 2 * canvas_margin do
            blank_template[x][z] = blank_id
        end
    end
    return blank_template
end

-- Creates a new canvas object for the citychunk
-- specified by 'citychunk_origin'
-- (see pcmg.mapchunk_origin in utils.lua)
function canvas.new(citychunk_origin)
    local canv = {}
    canv.origin = vector.copy(citychunk_origin)
    canv.terminus = pcmg.citychunk_terminus(canv.origin)
    canv.array = new_blank()
    canv.cursor_inside = true
    canv.cursor = vector.new(0, 0, 0)
    canv.metastore = pcmg.metastore.new()
    return setmetatable(canv, canvas)
end

function canvas:set_metastore(mt)
    if not pcmg.metastore.check(mt) then
        error("Canvas: 'mt' is not a proper metastore object: "..shallow_dump(mt))
    end
    self.metastore = mt
end

-- Sets cursor to a mapchunk-relative position
-- x, z should have values from 0 to citychunk size - 1
function canvas:set_cursor(pos)
    self.cursor_inside = vector.in_area(pos, margin_min, margin_max)
    self.cursor = vector.copy(pos)
    self.cursor.y = 0
end

-- Sets cursor to an absolute position 'pos'
-- The function actually translates absolute position
-- to citychunk-relative position that the cursor stores
function canvas:set_cursor_absolute(pos)
    local relative = pos - self.origin
    self:set_cursor(relative)
end

-- Moves cursor by a vector 'vec'
function canvas:move_cursor(vec)
    self:set_cursor(self.cursor + vec)
end

-- Reads a cell for a citychunk-relative position given by x, z
-- Returns material ID of the cell or blank_id if the position
-- is out of bounds of the canvas
function canvas:read_cell(x, z)
    local new_x, new_z = x + 1 + canvas_margin , z + 1 + canvas_margin
    if self.array[new_x] then
        return self.array[new_x][new_z] or blank_id
    end
    return blank_id
end

-- Returns material priority for a cell at
-- the citychunk-relative position given by x, z
-- Returns the lowest priority if the position is out of bounds
function canvas:cell_priority(x, z)
    local id = self:read_cell(x, z)
    local material = materials_by_id[id]
    return material.priority
end

-- Writes material ID to the cell at the citychunk-relative position x, z
-- The data is only written if priority of the new material is equal or
-- higher than the priority of the old material.
-- When the position is out of bounds, no data is written.
function canvas:write_cell(x, z, material_id)
    local priority = materials_by_id[material_id].priority
    local new_x, new_z = x + 1 + canvas_margin, z + 1 + canvas_margin
    if self.array[new_x] and self.array[new_x][new_z] and
        priority >= self:cell_priority(x, z) then
        self.array[new_x][new_z] = material_id
    end
end

-- A function that combines functions of 'read_cell', 'write_cell' and
-- 'cell_priority'. It likely makes it faster.
function canvas:read_write_cell(x, z, material_id)
    local new_x, new_z = x + 1 + canvas_margin, z + 1 + canvas_margin
    if not self.array[new_x] then
        return
    end
    local old_id = self.array[new_x][new_z]
    if not old_id then
        return
    end
    local old_priority = materials_by_id[old_id].priority
    local priority = materials_by_id[material_id].priority
    if priority >= old_priority then
        self.array[new_x][new_z] = material_id
    end
end

-- Checks if a material ID is present in the canvas within
-- the area defined by 'shape' that's attached to the cursor.
-- 'shape' is a table of vectors that describe cell position
-- relative to the cursor. Each element of the 'shape' table
-- is added to the cursor position to get the position in
-- the citychunk.
function canvas:search_for_material(shape, material_id)
    if not self.cursor_inside then
        return
    end
    local cursor_pos = vector.round(self.cursor)
    for i = 1, #shape do
        local point = shape[i] + current_pos
        local material = self:read_cell(point.x, point.z)
        if type(material) ~= "number" then
            minetest.log("error", type(material))
        end
        if material == material_id then
            return true
        end
    end
    return false
end

function canvas:draw_shape(shape)
    if not self.cursor_inside then
        return
    end
    local cursor_pos = vector.round(self.cursor)
    for _, cell in pairs(shape) do
        local point = cell.pos + cursor_pos
        self:read_write_cell(point.x, point.z, cell.material)
    end
end

function canvas:draw_brush(brush)
    if not self.cursor_inside then
        return
    end
    local shape = brush:get_shape()
    self:draw_shape(shape)
end

-- Draws a rectangle with in the citychunk. 'x_side' and 'z_side' are
-- the dimensions of the rectangle drawn. 'centered' is a bool that when
-- true will center the rectangle around the cursor, when false the rectangle
-- will have its bottom left corner at the cursor position and will extend
-- to X+ and Z+.
function canvas:draw_rectangle(x_side, z_side, material_id, centered)
    assert(x_side >= 1, "Canvas rectangle X side is smaller than 1: "..x_side)
    assert(z_side >= 1, "Canvas rectangle Z side is smaller than 1: "..z_side)
    if not self.cursor_inside then
        return
    end
    local shape =
        canvas_shapes.make_rectangle(x_side, z_side, material_id, centered)
    self:draw_shape(shape)
end

-- Works just like canvas:draw_rectangle (see above) but draws
-- a square.
function canvas:draw_square(side, material_id, centered)
    assert(side >= 1, "Canvas square side is smaller than 1: "..side)
    if not self.cursor_inside then
        return
    end
    self:draw_rectangle(side, side, material_id, centered)
end

-- Draws a circle as created by 'make_circle' (see above)
-- into the canvas using 'material_id'.
function canvas:draw_circle(radius, material_id)
    assert(radius >= 1, "Canvas circle radius is smaller than 1: "..radius)
    if not self.cursor_inside then
        return
    end
    local shape =
        canvas_shapes.make_circle(radius, material_id)
    self:draw_shape(shape)
end

-- Searches for a material in the area of canvas covered by
-- a circle with radius 'radius' created by 'make_circle' (see above).
-- Returns true if the material was found, false if not.
function canvas:search_in_circle(radius, material_id)
    assert(radius >= 1, "Canvas circle radius is smaller than 1: "..radius)
    if not self.cursor_inside then
        return
    end
    local circle = canvas_shapes.make_circle(radius, material_id)
    if self:search_for_material(circle, material_id) then
        return true
    end
    return false
end

-- Returns min and max indices (vectors) in citychunk.array that
-- specify min and max position of the mapchunk in the canvas.
-- 'pos_min', 'pos_max' are min and max absolute positions of the mapchunk
function canvas:mapchunk_indices(pos_min, pos_max)
    local array_pos_min =
        pos_min - self.origin + vector.new(1, 1, 1) + margin_vector
    local array_pos_max =
        pos_max - self.origin + vector.new(1, 1, 1) + margin_vector
    return array_pos_min, array_pos_max
end

--[[
    READ THIS:
    Before adding more features into the canvas, keep in mind that
    it doesn't provide overgeneration by itself.
    This means canvas will only properly overgenerate things
    that don't rely on randomness or rely on randomness that
    is reproducible and independent on the citychunk (i.e.
    randomness NOT bootstrapped with values like citychunk origin/hash).
    Use Megacanvas instead for functions that use not reproducible
    randomness or avoid it altogether.
--]]
