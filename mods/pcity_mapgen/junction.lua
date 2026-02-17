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

--[[
    ** Junction Class **
    
    Junctions are objects used for the modular building mapgen system.
    Each building module can define junctions - surfaces where building
    modules can be connected.
    
    A junction represents a rectangular connection surface with:
    - pos: relative position in nodes (vector)
    - direction: normal vector pointing outwards (e.g., (1,0,0), (-1,0,0))
    - size: vector perpendicular to direction, defining the surface size
    - type: string identifier (e.g., "staircase", "corridor")
    
    Two junctions can be connected only if:
    - Their direction vectors sum to zero (opposite facing)
    - They have the same type
--]]

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local vector = vector
local pcmg = pcity_mapgen

pcmg.junction = pcmg.junction or {}
local junction = pcmg.junction
junction.__index = junction

local checks = pcmg.junction_checks or dofile(mod_path.."/junction_checks.lua")

-- Creates a new instance of the Junction class. A junction represents
-- a rectangular connection surface on a building module.
-- 
-- @param pos: relative position in nodes (vector)
-- @param direction: normal vector pointing outwards, must be a unit vector
--                   along one axis: (±1,0,0), (0,±1,0), or (0,0,±1)
-- @param size: vector perpendicular to direction, defines surface dimensions
-- @param jtype: string identifier for junction type (e.g., "staircase", "corridor")
-- @return: new junction object
function junction.new(pos, direction, size, jtype)
    checks.check_junction_new_arguments(pos, direction, size, jtype)
    local j = {}
    j.pos = vector.copy(pos)
    j.direction = vector.copy(direction)
    j.size = vector.copy(size)
    j.type = jtype
    return setmetatable(j, junction)
end

-- Checks if the object is a junction.
-- @param j: object to check
-- @return: true if j is a junction, false otherwise
function junction.check(j)
    return getmetatable(j) == junction
end

-- Returns the second corner position of the junction rectangle.
-- The junction defines a rectangular surface from pos to pos+size.
-- @return: vector representing the opposite corner of the junction
function junction:get_opposite_corner()
    return vector.add(self.pos, self.size)
end

-- Checks if two junctions can be connected.
-- Junctions can be connected if:
-- 1. Their direction vectors sum to zero (opposite facing)
-- 2. They have the same type
-- @param other: another junction object
-- @return: true if junctions can connect, false otherwise
function junction:can_connect(other)
    checks.check_junction(other)
    
    -- Check if direction vectors sum to zero (opposite directions)
    local dir_sum = vector.add(self.direction, other.direction)
    if not vector.equals(dir_sum, vector.new(0, 0, 0)) then
        return false
    end
    
    -- Check if types match
    if self.type ~= other.type then
        return false
    end
    
    return true
end

-- Creates a copy of the junction with the same properties.
-- @return: new junction object with copied properties
function junction:copy()
    return junction.new(self.pos, self.direction, self.size, self.type)
end

-- Checks if two junctions are equal.
-- Junctions are equal if they have the same pos, direction, size, and type.
-- @param j1: first junction
-- @param j2: second junction
-- @return: true if junctions are equal, false otherwise
function junction.equals(j1, j2)
    return vector.equals(j1.pos, j2.pos) and
           vector.equals(j1.direction, j2.direction) and
           vector.equals(j1.size, j2.size) and
           j1.type == j2.type
end

return pcmg.junction
