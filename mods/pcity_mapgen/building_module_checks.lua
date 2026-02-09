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
    Validation functions for building_module
--]]

local vector = vector
local pcmg = pcity_mapgen

pcmg.building_module_checks = pcmg.building_module_checks or {}
local checks = pcmg.building_module_checks

-- Valid face names
local VALID_FACES = {
    top = true,
    bottom = true,
    north = true,
    south = true,
    east = true,
    west = true,
}

-- Helper function to create readable error messages
local function dump_value(val)
    if type(val) == "table" then
        if vector.check(val) then
            return string.format("vector(%s, %s, %s)",
                tostring(val.x), tostring(val.y), tostring(val.z))
        end
        return "table"
    end
    return tostring(val)
end

-- Validates arguments for building_module.new
function checks.check_new_arguments(min_pos, max_pos)
    if not vector.check(min_pos) then
        error("Building module: min_pos '" .. dump_value(min_pos) ..
            "' is not a vector.")
    end
    
    if not vector.check(max_pos) then
        error("Building module: max_pos '" .. dump_value(max_pos) ..
            "' is not a vector.")
    end
end

-- Validates that the object is a building module
function checks.check_module(obj)
    if not pcmg.building_module.check(obj) then
        error("Building module: object '" .. dump_value(obj) ..
            "' is not a building module.")
    end
end

-- Validates face name
function checks.check_face_name(face)
    if type(face) ~= "string" then
        error("Building module: face name '" .. dump_value(face) ..
            "' is not a string.")
    end
    
    if not VALID_FACES[face] then
        error("Building module: invalid face name '" .. face ..
            "'. Must be one of: top, bottom, north, south, east, west.")
    end
end

-- Validates schematic
function checks.check_schematic(schematic)
    if type(schematic) ~= "table" then
        error("Building module: schematic '" .. dump_value(schematic) ..
            "' is not a table.")
    end
end

-- Validates string argument
function checks.check_string(value, name)
    if type(value) ~= "string" then
        error("Building module: " .. name .. " '" .. dump_value(value) ..
            "' is not a string.")
    end
end

-- Validates vector argument
function checks.check_vector(value, name)
    if not vector.check(value) then
        error("Building module: " .. name .. " '" .. dump_value(value) ..
            "' is not a vector.")
    end
end

-- Validates number argument
function checks.check_number(value, name)
    if type(value) ~= "number" then
        error("Building module: " .. name .. " '" .. dump_value(value) ..
            "' is not a number.")
    end
end

-- Validates rotation angle
function checks.check_rotation_angle(angle)
    checks.check_number(angle, "rotation angle")
    
    if angle % 90 ~= 0 then
        error("Building module: rotation angle must be a multiple of 90, " ..
            "got " .. tostring(angle))
    end
end

return pcmg.building_module_checks
