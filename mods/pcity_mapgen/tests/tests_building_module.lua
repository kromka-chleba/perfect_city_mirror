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

local building_module = pcmg.building_module or
    dofile(mod_path.."/building_module.lua")

pcmg.tests = pcmg.tests or {}
pcmg.tests.building_module = {}
local tests = pcmg.tests.building_module

-- ============================================================
-- BUILDING MODULE UNIT TESTS
-- ============================================================

-- Tests that building_module.new creates a module correctly
function tests.test_building_module_new()
    local min_pos = vector.new(0, 0, 0)
    local max_pos = vector.new(10, 20, 10)
    local m = building_module.new(min_pos, max_pos)
    
    assert(m.id ~= nil, "Module should have an ID")
    assert(vector.equals(m.min_pos, min_pos),
        "Module min_pos should match input")
    assert(vector.equals(m.max_pos, max_pos),
        "Module max_pos should match input")
    
    -- Test that IDs are unique
    local m2 = building_module.new(vector.new(0, 0, 0),
        vector.new(5, 5, 5))
    assert(m2.id ~= m.id, "Modules should have unique IDs")
end

-- Tests that building_module.check identifies modules
function tests.test_building_module_check()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(5, 5, 5))
    
    assert(building_module.check(m) == true,
        "check should return true for a module")
    assert(building_module.check({}) == false,
        "check should return false for a table")
    assert(building_module.check(nil) == false,
        "check should return false for nil")
end

-- Tests get_size method
function tests.test_get_size()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(9, 19, 9))
    local size = m:get_size()
    
    assert(size.x == 10, "Size X should be 10")
    assert(size.y == 20, "Size Y should be 20")
    assert(size.z == 10, "Size Z should be 10")
end

-- Tests get_center method
function tests.test_get_center()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(10, 20, 10))
    local center = m:get_center()
    
    assert(center.x == 5, "Center X should be 5")
    assert(center.y == 10, "Center Y should be 10")
    assert(center.z == 5, "Center Z should be 5")
end

-- Tests junction surface management
function tests.test_junction_surfaces()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(5, 5, 5))
    
    -- Set junction surfaces
    m:set_junction_surface("y+", "surface_a")
    m:set_junction_surface("y-", "surface_b")
    m:set_junction_surface("z-", "surface_c")
    
    -- Get junction surfaces
    assert(m:get_junction_surface("y+") == "surface_a",
        "Y+ surface should be surface_a")
    assert(m:get_junction_surface("y-") == "surface_b",
        "Y- surface should be surface_b")
    assert(m:get_junction_surface("z-") == "surface_c",
        "Z- surface should be surface_c")
    assert(m:get_junction_surface("z+") == nil,
        "Z+ surface should be nil")
    
    -- Remove junction surface
    m:remove_junction_surface("y+")
    assert(m:get_junction_surface("y+") == nil,
        "Y+ surface should be nil after removal")
end

-- Tests module connection compatibility
function tests.test_can_connect()
    local m1 = building_module.new(vector.new(0, 0, 0),
        vector.new(5, 5, 5))
    local m2 = building_module.new(vector.new(0, 6, 0),
        vector.new(5, 11, 5))
    
    m1:set_junction_surface("y+", "connector_type_1")
    m2:set_junction_surface("y-", "connector_type_1")
    
    assert(m1:can_connect(m2, "y+", "y-") == true,
        "Modules with matching surfaces should be connectable")
    
    m2:set_junction_surface("y-", "connector_type_2")
    assert(m1:can_connect(m2, "y+", "y-") == false,
        "Modules with different surfaces should not be connectable")
    
    m2:remove_junction_surface("y-")
    assert(m1:can_connect(m2, "y+", "y-") == false,
        "Modules with missing surfaces should not be connectable")
end

-- Tests schematic management
function tests.test_schematic_management()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(5, 5, 5))
    
    local schematic1 = {size = {x = 5, y = 5, z = 5}, data = {}}
    local schematic2 = {size = {x = 3, y = 3, z = 3}, data = {}}
    
    local pos1 = vector.new(0, 0, 0)
    local pos2 = vector.new(1, 1, 1)
    
    -- Add schematics with positions
    m:add_schematic(schematic1, pos1)
    m:add_schematic(schematic2, pos2, "variant_a")
    
    -- Get schematic entries
    local entry1 = m:get_schematic(1)
    assert(entry1 ~= nil, "Should get schematic entry by numeric index")
    assert(entry1.schematic == schematic1,
        "Schematic entry should contain correct schematic")
    assert(vector.equals(entry1.relative_pos, pos1),
        "Schematic entry should have correct position")
    
    local entry2 = m:get_schematic("variant_a")
    assert(entry2 ~= nil, "Should get schematic entry by name")
    assert(entry2.schematic == schematic2,
        "Named schematic entry should contain correct schematic")
    assert(vector.equals(entry2.relative_pos, pos2),
        "Named schematic entry should have correct position")
    
    -- Get all schematics
    local all = m:get_all_schematics()
    assert(all[1] ~= nil, "All schematics should include index 1")
    assert(all[1].schematic == schematic1,
        "Entry 1 should contain correct schematic")
    assert(vector.equals(all[1].relative_pos, pos1),
        "Entry 1 should have correct position")
    assert(all["variant_a"] ~= nil,
        "All schematics should include named variant")
    assert(all["variant_a"].schematic == schematic2,
        "Named entry should contain correct schematic")
    assert(vector.equals(all["variant_a"].relative_pos, pos2),
        "Named entry should have correct position")
    
    -- Remove schematic
    m:remove_schematic("variant_a")
    assert(m:get_schematic("variant_a") == nil,
        "Removed schematic should be nil")
end

-- Tests Y-axis rotation
function tests.test_rotate_y()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(10, 5, 5))
    
    m:set_junction_surface("z-", "surface_a")
    m:set_junction_surface("x+", "surface_b")
    
    -- Rotate 90 degrees
    m:rotate_y(90)
    
    -- After 90 degree rotation around Y:
    -- Z- becomes X-, X+ becomes Z-
    assert(m:get_junction_surface("x-") == "surface_a",
        "Z- surface should become X- after 90 deg rotation")
    assert(m:get_junction_surface("z-") == "surface_b",
        "X+ surface should become Z- after 90 deg rotation")
end

-- Tests that Y rotation normalizes bounds
function tests.test_rotate_y_normalizes_bounds()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(10, 5, 5))
    
    m:rotate_y(180)
    
    -- After rotation, min_pos should still be min and max_pos max
    assert(m.min_pos.x <= m.max_pos.x,
        "min_pos.x should be <= max_pos.x")
    assert(m.min_pos.y <= m.max_pos.y,
        "min_pos.y should be <= max_pos.y")
    assert(m.min_pos.z <= m.max_pos.z,
        "min_pos.z should be <= max_pos.z")
end

-- Tests arbitrary axis rotation
function tests.test_rotate_axis()
    local m = building_module.new(vector.new(0, 0, 0),
        vector.new(5, 5, 5))
    
    -- Rotate around X axis
    local x_axis = vector.new(1, 0, 0)
    m:rotate_axis(x_axis, 90)
    
    -- After rotation, bounds should still be normalized
    assert(m.min_pos.x <= m.max_pos.x,
        "min_pos.x should be <= max_pos.x")
    assert(m.min_pos.y <= m.max_pos.y,
        "min_pos.y should be <= max_pos.y")
    assert(m.min_pos.z <= m.max_pos.z,
        "min_pos.z should be <= max_pos.z")
end

-- Register all tests
local register_test = pcmg.register_test

register_test("Building Module class")
register_test("building_module.new", tests.test_building_module_new)
register_test("building_module.check", tests.test_building_module_check)
register_test("building_module:get_size", tests.test_get_size)
register_test("building_module:get_center", tests.test_get_center)
register_test("building_module junction surfaces",
    tests.test_junction_surfaces)
register_test("building_module:can_connect", tests.test_can_connect)
register_test("building_module schematic management",
    tests.test_schematic_management)
register_test("building_module:rotate_y", tests.test_rotate_y)
register_test("building_module:rotate_y normalizes bounds",
    tests.test_rotate_y_normalizes_bounds)
register_test("building_module:rotate_axis", tests.test_rotate_axis)

return tests
