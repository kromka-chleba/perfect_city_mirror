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

local canvas_margin = 2 -- in mapchunks
local canvas_size = citychunk.in_mapchunks + 2 * canvas_margin

local blank_template = {}

for x = 1, mapchunk.in_nodes do
    blank_template[x] = {}
end

local function blank_chunk()
    return table.copy(blank_template)
end

function canvas.new(citychunk_origin, mapchunk_cache)
    local canv = {}
    canv.origin = vector.copy(citychunk_origin)
    canv.chunks = {}
    canv.cache = mapchunk_cache
    local ori_mapchunk = pcmg.mapchunk_coords(citychunk_origin)
    for x = -canvas_margin, canvas_size - 1 do
        for z = -canvas_margin, canvas_size - 1 do
            local mapchunk_coords = ori_mapchunk + vector.new(x, 0, z)
            local hash = minetest.hash_node_position(mapchunk_coords)
            local array = canv.cache[hash] or blank_chunk()
            canv.cache[hash] = array
            canv.chunks[hash] = array
        end
    end
    canv.cursor = vector.new(chunk_start, 0, chunk_start)
    return setmetatable(canv, canvas)
end

-- Makes sure x, z are contained in [min; max]
local function clamp_pos(x, z, min, max)
    local new_x, new_z = math.floor(x), math.floor(z)
    if x < min then
        new_x = min
    end
    if z < min then
        new_z = min
    end
    if x > max then
        new_x = max
    end
    if z > max then
        new_z = max
    end
    return new_x, new_z
end

-- Makes sure position is contained in citychunk, units
-- are expressed in node position relative to citychunk origin
local function clamp_to_citychunk(x, z)
    return clamp_pos(x, z, 0, citychunk.in_nodes - 1)
end

-- Makes sure position is contained in canvas, units
-- are expressed in node position relative to citychunk origin
local function clamp_to_canvas(x, z)
    return clamp_pos(x, z,
                     -canvas_margin * mapchunk.in_nodes,
                     canvas_size * mapchunk.in_nodes - 1)
end

-- translates citychunk-relative pos to array indices
local function array_indices(citychunk_ori, x, z)
    local new_x, new_z = clamp_to_canvas(x, z)
    local abs_pos = citychunk_ori + vector.new(new_x, 0, new_z)
    local hash = pcmg.mapchunk_hash(abs_pos)
    local mapchunk_ori = pcmg.mapchunk_origin(abs_pos)
    local mapchunk_relative = abs_pos - mapchunk_ori + vector.new(1, 1, 1)
    return hash, mapchunk_relative.x, mapchunk_relative.z
end

function canvas:set_cursor(x, z)
    local new_x, new_z = clamp_to_citychunk(x, z)
    self.cursor = vector.new(new_x, 0, new_z)
end

function canvas:read_cell(x, z)
    local hash, new_x, new_z = array_indices(self.origin, x, z)
    return self.chunks[hash][new_x][new_z] or blank_id
end

function canvas:cell_priority(x, z)
    local id = self:read_cell(x, z)
    local material = materials_by_id[id]
    return material.priority
end

function canvas:write_cell(x, z, material_id)
    local hash, new_x, new_z = array_indices(self.origin, x, z)
    local priority = materials_by_id[material_id].priority
    if priority >= self:cell_priority(x, z) then
        self.chunks[hash][new_x][new_z] = material_id
    end
end

function canvas:read_write_cell(x, z, material_id)
    local hash, new_x, new_z = array_indices(self.origin, x, z)
    local old_id = self.chunks[hash][new_x][new_z] or blank_id
    local old_priority = materials_by_id[old_id].priority
    local priority = materials_by_id[material_id].priority
    if priority >= old_priority then
        self.chunks[hash][new_x][new_z] = material_id
    end
end

function canvas:move_cursor(vec)
    local v = vector.round(vec) -- only integer moves allowed
    self:set_cursor(self.cursor.x + v.x, self.cursor.z + v.z)
end

function canvas:draw_rectangle(x_side, z_side, material_id, centered)
    assert(x_side >= 1, "Canvas rectangle X side is smaller than 1: "..x_side)
    assert(z_side >= 1, "Canvas rectangle Z side is smaller than 1: "..z_side)
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
    local circle = make_circle(radius, material_id)
    for i = 1, #circle do
        -- write to canvas
        local point = circle[i] + self.cursor
        --self:write_cell(point.x, point.z, material_id)
        self:read_write_cell(point.x, point.z, material_id)
    end
end
