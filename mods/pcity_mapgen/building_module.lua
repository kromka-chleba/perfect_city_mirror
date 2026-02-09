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
    Building Module Class
    
    Represents a modular building component defined by a cuboid space.
    Modules can connect to each other via junction surfaces on their faces.
    Each module contains schematic(s) and can be rotated.
--]]

local mod_path = core.get_modpath("pcity_mapgen")
local vector = vector
local math = math
local pcmg = pcity_mapgen

pcmg.building_module = pcmg.building_module or {}
local building_module = pcmg.building_module
building_module.__index = building_module

local checks = pcmg.building_module_checks or
    dofile(mod_path.."/building_module_checks.lua")
local junction = pcmg.junction or dofile(mod_path.."/junction.lua")

-- Face constants for the 6 faces of a cuboid
-- Using Luanti coordinate system: X+ (east), X- (west), Y+ (up), 
-- Y- (down), Z+ (south), Z- (north)
local FACE_Y_POS = "y+"
local FACE_Y_NEG = "y-"
local FACE_Z_NEG = "z-"
local FACE_Z_POS = "z+"
local FACE_X_POS = "x+"
local FACE_X_NEG = "x-"

-- Valid face names
local VALID_FACES = {
    [FACE_Y_POS] = true,
    [FACE_Y_NEG] = true,
    [FACE_Z_NEG] = true,
    [FACE_Z_POS] = true,
    [FACE_X_POS] = true,
    [FACE_X_NEG] = true,
}

-- Counter for generating unique module IDs
local module_id_counter = 0

-- Creates a new building module with position and size
-- pos: vector - absolute world position (origin point of the module)
-- size: vector - dimensions of the module (x, y, z sizes)
function building_module.new(pos, size)
    checks.check_new_arguments(pos, size)
    
    local m = {}
    module_id_counter = module_id_counter + 1
    m.id = module_id_counter
    m.pos = vector.copy(pos)
    m.size = vector.copy(size)
    m._schematics = {}
    m._junctions = {}
    
    return setmetatable(m, building_module)
end

-- Checks if the object is a building module
function building_module.check(obj)
    return getmetatable(obj) == building_module
end

-- Returns the size of the module as a vector
function building_module:get_size()
    return vector.copy(self.size)
end

-- Returns the center position of the module
function building_module:get_center()
    return vector.add(self.pos, vector.divide(self.size, 2))
end

-- Returns the minimum corner position
function building_module:get_min_pos()
    return vector.copy(self.pos)
end

-- Returns the maximum corner position
function building_module:get_max_pos()
    return vector.subtract(vector.add(self.pos, self.size),
        vector.new(1, 1, 1))
end

-- ============================================================
-- JUNCTION SURFACE MANAGEMENT
-- ============================================================

-- Adds a junction to the module
-- j: junction - Junction object to add
function building_module:add_junction(j)
    if not junction.check(j) then
        error("Building module: object is not a Junction")
    end
    
    -- Store by face (one junction per face for now)
    self._junctions[j.face] = j
end

-- Gets the junction for the specified face
-- Returns nil if no junction is set for that face
function building_module:get_junction(face)
    checks.check_face_name(face)
    return self._junctions[face]
end

-- Removes the junction from the specified face
function building_module:remove_junction(face)
    checks.check_face_name(face)
    self._junctions[face] = nil
end

-- Gets all junctions on this module
function building_module:get_all_junctions()
    local result = {}
    for face, j in pairs(self._junctions) do
        result[face] = j
    end
    return result
end

-- Checks if two modules can connect via their junctions
-- other: building_module - the other module to check
-- this_face: string - face of this module
-- other_face: string - face of the other module
-- Returns true if the junctions match and can connect
function building_module:can_connect(other, this_face, other_face)
    checks.check_module(other)
    checks.check_face_name(this_face)
    checks.check_face_name(other_face)
    
    local this_junction = self:get_junction(this_face)
    local other_junction = other:get_junction(other_face)
    
    if this_junction == nil or other_junction == nil then
        return false
    end
    
    return this_junction:can_connect_with(other_junction)
end

-- Legacy API compatibility: set_junction_surface
-- Creates a simple junction from a type string
-- Deprecated: Use add_junction with proper Junction objects instead
function building_module:set_junction_surface(face, surface_type)
    checks.check_face_name(face)
    
    if type(surface_type) ~= "string" then
        error("Building module: surface_type must be a string")
    end
    
    -- Create a default junction covering the entire face
    local pos_min, pos_max = self:_get_face_bounds(face)
    local j = junction.new(surface_type, pos_min, pos_max, face)
    self:add_junction(j)
end

-- Legacy API compatibility: get_junction_surface
-- Returns the junction type if exists
-- Deprecated: Use get_junction instead
function building_module:get_junction_surface(face)
    local j = self:get_junction(face)
    if j then
        return j.type
    end
    return nil
end

-- Legacy API compatibility: remove_junction_surface
-- Deprecated: Use remove_junction instead
function building_module:remove_junction_surface(face)
    self:remove_junction(face)
end

-- Helper to get face bounds for legacy API
function building_module:_get_face_bounds(face)
    local size = self.size
    local pos_min, pos_max
    
    if face == "y+" then
        pos_min = vector.new(0, size.y - 1, 0)
        pos_max = vector.new(size.x - 1, size.y - 1, size.z - 1)
    elseif face == "y-" then
        pos_min = vector.new(0, 0, 0)
        pos_max = vector.new(size.x - 1, 0, size.z - 1)
    elseif face == "z-" then
        pos_min = vector.new(0, 0, 0)
        pos_max = vector.new(size.x - 1, size.y - 1, 0)
    elseif face == "z+" then
        pos_min = vector.new(0, 0, size.z - 1)
        pos_max = vector.new(size.x - 1, size.y - 1, size.z - 1)
    elseif face == "x+" then
        pos_min = vector.new(size.x - 1, 0, 0)
        pos_max = vector.new(size.x - 1, size.y - 1, size.z - 1)
    elseif face == "x-" then
        pos_min = vector.new(0, 0, 0)
        pos_max = vector.new(0, size.y - 1, size.z - 1)
    end
    
    return pos_min, pos_max
end

-- ============================================================
-- SCHEMATIC MANAGEMENT
-- ============================================================

-- Adds a schematic to the module with a position relative to origin
-- schematic: table - luanti schematic data
-- relative_pos: vector - position relative to module's origin (0,0,0)
-- name: string (optional) - name identifier for the schematic
function building_module:add_schematic(schematic, relative_pos, name)
    checks.check_schematic(schematic)
    checks.check_vector(relative_pos, "schematic relative position")
    
    local schematic_entry = {
        schematic = schematic,
        relative_pos = vector.copy(relative_pos)
    }
    
    if name ~= nil then
        checks.check_string(name, "schematic name")
        self._schematics[name] = schematic_entry
    else
        table.insert(self._schematics, schematic_entry)
    end
end

-- Gets a schematic entry by name or index
-- identifier: string or number - name or numeric index
-- Returns the schematic entry {schematic=..., relative_pos=...}
-- or nil if not found
function building_module:get_schematic(identifier)
    return self._schematics[identifier]
end

-- Returns all schematic entries as a table
function building_module:get_all_schematics()
    local result = {}
    for k, v in pairs(self._schematics) do
        result[k] = v
    end
    return result
end

-- Removes a schematic by name or index
function building_module:remove_schematic(identifier)
    self._schematics[identifier] = nil
end

-- ============================================================
-- ROTATION
-- ============================================================

-- Rotates the module around the Y axis (vertical/up)
-- angle_degrees: number - rotation angle in degrees (90, 180, 270)
function building_module:rotate_y(angle_degrees)
    checks.check_rotation_angle(angle_degrees)
    self:rotate_axis(vector.new(0, 1, 0), angle_degrees)
    _rotate_junctions_y(self, angle_degrees)
end

-- Rotates the module around a specified axis
-- For voxel games, only x, y, z axes with 90-degree multiples
-- axis: vector - rotation axis (should be unit vector along x, y, or z)
-- angle_degrees: number - rotation angle in degrees (multiple of 90)
function building_module:rotate_axis(axis, angle_degrees)
    checks.check_vector(axis, "rotation axis")
    checks.check_rotation_angle(angle_degrees)
    
    local center = self:get_center()
    local angle_rad = math.rad(angle_degrees)
    local rotation = vector.multiply(axis, angle_rad)
    
    -- Rotate position around center
    local pos_relative = vector.subtract(self.pos, center)
    pos_relative = vector.rotate(pos_relative, rotation)
    self.pos = vector.add(pos_relative, center)
    
    -- Rotate size dimensions for non-cube modules
    local half_size = vector.divide(self.size, 2)
    half_size = vector.rotate(half_size, rotation)
    -- Take absolute values since size must be positive
    self.size = vector.multiply(vector.abs(half_size), 2)
end

-- ============================================================
-- INTERNAL HELPER FUNCTIONS
-- ============================================================

-- Rotates junctions after Y-axis rotation
function _rotate_junctions_y(module, angle_degrees)
    local rotations = math.floor((angle_degrees % 360) / 90)
    if rotations == 0 then
        return
    end
    
    local junctions = module._junctions
    local temp = {}
    
    -- Copy junctions and rotate their positions
    for face, j in pairs(junctions) do
        -- Rotate junction positions around module center
        local center = module:get_center()
        local angle_rad = math.rad(angle_degrees)
        local rotation = vector.new(0, angle_rad, 0)
        
        local pos_min_rel = vector.subtract(j.pos_min, center)
        local pos_max_rel = vector.subtract(j.pos_max, center)
        
        pos_min_rel = vector.rotate(pos_min_rel, rotation)
        pos_max_rel = vector.rotate(pos_max_rel, rotation)
        
        local new_pos_min = vector.add(pos_min_rel, center)
        local new_pos_max = vector.add(pos_max_rel, center)
        
        -- Determine new face after rotation
        local new_face = _rotate_face_y(face, rotations)
        
        -- Create new junction with rotated positions and face
        local new_j = junction.new(j.type, new_pos_min, new_pos_max, new_face)
        temp[new_face] = new_j
    end
    
    module._junctions = temp
end

-- Helper to rotate face name for Y rotation
function _rotate_face_y(face, rotations)
    local face_rotation_map = {
        ["z-"] = "x-",
        ["z+"] = "x+",
        ["x+"] = "z-",
        ["x-"] = "z+",
        ["y+"] = "y+",
        ["y-"] = "y-",
    }
    
    local current_face = face
    for _ = 1, rotations do
        current_face = face_rotation_map[current_face] or current_face
    end
    
    return current_face
end

return pcmg.building_module
