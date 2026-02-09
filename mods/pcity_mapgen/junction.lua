--[[
    This is a part of "Perfect City".
    Copyright (C) 2024-2026 Perfect City Team
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
    Junction Class
    
    Represents a junction surface on a building module face.
    Junctions define connection points between modules with specific
    type (e.g., corridor, hall, staircase) and position bounds.
--]]

local mod_path = core.get_modpath("pcity_mapgen")
local vector = vector
local math = math
local pcmg = pcity_mapgen

pcmg.junction = pcmg.junction or {}
local junction = pcmg.junction
junction.__index = junction

local checks = pcmg.junction_checks or
    dofile(mod_path.."/junction_checks.lua")

-- Counter for generating unique junction IDs
local junction_id_counter = 0

-- Creates a new junction with type and position bounds
-- junction_type: string - type of junction (e.g., "corridor", "hall")
-- pos_min: vector - minimum corner position (relative to module origin)
-- pos_max: vector - maximum corner position (relative to module origin)
-- face: string - face this junction is on ("y+", "y-", "z-", "z+", 
--                "x+", "x-")
function junction.new(junction_type, pos_min, pos_max, face)
    checks.check_new_arguments(junction_type, pos_min, pos_max, face)
    
    local j = {}
    junction_id_counter = junction_id_counter + 1
    j.id = junction_id_counter
    j.type = junction_type
    j.pos_min = vector.copy(pos_min)
    j.pos_max = vector.copy(pos_max)
    j.face = face
    
    return setmetatable(j, junction)
end

-- Checks if the object is a junction
function junction.check(obj)
    return getmetatable(obj) == junction
end

-- Returns the size of the junction area
function junction:get_size()
    return vector.subtract(self.pos_max, self.pos_min) +
        vector.new(1, 1, 1)
end

-- Returns the center position of the junction
function junction:get_center()
    return vector.divide(vector.add(self.pos_min, self.pos_max), 2)
end

-- Returns the area of the junction (number of voxels)
function junction:get_area()
    local size = self:get_size()
    -- For a surface, one dimension should be 1
    -- Area is the product of the other two dimensions
    return size.x * size.y * size.z
end

-- Checks if this junction can connect with another
-- Both must have matching types and compatible positions
function junction:can_connect_with(other)
    checks.check_junction(other)
    
    -- Types must match
    if self.type ~= other.type then
        return false
    end
    
    -- Check if junction areas are compatible
    -- (For now, just check if they have the same dimensions)
    local self_size = self:get_size()
    local other_size = other:get_size()
    
    -- Compare non-zero dimensions (surface dimensions)
    local self_dims = {}
    local other_dims = {}
    
    if self_size.x > 1 then table.insert(self_dims, self_size.x) end
    if self_size.y > 1 then table.insert(self_dims, self_size.y) end
    if self_size.z > 1 then table.insert(self_dims, self_size.z) end
    
    if other_size.x > 1 then table.insert(other_dims, other_size.x) end
    if other_size.y > 1 then table.insert(other_dims, other_size.y) end
    if other_size.z > 1 then table.insert(other_dims, other_size.z) end
    
    if #self_dims ~= #other_dims then
        return false
    end
    
    table.sort(self_dims)
    table.sort(other_dims)
    
    for i = 1, #self_dims do
        if self_dims[i] ~= other_dims[i] then
            return false
        end
    end
    
    return true
end

return pcmg.junction
