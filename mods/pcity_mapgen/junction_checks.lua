--[[
    This is a part of "Perfect City".
    Copyright (C) 2024-2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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

-- Validation functions for junction class

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local vector = vector
local pcmg = pcity_mapgen

pcmg.junction_checks = pcmg.junction_checks or {}
local checks = pcmg.junction_checks

-- Checks if a vector has only one non-zero component with value 1 or -1
-- Valid direction vectors: (1,0,0), (-1,0,0), (0,1,0), (0,-1,0), (0,0,1), (0,0,-1)
local function is_valid_direction_vector(v)
    if not vector.check(v) then
        return false
    end
    
    local non_zero_count = 0
    local values = {v.x, v.y, v.z}
    
    for _, val in ipairs(values) do
        if val ~= 0 then
            non_zero_count = non_zero_count + 1
            if val ~= 1 and val ~= -1 then
                return false
            end
        end
    end
    
    return non_zero_count == 1
end

-- Checks if a vector is perpendicular to another vector
local function is_perpendicular(v1, v2)
    return vector.dot(v1, v2) == 0
end

-- Validates position argument
local function check_pos_argument(pos)
    if not vector.check(pos) then
        error("Junction: pos '"..shallow_dump(pos).."' is not a vector.")
    end
end

-- Validates direction argument
local function check_direction_argument(direction)
    if not vector.check(direction) then
        error("Junction: direction '"..shallow_dump(direction).."' is not a vector.")
    end
    
    if not is_valid_direction_vector(direction) then
        error("Junction: direction '"..shallow_dump(direction)..
              "' is not a valid direction vector. "..
              "Direction must be a unit vector along one axis: "..
              "(±1,0,0), (0,±1,0), or (0,0,±1).")
    end
end

-- Validates size argument
local function check_size_argument(size, direction)
    if not vector.check(size) then
        error("Junction: size '"..shallow_dump(size).."' is not a vector.")
    end
    
    if not is_perpendicular(direction, size) then
        error("Junction: size vector '"..shallow_dump(size)..
              "' is not perpendicular to direction vector '"..
              shallow_dump(direction).."'.")
    end
end

-- Validates type argument
local function check_type_argument(jtype)
    if type(jtype) ~= "string" then
        error("Junction: type '"..tostring(jtype).."' is not a string.")
    end
    
    if jtype == "" then
        error("Junction: type cannot be an empty string.")
    end
end

-- Validates arguments for junction.new
function checks.check_junction_new_arguments(pos, direction, size, jtype)
    check_pos_argument(pos)
    check_direction_argument(direction)
    check_size_argument(size, direction)
    check_type_argument(jtype)
end

-- Checks if the object is a junction
function checks.check_junction(j)
    local junction = pcmg.junction
    if not junction then
        error("Junction module not loaded.")
    end
    if not junction.check(j) then
        error("Junction: j '"..shallow_dump(j).."' is not a junction.")
    end
end

return pcmg.junction_checks
