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
    Validation functions for junction
--]]

local vector = vector
local pcmg = pcity_mapgen

pcmg.junction_checks = pcmg.junction_checks or {}
local checks = pcmg.junction_checks

-- Valid face names (Luanti coordinate system)
local VALID_FACES = {
    ["y+"] = true,
    ["y-"] = true,
    ["z-"] = true,
    ["z+"] = true,
    ["x+"] = true,
    ["x-"] = true,
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

-- Checks if positions define a valid surface (area, not volume)
-- on the specified face
local function check_positions_on_face(pos_min, pos_max, face)
    -- Check which coordinate should be constant for this face
    local fixed_coord, fixed_value
    
    if face == "y+" or face == "y-" then
        fixed_coord = "y"
    elseif face == "z+" or face == "z-" then
        fixed_coord = "z"
    elseif face == "x+" or face == "x-" then
        fixed_coord = "x"
    end
    
    -- Check if the fixed coordinate is the same for min and max
    if pos_min[fixed_coord] ~= pos_max[fixed_coord] then
        error("Junction: positions must lie on face " .. face ..
            ", but " .. fixed_coord .. " coordinates differ: " ..
            tostring(pos_min[fixed_coord]) .. " vs " ..
            tostring(pos_max[fixed_coord]))
    end
    
    -- Ensure pos_min <= pos_max for all coordinates
    if pos_min.x > pos_max.x or pos_min.y > pos_max.y or
        pos_min.z > pos_max.z then
        error("Junction: pos_min must be <= pos_max for all coordinates, " ..
            "got pos_min=" .. dump_value(pos_min) ..
            ", pos_max=" .. dump_value(pos_max))
    end
end

-- Validates arguments for junction.new
function checks.check_new_arguments(junction_type, pos_min, pos_max, face)
    if type(junction_type) ~= "string" then
        error("Junction: type '" .. dump_value(junction_type) ..
            "' is not a string.")
    end
    
    if junction_type == "" then
        error("Junction: type cannot be empty string.")
    end
    
    if not vector.check(pos_min) then
        error("Junction: pos_min '" .. dump_value(pos_min) ..
            "' is not a vector.")
    end
    
    if not vector.check(pos_max) then
        error("Junction: pos_max '" .. dump_value(pos_max) ..
            "' is not a vector.")
    end
    
    if type(face) ~= "string" then
        error("Junction: face '" .. dump_value(face) ..
            "' is not a string.")
    end
    
    if not VALID_FACES[face] then
        error("Junction: invalid face name '" .. face ..
            "'. Must be one of: y+, y-, z-, z+, x+, x-.")
    end
    
    -- Validate positions are on the face
    check_positions_on_face(pos_min, pos_max, face)
end

-- Validates that the object is a junction
function checks.check_junction(obj)
    if not pcmg.junction.check(obj) then
        error("Junction: object '" .. dump_value(obj) ..
            "' is not a junction.")
    end
end

return pcmg.junction_checks
