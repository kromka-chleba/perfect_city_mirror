--[[
    This is a part of "Perfect City".
    Copyright (C) 2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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
local math = math
local vector = vector
local pcmg = pcity_mapgen
local canvas3d = pcmg.canvas3d
local megacanvas3d = pcmg.megacanvas3d

pcmg.tests = pcmg.tests or {}
pcmg.tests.canvas3d = {}
local tests = pcmg.tests.canvas3d

-- ============================================================
-- CANVAS3D CLASS UNIT TESTS
-- ============================================================

-- Tests that canvas3d.new creates a canvas3d with correct structure
function tests.test_canvas3d_new()
    local origin = vector.new(0, 0, 0)
    local canv = canvas3d.new(origin)
    
    assert(canv.origin ~= nil, "Canvas3D should have an origin")
    assert(vector.equals(canv.origin, origin), "Canvas3D origin should match input")
    assert(canv.array ~= nil, "Canvas3D should have an array")
    assert(canv.cursor ~= nil, "Canvas3D should have a cursor")
    assert(canv.cursor_inside == true, "Cursor should start inside")
    assert(canv.metastore ~= nil, "Canvas3D should have a metastore")
end

-- Tests that canvas3d:set_cursor updates cursor position and inside status
function tests.test_canvas3d_set_cursor()
    local origin = vector.new(0, 0, 0)
    local canv = canvas3d.new(origin)
    
    local pos = vector.new(10, 5, 15)
    canv:set_cursor(pos)
    
    assert(vector.equals(canv.cursor, pos), "Cursor should be at set position")
    assert(canv.cursor_inside == true, "Cursor should be inside for valid position")
    
    -- Test cursor outside bounds
    local far_pos = vector.new(10000, 10000, 10000)
    canv:set_cursor(far_pos)
    assert(canv.cursor_inside == false, "Cursor should be outside for far position")
end

-- Tests that canvas3d:read_cell and write_cell work in 3D
function tests.test_canvas3d_read_write_cell()
    local origin = vector.new(0, 0, 0)
    local canv = canvas3d.new(origin)
    
    local x, y, z = 10, 5, 15
    local material_id = 2  -- Assuming 2 is a valid material ID
    
    -- Read before write should return blank_id (1)
    local initial = canv:read_cell(x, y, z)
    assert(initial == 1, "Initial cell should be blank")
    
    -- Write to cell
    canv:write_cell(x, y, z, material_id)
    
    -- Read after write should return material_id
    local after_write = canv:read_cell(x, y, z)
    assert(after_write == material_id, "Cell should contain written material")
end

-- Tests that canvas3d:move_cursor updates cursor position
function tests.test_canvas3d_move_cursor()
    local origin = vector.new(0, 0, 0)
    local canv = canvas3d.new(origin)
    
    local initial_pos = vector.new(10, 5, 15)
    canv:set_cursor(initial_pos)
    
    local move = vector.new(5, 3, -2)
    canv:move_cursor(move)
    
    local expected = initial_pos + move
    assert(vector.equals(canv.cursor, expected), "Cursor should move by vector")
end

-- Tests that canvas3d:draw_box creates a 3D box
function tests.test_canvas3d_draw_box()
    local origin = vector.new(0, 0, 0)
    local canv = canvas3d.new(origin)
    
    local cursor_pos = vector.new(20, 10, 20)
    canv:set_cursor(cursor_pos)
    
    local material_id = 2
    canv:draw_box(3, 3, 3, material_id, false)
    
    -- Check that cells in the box are filled
    for x = 0, 2 do
        for y = 0, 2 do
            for z = 0, 2 do
                local cell_pos = cursor_pos + vector.new(x, y, z)
                local cell_val = canv:read_cell(cell_pos.x, cell_pos.y, cell_pos.z)
                assert(cell_val == material_id, "Cell in box should be filled with material")
            end
        end
    end
end

-- Tests that canvas3d:draw_rectangle works at a specific y level
function tests.test_canvas3d_draw_rectangle()
    local origin = vector.new(0, 0, 0)
    local canv = canvas3d.new(origin)
    
    local cursor_pos = vector.new(20, 10, 20)
    canv:set_cursor(cursor_pos)
    
    local material_id = 3
    canv:draw_rectangle(5, 5, material_id, false)
    
    -- Check that cells in the rectangle at y=10 are filled
    for x = 0, 4 do
        for z = 0, 4 do
            local cell_val = canv:read_cell(cursor_pos.x + x, cursor_pos.y, cursor_pos.z + z)
            assert(cell_val == material_id, "Cell in rectangle should be filled")
        end
    end
    
    -- Check that cells at different y are not affected
    local cell_above = canv:read_cell(cursor_pos.x, cursor_pos.y + 1, cursor_pos.z)
    assert(cell_above == 1, "Cell above rectangle should remain blank")
end

-- Tests that megacanvas3d.new creates a megacanvas3d with neighbors
function tests.test_megacanvas3d_new()
    local cache = megacanvas3d.cache.new()
    local origin = vector.new(0, 0, 0)
    local megacanv = megacanvas3d.new(origin, cache)
    
    assert(megacanv.origin ~= nil, "Megacanvas3D should have an origin")
    assert(megacanv.central ~= nil, "Megacanvas3D should have a central canvas")
    assert(megacanv.neighbors ~= nil, "Megacanvas3D should have neighbors")
    assert(#megacanv.neighbors > 0, "Megacanvas3D should have at least one neighbor")
    assert(megacanv.cursor ~= nil, "Megacanvas3D should have a cursor")
end

-- Tests that megacanvas3d:set_all_cursors updates all canvas cursors
function tests.test_megacanvas3d_set_all_cursors()
    local cache = megacanvas3d.cache.new()
    local origin = vector.new(0, 0, 0)
    local megacanv = megacanvas3d.new(origin, cache)
    
    local pos = vector.new(100, 50, 100)
    megacanv:set_all_cursors(pos)
    
    assert(vector.equals(megacanv.cursor, pos), "Megacanvas cursor should be at set position")
end

-- Tests that megacanvas3d caching works correctly
function tests.test_megacanvas3d_caching()
    local cache = megacanvas3d.cache.new()
    local origin = vector.new(0, 0, 0)
    local megacanv = megacanvas3d.new(origin, cache)
    
    -- Mark as partially complete
    megacanv:mark_partially_complete()
    local hash = pcmg.citychunk_hash(origin)
    assert(cache.partially_complete[hash] == true, "Should be marked as partially complete")
    
    -- Mark as complete
    megacanv:mark_complete()
    assert(cache.complete[hash] == true, "Should be marked as complete")
    assert(cache.partially_complete[hash] == nil, "Should not be partially complete anymore")
end

-- Register all tests
local register_test = pcmg.register_test

register_test("Canvas3D class")
register_test("canvas3d.new", tests.test_canvas3d_new)
register_test("canvas3d:set_cursor", tests.test_canvas3d_set_cursor)
register_test("canvas3d:read_cell and write_cell", tests.test_canvas3d_read_write_cell)
register_test("canvas3d:move_cursor", tests.test_canvas3d_move_cursor)
register_test("canvas3d:draw_box", tests.test_canvas3d_draw_box)
register_test("canvas3d:draw_rectangle", tests.test_canvas3d_draw_rectangle)

register_test("Megacanvas3D class")
register_test("megacanvas3d.new", tests.test_megacanvas3d_new)
register_test("megacanvas3d:set_all_cursors", tests.test_megacanvas3d_set_all_cursors)
register_test("megacanvas3d:caching", tests.test_megacanvas3d_caching)
