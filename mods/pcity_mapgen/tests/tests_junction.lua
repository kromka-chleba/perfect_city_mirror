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

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local vector = vector
local pcmg = pcity_mapgen
local junction = pcmg.junction or dofile(mod_path.."/junction.lua")

pcmg.tests = pcmg.tests or {}
pcmg.tests.junction = {}
local tests = pcmg.tests.junction

-- ============================================================
-- JUNCTION CLASS UNIT TESTS
-- ============================================================

-- Tests that junction.new creates a junction with correct properties
function tests.test_junction_new()
    local pos = vector.new(5, 10, 15)
    local direction = vector.new(1, 0, 0)
    local size = vector.new(0, 3, 4)
    local jtype = "corridor"
    
    local j = junction.new(pos, direction, size, jtype)
    
    assert(vector.equals(j.pos, pos), "Junction pos should match input")
    assert(vector.equals(j.direction, direction), "Junction direction should match input")
    assert(vector.equals(j.size, size), "Junction size should match input")
    assert(j.type == jtype, "Junction type should match input")
end

-- Tests that junction.check correctly identifies junction objects
function tests.test_junction_check()
    local j = junction.new(
        vector.new(0, 0, 0),
        vector.new(1, 0, 0),
        vector.new(0, 2, 3),
        "staircase"
    )
    
    assert(junction.check(j) == true, "junction.check should return true for a junction")
    assert(junction.check({}) == false, "junction.check should return false for a table")
    assert(junction.check("string") == false, "junction.check should return false for a string")
    assert(junction.check(nil) == false, "junction.check should return false for nil")
end

-- Tests junction creation with different valid direction vectors
function tests.test_junction_valid_directions()
    local pos = vector.new(0, 0, 0)
    local size = vector.new(0, 2, 3)
    
    -- Test all six valid direction vectors
    local directions = {
        vector.new(1, 0, 0),
        vector.new(-1, 0, 0),
        vector.new(0, 1, 0),
        vector.new(0, -1, 0),
        vector.new(0, 0, 1),
        vector.new(0, 0, -1)
    }
    
    for _, dir in ipairs(directions) do
        local perpendicular_size
        if dir.x ~= 0 then
            perpendicular_size = vector.new(0, 2, 3)
        elseif dir.y ~= 0 then
            perpendicular_size = vector.new(2, 0, 3)
        else
            perpendicular_size = vector.new(2, 3, 0)
        end
        
        local j = junction.new(pos, dir, perpendicular_size, "test")
        assert(junction.check(j), "Should create junction with direction "..dump(dir))
    end
end

-- Tests that invalid direction vectors are rejected
function tests.test_junction_invalid_direction()
    local pos = vector.new(0, 0, 0)
    local size = vector.new(0, 2, 3)
    
    -- Test invalid direction vectors
    local invalid_directions = {
        vector.new(0, 0, 0),  -- zero vector
        vector.new(1, 1, 0),  -- diagonal
        vector.new(2, 0, 0),  -- not unit length
        vector.new(1, 0, 1),  -- multiple non-zero components
    }
    
    for _, dir in ipairs(invalid_directions) do
        local ok, err = pcall(function()
            junction.new(pos, dir, size, "test")
        end)
        assert(not ok, "Should reject invalid direction vector "..dump(dir))
    end
end

-- Tests that size must be perpendicular to direction
function tests.test_junction_size_perpendicularity()
    local pos = vector.new(0, 0, 0)
    local direction = vector.new(1, 0, 0)
    
    -- Valid perpendicular size (no x component)
    local valid_size = vector.new(0, 2, 3)
    local j = junction.new(pos, direction, valid_size, "test")
    assert(junction.check(j), "Should accept perpendicular size")
    
    -- Invalid non-perpendicular size (has x component)
    local invalid_size = vector.new(1, 2, 3)
    local ok, err = pcall(function()
        junction.new(pos, direction, invalid_size, "test")
    end)
    assert(not ok, "Should reject non-perpendicular size")
end

-- Tests that type must be a non-empty string
function tests.test_junction_type_validation()
    local pos = vector.new(0, 0, 0)
    local direction = vector.new(1, 0, 0)
    local size = vector.new(0, 2, 3)
    
    -- Valid type
    local j = junction.new(pos, direction, size, "corridor")
    assert(j.type == "corridor", "Should accept valid type string")
    
    -- Empty string should be rejected
    local ok, err = pcall(function()
        junction.new(pos, direction, size, "")
    end)
    assert(not ok, "Should reject empty string type")
    
    -- Non-string should be rejected
    ok, err = pcall(function()
        junction.new(pos, direction, size, 123)
    end)
    assert(not ok, "Should reject non-string type")
end

-- Tests get_opposite_corner method
function tests.test_junction_get_opposite_corner()
    local pos = vector.new(5, 10, 15)
    local direction = vector.new(1, 0, 0)
    local size = vector.new(0, 3, 4)
    
    local j = junction.new(pos, direction, size, "corridor")
    local corner = j:get_opposite_corner()
    
    local expected = vector.new(5, 13, 19)
    assert(vector.equals(corner, expected), 
           "Opposite corner should be pos + size")
end

-- Tests can_connect method with compatible junctions
function tests.test_junction_can_connect_compatible()
    -- Create two junctions facing each other
    local j1 = junction.new(
        vector.new(0, 0, 0),
        vector.new(1, 0, 0),  -- facing +x
        vector.new(0, 2, 3),
        "corridor"
    )
    
    local j2 = junction.new(
        vector.new(10, 0, 0),
        vector.new(-1, 0, 0),  -- facing -x (opposite)
        vector.new(0, 2, 3),
        "corridor"
    )
    
    assert(j1:can_connect(j2), "Compatible junctions should be able to connect")
    assert(j2:can_connect(j1), "Connection should be symmetric")
end

-- Tests can_connect method with incompatible directions
function tests.test_junction_can_connect_wrong_direction()
    -- Create two junctions not facing each other
    local j1 = junction.new(
        vector.new(0, 0, 0),
        vector.new(1, 0, 0),  -- facing +x
        vector.new(0, 2, 3),
        "corridor"
    )
    
    local j2 = junction.new(
        vector.new(10, 0, 0),
        vector.new(1, 0, 0),  -- also facing +x (same direction)
        vector.new(0, 2, 3),
        "corridor"
    )
    
    assert(not j1:can_connect(j2), 
           "Junctions with non-opposite directions should not connect")
end

-- Tests can_connect method with incompatible types
function tests.test_junction_can_connect_wrong_type()
    -- Create two junctions with different types
    local j1 = junction.new(
        vector.new(0, 0, 0),
        vector.new(1, 0, 0),
        vector.new(0, 2, 3),
        "corridor"
    )
    
    local j2 = junction.new(
        vector.new(10, 0, 0),
        vector.new(-1, 0, 0),
        vector.new(0, 2, 3),
        "staircase"  -- different type
    )
    
    assert(not j1:can_connect(j2), 
           "Junctions with different types should not connect")
end

-- Tests junction:copy method
function tests.test_junction_copy()
    local j1 = junction.new(
        vector.new(5, 10, 15),
        vector.new(1, 0, 0),
        vector.new(0, 3, 4),
        "corridor"
    )
    
    local j2 = j1:copy()
    
    assert(junction.check(j2), "Copy should be a valid junction")
    assert(vector.equals(j2.pos, j1.pos), "Copy should have same position")
    assert(vector.equals(j2.direction, j1.direction), 
           "Copy should have same direction")
    assert(vector.equals(j2.size, j1.size), "Copy should have same size")
    assert(j2.type == j1.type, "Copy should have same type")
    
    -- Modify copy and ensure original is unchanged
    j2.pos.x = 100
    assert(j1.pos.x ~= 100, "Modifying copy should not affect original")
end

-- Tests junction.equals method
function tests.test_junction_equals()
    local j1 = junction.new(
        vector.new(5, 10, 15),
        vector.new(1, 0, 0),
        vector.new(0, 3, 4),
        "corridor"
    )
    
    local j2 = junction.new(
        vector.new(5, 10, 15),
        vector.new(1, 0, 0),
        vector.new(0, 3, 4),
        "corridor"
    )
    
    assert(junction.equals(j1, j2), "Identical junctions should be equal")
    
    -- Test with different properties
    local j3 = junction.new(
        vector.new(5, 10, 15),
        vector.new(-1, 0, 0),  -- different direction
        vector.new(0, 3, 4),
        "corridor"
    )
    
    assert(not junction.equals(j1, j3), 
           "Junctions with different directions should not be equal")
end

-- ============================================================
-- REGISTER ALL TESTS
-- ============================================================

pcmg.register_test("Junction Tests")
pcmg.register_test("test_junction_new", tests.test_junction_new)
pcmg.register_test("test_junction_check", tests.test_junction_check)
pcmg.register_test("test_junction_valid_directions", tests.test_junction_valid_directions)
pcmg.register_test("test_junction_invalid_direction", tests.test_junction_invalid_direction)
pcmg.register_test("test_junction_size_perpendicularity", tests.test_junction_size_perpendicularity)
pcmg.register_test("test_junction_type_validation", tests.test_junction_type_validation)
pcmg.register_test("test_junction_get_opposite_corner", tests.test_junction_get_opposite_corner)
pcmg.register_test("test_junction_can_connect_compatible", tests.test_junction_can_connect_compatible)
pcmg.register_test("test_junction_can_connect_wrong_direction", tests.test_junction_can_connect_wrong_direction)
pcmg.register_test("test_junction_can_connect_wrong_type", tests.test_junction_can_connect_wrong_type)
pcmg.register_test("test_junction_copy", tests.test_junction_copy)
pcmg.register_test("test_junction_equals", tests.test_junction_equals)
