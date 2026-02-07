--[[
    This is a part of "Perfect City".
    Copyright (C) 2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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
local point = pcmg.point or dofile(mod_path.."/point.lua")
local path = pcmg.path or dofile(mod_path.."/path.lua")

pcmg.tests = pcmg.tests or {}
pcmg.tests.point = {}
local tests = pcmg.tests.point

-- ============================================================
-- POINT CLASS UNIT TESTS
-- ============================================================

-- Tests that point.new creates a point with correct position and unique ID
function tests.test_point_new()
    local pos = vector.new(5, 10, 15)
    local p = point.new(pos)
    
    assert(p.pos.x == 5, "Point x coordinate should be 5")
    assert(p.pos.y == 10, "Point y coordinate should be 10")
    assert(p.pos.z == 15, "Point z coordinate should be 15")
    assert(p.id ~= nil, "Point should have an ID")
    assert(p.path == nil, "New point should not belong to a path")
    assert(p.previous == nil, "New point should have no previous link")
    assert(p.next == nil, "New point should have no next link")
    
    -- Test that IDs are unique
    local p2 = point.new(vector.new(20, 25, 30))
    assert(p2.id ~= p.id, "Points should have unique IDs")
end

-- Tests that point.check correctly identifies point objects
function tests.test_point_check()
    local p = point.new(vector.new(7, 14, 21))
    
    assert(point.check(p) == true, "point.check should return true for a point")
    assert(point.check({}) == false, "point.check should return false for a table")
    assert(point.check("string") == false, "point.check should return false for a string")
    assert(point.check(nil) == false, "point.check should return false for nil")
end

-- Tests that point:copy creates a new point with same position but no links
function tests.test_point_copy()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(30, 40, 50))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(15, 25, 35))
    pth:insert(p_mid)
    
    local p_copy = p_mid:copy()
    
    assert(vector.equals(p_copy.pos, p_mid.pos), "Copy should have same position")
    assert(p_copy.id ~= p_mid.id, "Copy should have different ID")
    assert(p_copy.path == nil, "Copy should not belong to any path")
    assert(p_copy.previous == nil, "Copy should have no previous link")
    assert(p_copy.next == nil, "Copy should have no next link")
end

-- Tests that point.same_path correctly identifies points on the same path
function tests.test_point_same_path()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(30, 35, 40))
    local pth = path.new(p1, p2)
    
    local p3 = point.new(vector.new(15, 20, 25))
    pth:insert(p3)
    
    assert(point.same_path(p1, p2, p3) == true, "All points should be on same path")
    
    -- Create another path
    local p4 = point.new(vector.new(100, 110, 120))
    local p5 = point.new(vector.new(200, 210, 220))
    local pth2 = path.new(p4, p5)
    
    assert(point.same_path(p1, p4) == false, "Points from different paths should return false")
end

-- Tests that point.link correctly links multiple points in order
function tests.test_point_link()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(10, 15, 20))
    local p3 = point.new(vector.new(25, 30, 35))
    local pth = path.new(p1, p3)
    p2:set_path(pth)
    
    point.link(p1, p2, p3)
    
    assert(p1.next == p2, "p1.next should be p2")
    assert(p2.previous == p1, "p2.previous should be p1")
    assert(p2.next == p3, "p2.next should be p3")
    assert(p3.previous == p2, "p3.previous should be p2")
end

-- Tests that point:unlink_from_previous correctly severs the previous link
function tests.test_point_unlink_from_previous()
    local p1 = point.new(vector.new(5, 10, 15))
    local p2 = point.new(vector.new(35, 40, 45))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(20, 25, 30))
    pth:insert(p_mid)
    
    p_mid:unlink_from_previous()
    
    assert(p_mid.previous == nil, "p_mid.previous should be nil after unlink")
    assert(p1.next == nil, "p1.next should be nil after unlink")
end

-- Tests that point:unlink_from_next correctly severs the next link
function tests.test_point_unlink_from_next()
    local p1 = point.new(vector.new(0, 8, 16))
    local p2 = point.new(vector.new(32, 40, 48))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(16, 24, 32))
    pth:insert(p_mid)
    
    p_mid:unlink_from_next()
    
    assert(p_mid.next == nil, "p_mid.next should be nil after unlink")
    assert(p2.previous == nil, "p2.previous should be nil after unlink")
end

-- Tests that point:unlink correctly severs both previous and next links
function tests.test_point_unlink()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(30, 35, 40))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(15, 20, 25))
    pth:insert(p_mid)
    
    p_mid:unlink()
    
    assert(p_mid.previous == nil, "p_mid.previous should be nil")
    assert(p_mid.next == nil, "p_mid.next should be nil")
    assert(p1.next == nil, "p1.next should be nil")
    assert(p2.previous == nil, "p2.previous should be nil")
end

-- Tests that point:attach shares position between attached points
function tests.test_point_attach()
    local p1 = point.new(vector.new(10, 20, 30))
    local p2 = point.new(vector.new(5, 15, 25))
    local p3 = point.new(vector.new(40, 50, 60))
    
    p1:attach(p2, p3)
    
    -- Attached points should share the same position reference
    assert(p2.pos == p1.pos, "p2 should share position with p1")
    assert(p3.pos == p1.pos, "p3 should share position with p1")
    assert(p1.attached[p2] == p2, "p2 should be in p1's attached table")
    assert(p1.attached[p3] == p3, "p3 should be in p1's attached table")
    assert(p2.attached[p1] == p1, "p1 should be in p2's attached table")
end

-- Tests that point:detach removes attachment relationship
function tests.test_point_detach()
    local p1 = point.new(vector.new(15, 25, 35))
    local p2 = point.new(vector.new(5, 10, 15))
    local p3 = point.new(vector.new(45, 55, 65))
    
    p1:attach(p2, p3)
    p1:detach(p2)
    
    assert(p1.attached[p2] == nil, "p2 should be removed from p1's attached table")
    assert(p2.attached[p1] == nil, "p1 should be removed from p2's attached table")
    assert(p1.attached[p3] == p3, "p3 should still be attached to p1")
end

-- Tests that point:detach_all removes all attachments
function tests.test_point_detach_all()
    local p1 = point.new(vector.new(20, 30, 40))
    local p2 = point.new(vector.new(5, 10, 15))
    local p3 = point.new(vector.new(50, 60, 70))
    
    p1:attach(p2, p3)
    p1:detach_all()
    
    assert(next(p1.attached) == nil, "p1's attached table should be empty")
    assert(p2.attached[p1] == nil, "p1 should be removed from p2's attached table")
    assert(p3.attached[p1] == nil, "p1 should be removed from p3's attached table")
end

-- Tests that point:set_position updates position for all attached points
function tests.test_point_set_position()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(50, 60, 70))
    
    p1:attach(p2)
    p1:set_position(vector.new(100, 200, 300))
    
    assert(p1.pos.x == 100, "p1.x should be 100")
    assert(p1.pos.y == 200, "p1.y should be 200")
    assert(p1.pos.z == 300, "p1.z should be 300")
    assert(p2.pos == p1.pos, "p2 should share the updated position")
end

-- Tests that point.equals correctly compares points by position and ID
function tests.test_point_equals()
    local p1 = point.new(vector.new(10, 20, 30))
    local p2 = point.new(vector.new(10, 20, 30))
    local p3 = point.new(vector.new(15, 25, 35))
    
    -- Same point should equal itself
    assert(point.equals(p1, p1) == true, "Point should equal itself")
    
    -- Different points with same position should not be equal (different IDs)
    assert(point.equals(p1, p2) == false, "Points with same pos but different ID should not be equal")
    
    -- Different positions should not be equal
    assert(point.equals(p1, p3) == false, "Points with different positions should not be equal")
end

-- Tests that point.comparator provides deterministic ordering
function tests.test_point_comparator()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(5, 0, 0))
    local p3 = point.new(vector.new(0, 5, 0))
    local p4 = point.new(vector.new(0, 0, 5))
    
    -- Compare by x first
    assert(point.comparator(p1, p2) == true, "p1 should come before p2 (x comparison)")
    
    -- Compare by y when x is equal
    assert(point.comparator(p1, p3) == true, "p1 should come before p3 (y comparison)")
    
    -- Compare by z when x and y are equal
    assert(point.comparator(p1, p4) == true, "p1 should come before p4 (z comparison)")
    
    -- Same position, compare by ID
    local p5 = point.new(vector.new(0, 0, 0))
    assert(point.comparator(p1, p5) == true, "p1 should come before p5 (ID comparison)")
end

-- Tests that point.sort returns points in deterministic order
function tests.test_point_sort()
    local p3 = point.new(vector.new(30, 15, 10))
    local p1 = point.new(vector.new(5, 25, 20))
    local p2 = point.new(vector.new(20, 10, 30))
    
    local points = {p3, p1, p2}
    local sorted = point.sort(points)
    
    assert(sorted[1] == p1, "First point should be p1 (smallest x)")
    assert(sorted[2] == p2, "Second point should be p2")
    assert(sorted[3] == p3, "Third point should be p3 (largest x)")
end

-- Tests that point:attached_sorted returns attached points in order
function tests.test_point_attached_sorted()
    local p1 = point.new(vector.new(25, 25, 25))
    local p2 = point.new(vector.new(10, 15, 20))
    local p3 = point.new(vector.new(40, 45, 50))
    
    p1:attach(p3, p2)  -- attach in reverse order
    
    local sorted = p1:attached_sorted()
    
    -- Should be sorted by position/ID
    assert(#sorted == 2, "Should have 2 attached points")
end

-- Tests that point:branches_sorted returns branches in deterministic order
function tests.test_point_branches_sorted()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(30, 40, 50))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(15, 25, 35))
    pth:insert(p_mid)
    
    -- Create branches with different end positions
    local branch1_end = point.new(vector.new(15, 50, 35))
    local branch2_end = point.new(vector.new(15, 25, 60))
    
    p_mid:branch(branch1_end)
    p_mid:branch(branch2_end)
    
    local sorted = p_mid:branches_sorted()
    
    assert(#sorted == 2, "Should have 2 branches")
end

-- Tests that point:iterator traverses forward through linked points
function tests.test_point_iterator()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(10, 5, 8)))
    pth:insert(point.new(vector.new(20, 10, 15)))
    pth:insert(point.new(vector.new(30, 15, 22)))
    
    local count = 0
    local x_positions = {}
    for i, p in p1:iterator() do
        count = count + 1
        table.insert(x_positions, p.pos.x)
    end
    
    assert(count == 4, "Iterator should visit 4 points after start")
    assert(x_positions[1] == 10, "First visited should be at x=10")
    assert(x_positions[2] == 20, "Second visited should be at x=20")
    assert(x_positions[3] == 30, "Third visited should be at x=30")
    assert(x_positions[4] == 40, "Fourth visited should be at x=40 (finish)")
end

-- Tests that point:reverse_iterator traverses backward through linked points
function tests.test_point_reverse_iterator()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(10, 5, 8)))
    pth:insert(point.new(vector.new(20, 10, 15)))
    pth:insert(point.new(vector.new(30, 15, 22)))
    
    local count = 0
    local x_positions = {}
    for i, p in p2:reverse_iterator() do
        count = count + 1
        table.insert(x_positions, p.pos.x)
    end
    
    assert(count == 4, "Reverse iterator should visit 4 points before finish")
    assert(x_positions[1] == 30, "First visited should be at x=30")
    assert(x_positions[2] == 20, "Second visited should be at x=20")
    assert(x_positions[3] == 10, "Third visited should be at x=10")
    assert(x_positions[4] == 0, "Fourth visited should be at x=0 (start)")
end

-- Tests that point:set_path correctly assigns point to path
function tests.test_point_set_path()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(30, 35, 40))
    local pth = path.new(p1, p2)
    
    local p3 = point.new(vector.new(15, 20, 25))
    p3:set_path(pth)
    
    assert(p3.path == pth, "Point should be assigned to path")
    assert(pth.points[p3] == p3, "Path should contain point in points table")
end

-- Tests that point:branch creates a new path branching from this point
function tests.test_point_branch()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(30, 40, 50))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(15, 25, 35))
    pth:insert(p_mid)
    
    local branch_end = point.new(vector.new(15, 60, 35))
    local branch = p_mid:branch(branch_end)
    
    assert(path.check(branch), "Branch should be a path")
    assert(branch.finish == branch_end, "Branch finish should be branch_end")
    assert(p_mid.branches[branch] == branch, "Branch should be in point's branches table")
    assert(pth.branching_points[p_mid] == p_mid, "Point should be marked as branching point")
    assert(p_mid.attached[branch.start] == branch.start, "Branch start should be attached to branching point")
end

-- Tests that point:has_branches correctly detects branches
function tests.test_point_has_branches()
    local p1 = point.new(vector.new(5, 15, 25))
    local p2 = point.new(vector.new(35, 45, 55))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(20, 30, 40))
    pth:insert(p_mid)
    
    assert(p_mid:has_branches() == false, "Point should have no branches initially")
    
    local branch_end = point.new(vector.new(20, 60, 40))
    p_mid:branch(branch_end)
    
    assert(p_mid:has_branches() == true, "Point should have branches after branching")
end

-- Tests that point:unbranch removes a specific branch
function tests.test_point_unbranch()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(20, 30, 40))
    pth:insert(p_mid)
    
    local branch1_end = point.new(vector.new(20, 70, 40))
    local branch2_end = point.new(vector.new(20, 30, 80))
    local branch1 = p_mid:branch(branch1_end)
    local branch2 = p_mid:branch(branch2_end)
    
    p_mid:unbranch(branch1)
    
    assert(p_mid.branches[branch1] == nil, "Branch1 should be removed")
    assert(p_mid.branches[branch2] == branch2, "Branch2 should still exist")
    assert(pth.branching_points[p_mid] == p_mid, "Point should still be a branching point")
    
    p_mid:unbranch(branch2)
    assert(pth.branching_points[p_mid] == nil, "Point should no longer be a branching point")
end

-- Tests that point:unbranch_all removes all branches
function tests.test_point_unbranch_all()
    local p1 = point.new(vector.new(5, 15, 25))
    local p2 = point.new(vector.new(45, 55, 65))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(25, 35, 45))
    pth:insert(p_mid)
    
    local branch1_end = point.new(vector.new(25, 80, 45))
    local branch2_end = point.new(vector.new(25, 35, 90))
    p_mid:branch(branch1_end)
    p_mid:branch(branch2_end)
    
    p_mid:unbranch_all()
    
    assert(next(p_mid.branches) == nil, "All branches should be removed")
    assert(pth.branching_points[p_mid] == nil, "Point should no longer be a branching point")
end

-- Tests that point:clear removes all links, attachments, and branches
function tests.test_point_clear()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    local p_mid = point.new(vector.new(20, 30, 40))
    pth:insert(p_mid)
    
    local p_attached = point.new(vector.new(20, 30, 40))
    p_mid:attach(p_attached)
    
    local branch_end = point.new(vector.new(20, 70, 40))
    p_mid:branch(branch_end)
    
    p_mid:clear()
    
    assert(p_mid.previous == nil, "previous should be nil after clear")
    assert(p_mid.next == nil, "next should be nil after clear")
    assert(next(p_mid.attached) == nil, "attached should be empty after clear")
    assert(next(p_mid.branches) == nil, "branches should be empty after clear")
    assert(p_mid.path == nil, "path should be nil after clear")
end

-- Register all tests
local register_test = pcmg.register_test

register_test("Point class")
register_test("point.new", tests.test_point_new)
register_test("point.check", tests.test_point_check)
register_test("point:copy", tests.test_point_copy)
register_test("point.same_path", tests.test_point_same_path)
register_test("point.link", tests.test_point_link)
register_test("point:unlink_from_previous", tests.test_point_unlink_from_previous)
register_test("point:unlink_from_next", tests.test_point_unlink_from_next)
register_test("point:unlink", tests.test_point_unlink)
register_test("point:attach", tests.test_point_attach)
register_test("point:detach", tests.test_point_detach)
register_test("point:detach_all", tests.test_point_detach_all)
register_test("point:set_position", tests.test_point_set_position)
register_test("point.equals", tests.test_point_equals)
register_test("point.comparator", tests.test_point_comparator)
register_test("point.sort", tests.test_point_sort)
register_test("point:attached_sorted", tests.test_point_attached_sorted)
register_test("point:branches_sorted", tests.test_point_branches_sorted)
register_test("point:iterator", tests.test_point_iterator)
register_test("point:reverse_iterator", tests.test_point_reverse_iterator)
register_test("point:set_path", tests.test_point_set_path)
register_test("point:branch", tests.test_point_branch)
register_test("point:has_branches", tests.test_point_has_branches)
register_test("point:unbranch", tests.test_point_unbranch)
register_test("point:unbranch_all", tests.test_point_unbranch_all)
register_test("point:clear", tests.test_point_clear)
