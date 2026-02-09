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
local canvas_shapes = pcmg.canvas_shapes

local materials_by_id, materials_by_name = dofile(mod_path.."/canvas_ids.lua")

-- Sizes of map division units
local node = units.sizes.node
local mapchunk = units.sizes.mapchunk
local citychunk = units.sizes.citychunk

-------------------------------------------------------------------------
-- Canvas 3D
-------------------------------------------------------------------------

--[[
    ** Overview **
    Canvas3D is a data type for storing and processing 3D citychunk (node) data.
    Canvas3D is meant to be a blueprint that provides a layer of abstraction between
    map planning and actual mapgen. The main use case is generating complex map
    layouts, for example a layout of a city.
    canvas3d.array[x][y][z] is a 3D array that stores material IDs (see canvas_ids.lua)
    that correspond to nodes, node groups or more abstract concepts (like building
    placeholders). Each element of the array is called a "cell" and stores data for
    one node. The canvas3d array is the size of a citychunk.
    Canvas3D has a built-in cursor that points to a position where data can be read/written.
    The cursor can be moved around and set to an arbitrary position in the citychunk,
    but also in a slightly bigger area called "canvas margin" that includes parts
    of surrounding citychunks. This design allows for overgeneration, but doesn't
    provide it directly as the canvas can only write/read its own cells that are contained
    in the citychunk. Real overgeneration is provided by Megacanvas3D (see megacanvas3d.lua).

    Also see the comment on the bottom of the file, if tempted to add more features
    to the canvas3d.
--]]

pcmg.canvas3d = {}
local canvas3d = pcmg.canvas3d
canvas3d.__index = canvas3d

local blank_id = 1

--[[
    Canvas margin is the area around the citychunk
    where writing/reading to/from the canvas is still active.
    This allows writing to the citychunk even if the shape
    is partially outside the canvas.
    This means overgeneration will only work for nodes in that area.
--]]
local canvas_margin = units.sizes.citychunk.overgen_margin  -- A vector
local canvas_size = citychunk.in_nodes  -- A vector
local margin_vector = canvas_margin
local margin_min = citychunk.pos_min - margin_vector
local margin_max = citychunk.pos_max + margin_vector

-- Creates a blank citychunk array
-- Note: Canvas3D is 3D (x, y, z), so we use all three components
local function new_blank()
    local blank_template = {}
    local size_x = canvas_size.x + 2 * canvas_margin.x
    local size_y = canvas_size.y + 2 * canvas_margin.y
    local size_z = canvas_size.z + 2 * canvas_margin.z
    for x = 1, size_x do
        blank_template[x] = {}
        for y = 1, size_y do
            blank_template[x][y] = {}
            for z = 1, size_z do
                blank_template[x][y][z] = blank_id
            end
        end
    end
    return blank_template
end

-- Creates a new canvas3d object for the citychunk
-- specified by 'citychunk_origin'
-- (see pcmg.mapchunk_origin in utils.lua)
function canvas3d.new(citychunk_origin)
    local canv = {}
    canv.origin = vector.copy(citychunk_origin)
    canv.terminus = pcmg.citychunk_terminus(canv.origin)
    canv.array = new_blank()
    canv.cursor_inside = true
    canv.cursor = vector.new(0, 0, 0)
    canv.metastore = pcmg.metastore.new()
    return setmetatable(canv, canvas3d)
end

function canvas3d:set_metastore(mt)
    if not pcmg.metastore.check(mt) then
        error("Canvas3D: 'mt' is not a proper metastore object: "..shallow_dump(mt))
    end
    self.metastore = mt
end

-- Sets cursor to a citychunk-relative position
-- x, y, z should have values from 0 to citychunk size - 1
function canvas3d:set_cursor(pos)
    self.cursor_inside = vector.in_area(pos, margin_min, margin_max)
    self.cursor = vector.copy(pos)
end

-- Sets cursor to an absolute position 'pos'
-- The function actually translates absolute position
-- to citychunk-relative position that the cursor stores
function canvas3d:set_cursor_absolute(pos)
    local relative = pos - self.origin
    self:set_cursor(relative)
end

-- Moves cursor by a vector 'vec'
function canvas3d:move_cursor(vec)
    self:set_cursor(self.cursor + vec)
end

-- Reads a cell for a citychunk-relative position given by x, y, z
-- Returns material ID of the cell or blank_id if the position
-- is out of bounds of the canvas
function canvas3d:read_cell(x, y, z)
    local new_x = x + 1 + canvas_margin.x
    local new_y = y + 1 + canvas_margin.y
    local new_z = z + 1 + canvas_margin.z
    if self.array[new_x] and self.array[new_x][new_y] then
        return self.array[new_x][new_y][new_z] or blank_id
    end
    return blank_id
end

-- Returns material priority for a cell at
-- the citychunk-relative position given by x, y, z
-- Returns the lowest priority if the position is out of bounds
function canvas3d:cell_priority(x, y, z)
    local id = self:read_cell(x, y, z)
    local material = materials_by_id[id]
    return material.priority
end

-- Writes material ID to the cell at the citychunk-relative position x, y, z
-- The data is only written if priority of the new material is equal or
-- higher than the priority of the old material.
-- When the position is out of bounds, no data is written.
function canvas3d:write_cell(x, y, z, material_id)
    local priority = materials_by_id[material_id].priority
    local new_x = x + 1 + canvas_margin.x
    local new_y = y + 1 + canvas_margin.y
    local new_z = z + 1 + canvas_margin.z
    if self.array[new_x] and self.array[new_x][new_y] and self.array[new_x][new_y][new_z] and
        priority >= self:cell_priority(x, y, z) then
        self.array[new_x][new_y][new_z] = material_id
    end
end

-- A function that combines functions of 'read_cell', 'write_cell' and
-- 'cell_priority'. It likely makes it faster.
function canvas3d:read_write_cell(x, y, z, material_id)
    local new_x = x + 1 + canvas_margin.x
    local new_y = y + 1 + canvas_margin.y
    local new_z = z + 1 + canvas_margin.z
    if not self.array[new_x] or not self.array[new_x][new_y] then
        return
    end
    local old_id = self.array[new_x][new_y][new_z]
    if not old_id then
        return
    end
    local old_priority = materials_by_id[old_id].priority
    local priority = materials_by_id[material_id].priority
    if priority >= old_priority then
        self.array[new_x][new_y][new_z] = material_id
    end
end

-- Checks if a material ID is present in the canvas within
-- the area defined by 'shape' that's attached to the cursor.
-- 'shape' is a table of vectors that describe cell position
-- relative to the cursor. Each element of the 'shape' table
-- is added to the cursor position to get the position in
-- the citychunk.
function canvas3d:search_for_material(shape, material_id)
    if not self.cursor_inside then
        return
    end
    local cursor_pos = vector.round(self.cursor)
    for i = 1, #shape do
        local point = shape[i] + cursor_pos
        local material = self:read_cell(point.x, point.y, point.z)
        if type(material) ~= "number" then
            core.log("error", type(material))
        end
        if material == material_id then
            return true
        end
    end
    return false
end

function canvas3d:draw_shape(shape)
    if not self.cursor_inside then
        return
    end
    local cursor_pos = vector.round(self.cursor)
    for _, cell in pairs(shape) do
        local point = cell.pos + cursor_pos
        self:read_write_cell(point.x, point.y, point.z, cell.material)
    end
end

function canvas3d:draw_brush(brush)
    if not self.cursor_inside then
        return
    end
    local shape = brush:get_shape()
    self:draw_shape(shape)
end

-- Draws a box in the citychunk. 'x_side', 'y_side', and 'z_side' are
-- the dimensions of the box drawn. 'centered' is a bool that when
-- true will center the box around the cursor, when false the box
-- will have its bottom corner at the cursor position and will extend
-- to X+, Y+, and Z+.
function canvas3d:draw_box(x_side, y_side, z_side, material_id, centered)
    assert(x_side >= 1, "Canvas3D box X side is smaller than 1: "..x_side)
    assert(y_side >= 1, "Canvas3D box Y side is smaller than 1: "..y_side)
    assert(z_side >= 1, "Canvas3D box Z side is smaller than 1: "..z_side)
    if not self.cursor_inside then
        return
    end
    local shape = {}
    local start_x = centered and -math.floor(x_side / 2) or 0
    local start_y = centered and -math.floor(y_side / 2) or 0
    local start_z = centered and -math.floor(z_side / 2) or 0
    for x = start_x, start_x + x_side - 1 do
        for y = start_y, start_y + y_side - 1 do
            for z = start_z, start_z + z_side - 1 do
                table.insert(shape, {
                    pos = vector.new(x, y, z),
                    material = material_id
                })
            end
        end
    end
    self:draw_shape(shape)
end

-- Draws a rectangle in the citychunk at the current y level. 'x_side' and 'z_side' are
-- the dimensions of the rectangle drawn. 'centered' is a bool that when
-- true will center the rectangle around the cursor, when false the rectangle
-- will have its bottom left corner at the cursor position and will extend
-- to X+ and Z+.
function canvas3d:draw_rectangle(x_side, z_side, material_id, centered)
    assert(x_side >= 1, "Canvas3D rectangle X side is smaller than 1: "..x_side)
    assert(z_side >= 1, "Canvas3D rectangle Z side is smaller than 1: "..z_side)
    if not self.cursor_inside then
        return
    end
    local shape = {}
    local start_x = centered and -math.floor(x_side / 2) or 0
    local start_z = centered and -math.floor(z_side / 2) or 0
    for x = start_x, start_x + x_side - 1 do
        for z = start_z, start_z + z_side - 1 do
            table.insert(shape, {
                pos = vector.new(x, 0, z),
                material = material_id
            })
        end
    end
    self:draw_shape(shape)
end

-- Works just like canvas3d:draw_rectangle (see above) but draws
-- a square.
function canvas3d:draw_square(side, material_id, centered)
    assert(side >= 1, "Canvas3D square side is smaller than 1: "..side)
    if not self.cursor_inside then
        return
    end
    self:draw_rectangle(side, side, material_id, centered)
end

-- Draws a circle at the current y level as created by 'make_circle'
-- into the canvas using 'material_id'.
function canvas3d:draw_circle(radius, material_id)
    assert(radius >= 1, "Canvas3D circle radius is smaller than 1: "..radius)
    if not self.cursor_inside then
        return
    end
    local shape =
        canvas_shapes.make_circle(radius, material_id)
    self:draw_shape(shape)
end

-- Searches for a material in the area of canvas covered by
-- a circle with radius 'radius' created by 'make_circle' at current y level.
-- Returns true if the material was found, false if not.
function canvas3d:search_in_circle(radius, material_id)
    assert(radius >= 1, "Canvas3D circle radius is smaller than 1: "..radius)
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
function canvas3d:mapchunk_indices(pos_min, pos_max)
    local array_pos_min =
        pos_min - self.origin + vector.new(1, 1, 1) + margin_vector
    local array_pos_max =
        pos_max - self.origin + vector.new(1, 1, 1) + margin_vector
    return array_pos_min, array_pos_max
end

--[[
    READ THIS:
    Before adding more features into the canvas3d, keep in mind that
    it doesn't provide overgeneration by itself.
    This means canvas3d will only properly overgenerate things
    that don't rely on randomness or rely on randomness that
    is reproducible and independent on the citychunk (i.e.
    randomness NOT bootstrapped with values like citychunk origin/hash).
    Use Megacanvas3D instead for functions that use not reproducible
    randomness or avoid it altogether.
--]]
