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
local mlib = dofile(mod_path.."/mlib.lua")
local vector = vector
local pcmg = pcity_mapgen
local sizes = dofile(mod_path.."/sizes.lua")
local units = sizes.units

local materials_by_id, materials_by_name = dofile(mod_path.."/canvas_ids.lua")

-- Sizes of map division units
local node = sizes.node
local mapchunk = sizes.mapchunk
local citychunk = sizes.citychunk

pcmg.canvas = {}
local canvas = pcmg.canvas
canvas.__index = canvas

local blank_id = 1

local canvas_margin = 2 * mapchunk.in_nodes
local canvas_size = citychunk.in_nodes

local function new_blank()
    local blank_template = {}
    for x = 1, canvas_size do
        blank_template[x] = {}
        for z = 1, canvas_size do
            blank_template[x][z] = blank_id
        end
    end
    return blank_template
end

function canvas.new(citychunk_origin)
    local canv = {}
    canv.origin = vector.copy(citychunk_origin)
    canv.array = new_blank()
    canv.cursor_inside = true
    canv.cursor = vector.new(0, 0, 0)
    return setmetatable(canv, canvas)
end

local function is_position_in_citychunk(x, z)
    if x >= -canvas_margin and x < canvas_size + canvas_margin and
        z >= -canvas_margin and z < canvas_size + canvas_margin then
        return true
    else
        return false
    end
end

function canvas:set_cursor(x, z)
    self.cursor_inside = is_position_in_citychunk(x, z)
    self.cursor = vector.new(x, 0, z)
end

function canvas:set_cursor_absolute(pos)
    local relative = pos - self.origin
    self:set_cursor(relative.x, relative.z)
end

function canvas:move_cursor(vec)
    local v = vector.round(vec) -- only integer moves allowed
    self:set_cursor(self.cursor.x + v.x, self.cursor.z + v.z)
end

function canvas:read_cell(x, z)
    local new_x, new_z = x + 1, z + 1
    if self.array[new_x] then
        return self.array[new_x][new_z] or blank_id
    end
    return blank_id
end

function canvas:cell_priority(x, z)
    local id = self:read_cell(x, z)
    local material = materials_by_id[id]
    return material.priority
end

function canvas:write_cell(x, z, material_id)
    local priority = materials_by_id[material_id].priority
    local new_x, new_z = x + 1, z + 1
    if self.array[new_x] and self.array[new_x][new_z] and
        priority >= self:cell_priority(x, z) then
        self.array[new_x][new_z] = material_id
    end
end

function canvas:read_write_cell(x, z, material_id)
    local new_x, new_z = x + 1, z + 1
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

function canvas:draw_rectangle(x_side, z_side, material_id, centered)
    assert(x_side >= 1, "Canvas rectangle X side is smaller than 1: "..x_side)
    assert(z_side >= 1, "Canvas rectangle Z side is smaller than 1: "..z_side)
    if not self.cursor_inside then
        minetest.log("error", "cursor not inside!")
        return
    end
    local square = {}
    for x = 0, x_side - 1 do
        for z = 0, z_side - 1 do
            table.insert(square, vector.new(x, 0, z))
        end
    end
    if centered then
        local center = vector.new(
            math.floor(x_side / 2),
            0,
            math.floor(z_side / 2)
        )
        for i = 1, #square do
            square[i] = square[i] - center
        end
    end
    for i = 1, #square do
        -- write to canvas
        local point = square[i] + self.cursor
        self:write_cell(point.x, point.z, material_id)
    end
end

function canvas:draw_square(side, material_id, centered)
    assert(side >= 1, "Canvas square side is smaller than 1: "..side)
    self:draw_rectangle(side, side, material_id, centered)
end

local circle_memory = {}

for id, _ in ipairs(materials_by_id) do
    -- initialize memory
    circle_memory[id] = {}
end

local function make_circle(radius, material_id)
    if circle_memory[material_id][radius] then
        return circle_memory[material_id][radius]
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
            table.insert(circle, pos)
        end
    end
    circle_memory[material_id][radius] = circle
    return circle
end

function canvas:draw_circle(radius, material_id)
    assert(radius >= 1, "Canvas circle radius is smaller than 1: "..radius)
    if not self.cursor_inside then
        return
    end
    local circle = make_circle(radius, material_id)
    for i = 1, #circle do
        -- write to canvas
        local point = circle[i] + self.cursor
        --self:write_cell(point.x, point.z, material_id)
        self:read_write_cell(point.x, point.z, material_id)
    end
end

-- pos_min - origin pos of a mapchunk
function canvas:mapchunk_indices(pos_min, pos_max)
    local array_pos_min = pos_min - self.origin + vector.new(1, 1, 1)
    local array_pos_max = pos_max - self.origin + vector.new(1, 1, 1)
    return array_pos_min, array_pos_max
end
