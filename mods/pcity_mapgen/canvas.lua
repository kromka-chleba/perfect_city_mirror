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
local canvas_margin = units.sizes.citychunk.overgen_margin  -- Now a vector
local canvas_size = citychunk.in_nodes  -- A vector
local margin_vector = canvas_margin  -- Already a vector, no need to multiply
local margin_min = citychunk.pos_min - margin_vector
local margin_max = citychunk.pos_max + margin_vector

--- Creates a blank citychunk array
-- Note: Canvas is 2D (x, z), so we use .x and .z components.
-- Pre-calculates sizes for performance optimization.
-- @return table 2D array filled with blank_id values
local blank_size_x = canvas_size.x + 2 * canvas_margin.x
local blank_size_z = canvas_size.z + 2 * canvas_margin.z
local function new_blank()
    local blank_template = {}
    for x = 1, blank_size_x do
        local row = {}
        blank_template[x] = row
        for z = 1, blank_size_z do
            row[z] = blank_id
        end
    end
    return blank_template
end

--- Creates a new canvas object for the citychunk
-- The canvas provides a 2D data structure for storing and processing
-- citychunk node data as a blueprint for map generation.
-- @param citychunk_origin vector The origin position of the citychunk
-- @return table Canvas object with initialized array, cursor, and metastore
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

--- Sets the metastore for this canvas
-- @param mt table Metastore object to assign to this canvas
function canvas:set_metastore(mt)
    if not pcmg.metastore.check(mt) then
        error("Canvas: 'mt' is not a proper metastore object: "..shallow_dump(mt))
    end
    self.metastore = mt
end

--- Sets cursor to a citychunk-relative position
-- Updates cursor_inside flag based on whether position is within canvas margin.
-- @param pos vector Position relative to citychunk origin (x, z from 0 to citychunk size - 1)
function canvas:set_cursor(pos)
    self.cursor_inside = vector.in_area(pos, margin_min, margin_max)
    self.cursor = vector.copy(pos)
    self.cursor.y = 0
end

--- Sets cursor to an absolute position
-- Translates absolute position to citychunk-relative position
-- before storing in the cursor.
-- @param pos vector Absolute world position
function canvas:set_cursor_absolute(pos)
    local relative = pos - self.origin
    self:set_cursor(relative)
end

--- Moves cursor by a relative offset vector
-- @param vec vector Offset to add to current cursor position
function canvas:move_cursor(vec)
    self:set_cursor(self.cursor + vec)
end

-- Cache margin offset calculations
local margin_offset_x = 1 + canvas_margin.x
local margin_offset_z = 1 + canvas_margin.z

--- Reads a cell at citychunk-relative position
-- @param x number X coordinate relative to citychunk origin
-- @param z number Z coordinate relative to citychunk origin
-- @return number Material ID of the cell or blank_id if out of bounds
function canvas:read_cell(x, z)
    local new_x, new_z = x + margin_offset_x, z + margin_offset_z
    local row = self.array[new_x]
    if row then
        return row[new_z] or blank_id
    end
    return blank_id
end

--- Returns material priority for a cell
-- @param x number X coordinate relative to citychunk origin
-- @param z number Z coordinate relative to citychunk origin
-- @return number Material priority (lowest priority if out of bounds)
function canvas:cell_priority(x, z)
    local id = self:read_cell(x, z)
    return materials_by_id[id].priority
end

--- Writes material ID to a cell with priority checking
-- Data is only written if the new material's priority is equal to or
-- higher than the existing material's priority. Out-of-bounds writes are ignored.
-- @param x number X coordinate relative to citychunk origin
-- @param z number Z coordinate relative to citychunk origin
-- @param material_id number Material ID to write
function canvas:write_cell(x, z, material_id)
    local new_x, new_z = x + margin_offset_x, z + margin_offset_z
    local row = self.array[new_x]
    if row and row[new_z] then
        local old_id = row[new_z]
        local old_priority = materials_by_id[old_id].priority
        local priority = materials_by_id[material_id].priority
        if priority >= old_priority then
            row[new_z] = material_id
        end
    end
end

--- Combined read-write operation with priority checking
-- Optimized function that performs read, priority check, and write in one call.
-- @param x number X coordinate relative to citychunk origin
-- @param z number Z coordinate relative to citychunk origin
-- @param material_id number Material ID to write
function canvas:read_write_cell(x, z, material_id)
    local new_x, new_z = x + margin_offset_x, z + margin_offset_z
    local row = self.array[new_x]
    if not row then
        return
    end
    local old_id = row[new_z]
    if not old_id then
        return
    end
    local old_priority = materials_by_id[old_id].priority
    local priority = materials_by_id[material_id].priority
    if priority >= old_priority then
        row[new_z] = material_id
    end
end

--- Searches for a material within a shape area attached to cursor
-- Each element of the shape table contains vectors describing cell positions
-- relative to the cursor. Returns nil if cursor is outside canvas.
-- @param shape table Array of vectors defining positions relative to cursor
-- @param material_id number Material ID to search for
-- @return boolean|nil True if material found, false if not, nil if cursor outside
function canvas:search_for_material(shape, material_id)
    if not self.cursor_inside then
        return
    end
    local cursor_pos = vector.round(self.cursor)
    for i = 1, #shape do
        local point = shape[i] + current_pos
        local material = self:read_cell(point.x, point.z)
        if type(material) ~= "number" then
            core.log("error", type(material))
        end
        if material == material_id then
            return true
        end
    end
    return false
end

--- Draws a shape onto the canvas at cursor position
-- Each element in the shape must have 'pos' (vector) and 'material' (number) fields.
-- @param shape table Array of cells with pos and material fields
function canvas:draw_shape(shape)
    if not self.cursor_inside then
        return
    end
    local cursor_pos = vector.round(self.cursor)
    local cursor_x, cursor_z = cursor_pos.x, cursor_pos.z
    for i = 1, #shape do
        local cell = shape[i]
        local pos = cell.pos
        self:read_write_cell(pos.x + cursor_x, pos.z + cursor_z, cell.material)
    end
end

--- Draws a brush onto the canvas at cursor position
-- @param brush table Brush object with get_shape() method
function canvas:draw_brush(brush)
    if not self.cursor_inside then
        return
    end
    local shape = brush:get_shape()
    self:draw_shape(shape)
end

--- Draws a rectangle in the citychunk
-- When centered is true, rectangle is centered around cursor.
-- When false, cursor is at bottom-left corner extending toward X+ and Z+.
-- @param x_side number Width of rectangle (must be >= 1)
-- @param z_side number Depth of rectangle (must be >= 1)
-- @param material_id number Material ID to use for rectangle
-- @param centered boolean Whether to center rectangle around cursor
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

--- Draws a square in the citychunk
-- Convenience function that calls draw_rectangle with equal sides.
-- @param side number Side length of square (must be >= 1)
-- @param material_id number Material ID to use for square
-- @param centered boolean Whether to center square around cursor
function canvas:draw_square(side, material_id, centered)
    assert(side >= 1, "Canvas square side is smaller than 1: "..side)
    if not self.cursor_inside then
        return
    end
    self:draw_rectangle(side, side, material_id, centered)
end

--- Draws a circle onto the canvas at cursor position
-- @param radius number Radius of circle (must be >= 1)
-- @param material_id number Material ID to use for circle
function canvas:draw_circle(radius, material_id)
    assert(radius >= 1, "Canvas circle radius is smaller than 1: "..radius)
    if not self.cursor_inside then
        return
    end
    local shape =
        canvas_shapes.make_circle(radius, material_id)
    self:draw_shape(shape)
end

--- Searches for a material within a circular area around cursor
-- @param radius number Radius of search circle (must be >= 1)
-- @param material_id number Material ID to search for
-- @return boolean|nil True if material found, false if not, nil if cursor outside
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

--- Returns array indices for a mapchunk within the canvas
-- Translates absolute mapchunk positions to canvas array indices.
-- @param pos_min vector Minimum absolute position of mapchunk
-- @param pos_max vector Maximum absolute position of mapchunk
-- @return vector Minimum array index position
-- @return vector Maximum array index position
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
