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

-- Face constants for the 6 faces of a cuboid
local FACE_TOP = "top"
local FACE_BOTTOM = "bottom"
local FACE_NORTH = "north"
local FACE_SOUTH = "south"
local FACE_EAST = "east"
local FACE_WEST = "west"

-- Valid face names
local VALID_FACES = {
    [FACE_TOP] = true,
    [FACE_BOTTOM] = true,
    [FACE_NORTH] = true,
    [FACE_SOUTH] = true,
    [FACE_EAST] = true,
    [FACE_WEST] = true,
}

-- Counter for generating unique module IDs
local module_id_counter = 0

-- Creates a new building module with the given bounds
-- min_pos: vector - minimum corner position (inclusive)
-- max_pos: vector - maximum corner position (inclusive)
function building_module.new(min_pos, max_pos)
    checks.check_new_arguments(min_pos, max_pos)
    
    local m = {}
    module_id_counter = module_id_counter + 1
    m.id = module_id_counter
    m.min_pos = vector.copy(min_pos)
    m.max_pos = vector.copy(max_pos)
    m._schematics = {}
    m._junction_surfaces = {}
    
    return setmetatable(m, building_module)
end

-- Checks if the object is a building module
function building_module.check(obj)
    return getmetatable(obj) == building_module
end

-- Returns the size of the module as a vector
function building_module:get_size()
    return vector.subtract(self.max_pos, self.min_pos) +
        vector.new(1, 1, 1)
end

-- Returns the center position of the module
function building_module:get_center()
    return vector.divide(vector.add(self.min_pos, self.max_pos), 2)
end

-- ============================================================
-- JUNCTION SURFACE MANAGEMENT
-- ============================================================

-- Sets a junction surface for the specified face
-- face: string - one of "top", "bottom", "north", "south",
--                "east", "west"
-- surface_id: any - identifier for the junction surface type
function building_module:set_junction_surface(face, surface_id)
    checks.check_face_name(face)
    self._junction_surfaces[face] = surface_id
end

-- Gets the junction surface for the specified face
-- Returns nil if no junction surface is set for that face
function building_module:get_junction_surface(face)
    checks.check_face_name(face)
    return self._junction_surfaces[face]
end

-- Removes the junction surface from the specified face
function building_module:remove_junction_surface(face)
    checks.check_face_name(face)
    self._junction_surfaces[face] = nil
end

-- Checks if two modules can connect via their junction surfaces
-- other: building_module - the other module to check
-- this_face: string - face of this module
-- other_face: string - face of the other module
-- Returns true if the junction surfaces match
function building_module:can_connect(other, this_face, other_face)
    checks.check_module(other)
    checks.check_face_name(this_face)
    checks.check_face_name(other_face)
    
    local this_surface = self:get_junction_surface(this_face)
    local other_surface = other:get_junction_surface(other_face)
    
    if this_surface == nil or other_surface == nil then
        return false
    end
    
    return this_surface == other_surface
end

-- ============================================================
-- SCHEMATIC MANAGEMENT
-- ============================================================

-- Adds a schematic to the module
-- schematic: table - luanti schematic data
-- name: string (optional) - name identifier for the schematic
function building_module:add_schematic(schematic, name)
    checks.check_schematic(schematic)
    
    if name ~= nil then
        checks.check_string(name, "schematic name")
        self._schematics[name] = schematic
    else
        table.insert(self._schematics, schematic)
    end
end

-- Gets a schematic by name or index
-- identifier: string or number - name or numeric index
-- Returns the schematic or nil if not found
function building_module:get_schematic(identifier)
    return self._schematics[identifier]
end

-- Returns all schematics as a table
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
    
    local center = self:get_center()
    self.min_pos = _rotate_point_y(self.min_pos, center, angle_degrees)
    self.max_pos = _rotate_point_y(self.max_pos, center, angle_degrees)
    
    _normalize_bounds(self)
    _rotate_junction_surfaces_y(self, angle_degrees)
end

-- Rotates the module around an arbitrary axis
-- axis: vector - normalized rotation axis
-- angle_degrees: number - rotation angle in degrees
function building_module:rotate_axis(axis, angle_degrees)
    checks.check_vector(axis, "rotation axis")
    checks.check_number(angle_degrees, "rotation angle")
    
    local center = self:get_center()
    self.min_pos = _rotate_point_axis(
        self.min_pos, center, axis, angle_degrees)
    self.max_pos = _rotate_point_axis(
        self.max_pos, center, axis, angle_degrees)
    
    _normalize_bounds(self)
end

-- ============================================================
-- INTERNAL HELPER FUNCTIONS
-- ============================================================

-- Rotates a point around a center point on the Y axis
function _rotate_point_y(point, center, angle_degrees)
    local rad = math.rad(angle_degrees)
    local cos_a = math.cos(rad)
    local sin_a = math.sin(rad)
    
    local dx = point.x - center.x
    local dz = point.z - center.z
    
    return vector.new(
        center.x + dx * cos_a - dz * sin_a,
        point.y,
        center.z + dx * sin_a + dz * cos_a
    )
end

-- Rotates a point around a center using axis-angle rotation
function _rotate_point_axis(point, center, axis, angle_degrees)
    local rad = math.rad(angle_degrees)
    local cos_a = math.cos(rad)
    local sin_a = math.sin(rad)
    local one_minus_cos = 1 - cos_a
    
    local p = vector.subtract(point, center)
    local ax, ay, az = axis.x, axis.y, axis.z
    
    local rotated = vector.new(
        (cos_a + ax * ax * one_minus_cos) * p.x +
        (ax * ay * one_minus_cos - az * sin_a) * p.y +
        (ax * az * one_minus_cos + ay * sin_a) * p.z,
        
        (ay * ax * one_minus_cos + az * sin_a) * p.x +
        (cos_a + ay * ay * one_minus_cos) * p.y +
        (ay * az * one_minus_cos - ax * sin_a) * p.z,
        
        (az * ax * one_minus_cos - ay * sin_a) * p.x +
        (az * ay * one_minus_cos + ax * sin_a) * p.y +
        (cos_a + az * az * one_minus_cos) * p.z
    )
    
    return vector.add(rotated, center)
end

-- Ensures min_pos has smaller coordinates than max_pos
function _normalize_bounds(module)
    local min_x = math.min(module.min_pos.x, module.max_pos.x)
    local max_x = math.max(module.min_pos.x, module.max_pos.x)
    local min_y = math.min(module.min_pos.y, module.max_pos.y)
    local max_y = math.max(module.min_pos.y, module.max_pos.y)
    local min_z = math.min(module.min_pos.z, module.max_pos.z)
    local max_z = math.max(module.min_pos.z, module.max_pos.z)
    
    module.min_pos = vector.new(min_x, min_y, min_z)
    module.max_pos = vector.new(max_x, max_y, max_z)
end

-- Rotates junction surfaces after Y-axis rotation
function _rotate_junction_surfaces_y(module, angle_degrees)
    local rotations = math.floor((angle_degrees % 360) / 90)
    if rotations == 0 then
        return
    end
    
    local surfaces = module._junction_surfaces
    local temp = {}
    
    for face, surface_id in pairs(surfaces) do
        temp[face] = surface_id
    end
    
    for _ = 1, rotations do
        local new_temp = {}
        new_temp[FACE_TOP] = temp[FACE_TOP]
        new_temp[FACE_BOTTOM] = temp[FACE_BOTTOM]
        new_temp[FACE_NORTH] = temp[FACE_WEST]
        new_temp[FACE_SOUTH] = temp[FACE_EAST]
        new_temp[FACE_EAST] = temp[FACE_NORTH]
        new_temp[FACE_WEST] = temp[FACE_SOUTH]
        temp = new_temp
    end
    
    module._junction_surfaces = temp
end

return pcmg.building_module
