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

-- Tests that junction.new creates a junction correctly
function tests.test_junction_new()
    local j = junction.new("corridor",
        vector.new(0, 5, 0),
        vector.new(3, 5, 2),
        "y+")
    
    assert(j.id ~= nil, "Junction should have an ID")
    assert(j.type == "corridor", "Junction type should match")
    assert(vector.equals(j.pos_min, vector.new(0, 5, 0)),
        "Junction pos_min should match")
    assert(vector.equals(j.pos_max, vector.new(3, 5, 2)),
        "Junction pos_max should match")
    assert(j.face == "y+", "Junction face should match")
    
    -- Test that IDs are unique
    local j2 = junction.new("hall",
        vector.new(0, 0, 0),
        vector.new(2, 0, 2),
        "y-")
    assert(j2.id ~= j.id, "Junctions should have unique IDs")
end

-- Tests that junction.check identifies junctions
function tests.test_junction_check()
    local j = junction.new("staircase",
        vector.new(0, 5, 0),
        vector.new(2, 5, 2),
        "y+")
    
    assert(junction.check(j) == true,
        "check should return true for a junction")
    assert(junction.check({}) == false,
        "check should return false for a table")
    assert(junction.check(nil) == false,
        "check should return false for nil")
end

-- Tests that junctions validate positions are on face
function tests.test_junction_validates_face_position()
    -- Valid: Y+ face with constant y coordinate
    local success = pcall(function()
        junction.new("corridor",
            vector.new(0, 5, 0),
            vector.new(3, 5, 2),
            "y+")
    end)
    assert(success, "Should accept positions on correct face")
    
    -- Invalid: Y+ face with different y coordinates
    local success2, err = pcall(function()
        junction.new("corridor",
            vector.new(0, 5, 0),
            vector.new(3, 6, 2),  -- y differs
            "y+")
    end)
    assert(not success2, "Should reject positions not on face")
    assert(string.find(err, "y coordinates differ"),
        "Error should mention coordinate mismatch")
end

-- Tests get_size method
function tests.test_junction_get_size()
    local j = junction.new("corridor",
        vector.new(0, 5, 0),
        vector.new(3, 5, 2),
        "y+")
    local size = j:get_size()
    
    assert(size.x == 4, "Size X should be 4 (0 to 3 inclusive)")
    assert(size.y == 1, "Size Y should be 1 (on face)")
    assert(size.z == 3, "Size Z should be 3 (0 to 2 inclusive)")
end

-- Tests get_center method
function tests.test_junction_get_center()
    local j = junction.new("corridor",
        vector.new(0, 5, 0),
        vector.new(4, 5, 2),
        "y+")
    local center = j:get_center()
    
    assert(center.x == 2, "Center X should be 2")
    assert(center.y == 5, "Center Y should be 5")
    assert(center.z == 1, "Center Z should be 1")
end

-- Tests get_area method
function tests.test_junction_get_area()
    local j = junction.new("corridor",
        vector.new(0, 5, 0),
        vector.new(3, 5, 2),
        "y+")
    local area = j:get_area()
    
    -- 4 * 1 * 3 = 12 voxels
    assert(area == 12, "Area should be 12 voxels")
end

-- Tests can_connect_with for matching junctions
function tests.test_junction_can_connect_matching()
    local j1 = junction.new("corridor",
        vector.new(0, 5, 0),
        vector.new(3, 5, 2),
        "y+")
    local j2 = junction.new("corridor",
        vector.new(0, 0, 0),
        vector.new(3, 0, 2),
        "y-")
    
    assert(j1:can_connect_with(j2) == true,
        "Matching junctions should be connectable")
end

-- Tests can_connect_with for different types
function tests.test_junction_can_connect_different_types()
    local j1 = junction.new("corridor",
        vector.new(0, 5, 0),
        vector.new(3, 5, 2),
        "y+")
    local j2 = junction.new("hall",
        vector.new(0, 0, 0),
        vector.new(3, 0, 2),
        "y-")
    
    assert(j1:can_connect_with(j2) == false,
        "Different junction types should not be connectable")
end

-- Tests can_connect_with for different sizes
function tests.test_junction_can_connect_different_sizes()
    local j1 = junction.new("corridor",
        vector.new(0, 5, 0),
        vector.new(3, 5, 2),
        "y+")
    local j2 = junction.new("corridor",
        vector.new(0, 0, 0),
        vector.new(2, 0, 2),  -- Different X size
        "y-")
    
    assert(j1:can_connect_with(j2) == false,
        "Different sized junctions should not be connectable")
end

-- Tests junctions on different faces
function tests.test_junction_different_faces()
    -- Z- face (constant z)
    local jz = junction.new("corridor",
        vector.new(0, 0, 5),
        vector.new(3, 2, 5),
        "z-")
    assert(jz.face == "z-", "Should create junction on z- face")
    
    -- X+ face (constant x)
    local jx = junction.new("hall",
        vector.new(10, 0, 0),
        vector.new(10, 2, 3),
        "x+")
    assert(jx.face == "x+", "Should create junction on x+ face")
end

-- Register all tests
local register_test = pcmg.register_test

register_test("Junction class")
register_test("junction.new", tests.test_junction_new)
register_test("junction.check", tests.test_junction_check)
register_test("junction validates face position",
    tests.test_junction_validates_face_position)
register_test("junction:get_size", tests.test_junction_get_size)
register_test("junction:get_center", tests.test_junction_get_center)
register_test("junction:get_area", tests.test_junction_get_area)
register_test("junction:can_connect_with matching",
    tests.test_junction_can_connect_matching)
register_test("junction:can_connect_with different types",
    tests.test_junction_can_connect_different_types)
register_test("junction:can_connect_with different sizes",
    tests.test_junction_can_connect_different_sizes)
register_test("junction different faces",
    tests.test_junction_different_faces)

return tests
