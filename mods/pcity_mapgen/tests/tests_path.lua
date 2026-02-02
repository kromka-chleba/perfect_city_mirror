--[[
    This is a part of "Perfect City".
    Copyright (C) 2026 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")
local math = math
local vector = vector
local pcmg = pcity_mapgen
local point = pcmg.point or dofile(mod_path.."/point.lua")
local path = pcmg.path or dofile(mod_path.."/path.lua")

-- ============================================================
-- UNIT TESTS
-- ============================================================

pcmg.tests.path = {}
local tests = pcmg.tests.path

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

-- ============================================================
-- PATH CLASS UNIT TESTS
-- ============================================================

-- Tests that path.new creates a path with start and finish points
function tests.test_path_new()
    local p1 = point.new(vector.new(5, 10, 15))
    local p2 = point.new(vector.new(25, 30, 35))
    local pth = path.new(p1, p2)
    
    assert(pth.start == p1, "Path start should be p1")
    assert(pth.finish == p2, "Path finish should be p2")
    assert(pth:count_intermediate() == 0, "Initial count_intermediate() should be 0")
    assert(pth:has_intermediate() == false, "Initial has_intermediate() should be false")
    assert(pth.id ~= nil, "Path should have an ID")
    assert(p1.path == pth, "Start point should belong to path")
    assert(p2.path == pth, "Finish point should belong to path")
    assert(p1.next == p2, "Start should link to finish")
    assert(p2.previous == p1, "Finish should link back to start")
end

-- Tests that path.check correctly identifies path objects
function tests.test_path_check()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(20, 25, 30))
    local pth = path.new(p1, p2)
    
    assert(path.check(pth) == true, "path.check should return true for a path")
    assert(path.check({}) == false, "path.check should return false for a table")
    assert(path.check("string") == false, "path.check should return false for a string")
    assert(path.check(nil) == false, "path.check should return false for nil")
end

-- Tests that path.comparator provides deterministic ordering
function tests.test_path_comparator()
    local pth1 = path.new(point.new(vector.new(0, 5, 10)), point.new(vector.new(30, 35, 40)))
    local pth2 = path.new(point.new(vector.new(15, 20, 25)), point.new(vector.new(45, 50, 55)))
    local pth3 = path.new(point.new(vector.new(0, 5, 10)), point.new(vector.new(60, 65, 70)))
    
    -- Compare by start position first
    assert(path.comparator(pth1, pth2) == true, "pth1 should come before pth2 (start comparison)")
    
    -- Same start, compare by finish
    assert(path.comparator(pth1, pth3) == true, "pth1 should come before pth3 (finish comparison)")
end

-- Tests that path.sort returns paths in deterministic order
function tests.test_path_sort()
    local pth3 = path.new(point.new(vector.new(30, 35, 40)), point.new(vector.new(60, 65, 70)))
    local pth1 = path.new(point.new(vector.new(0, 5, 10)), point.new(vector.new(30, 35, 40)))
    local pth2 = path.new(point.new(vector.new(15, 20, 25)), point.new(vector.new(45, 50, 55)))
    
    local paths = {pth3, pth1, pth2}
    local sorted = path.sort(paths)
    
    assert(sorted[1] == pth1, "First path should be pth1 (smallest start x)")
    assert(sorted[2] == pth2, "Second path should be pth2")
    assert(sorted[3] == pth3, "Third path should be pth3 (largest start x)")
end

-- Tests that path:branching_points_sorted returns branching points in path order
function tests.test_path_branching_points_sorted()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    local p_mid1 = point.new(vector.new(12, 6, 9))
    local p_mid2 = point.new(vector.new(28, 14, 21))
    pth:insert(p_mid1)
    pth:insert(p_mid2)
    
    -- Create branches in reverse order
    p_mid2:branch(point.new(vector.new(28, 50, 21)))
    p_mid1:branch(point.new(vector.new(12, 40, 9)))
    
    local sorted = pth:branching_points_sorted()
    
    assert(#sorted == 2, "Should have 2 branching points")
    assert(sorted[1] == p_mid1, "First branching point should be p_mid1")
    assert(sorted[2] == p_mid2, "Second branching point should be p_mid2")
end

-- Tests that path:count_intermediate correctly counts intermediate points
function tests.test_path_count_intermediate()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    assert(pth:count_intermediate() == 0, "Initial count should be 0")
    
    pth:insert(point.new(vector.new(10, 20, 30)))
    assert(pth:count_intermediate() == 1, "Count should be 1 after first insert")
    
    pth:insert(point.new(vector.new(20, 30, 40)))
    assert(pth:count_intermediate() == 2, "Count should be 2 after second insert")
    
    pth:insert(point.new(vector.new(30, 40, 50)))
    assert(pth:count_intermediate() == 3, "Count should be 3 after third insert")
end

-- Tests that path:has_intermediate correctly detects intermediate points
function tests.test_path_has_intermediate()
    local p1 = point.new(vector.new(5, 15, 25))
    local p2 = point.new(vector.new(35, 45, 55))
    local pth = path.new(p1, p2)
    
    assert(pth:has_intermediate() == false, "Should have no intermediates initially")
    
    pth:insert(point.new(vector.new(20, 30, 40)))
    assert(pth:has_intermediate() == true, "Should have intermediates after insert")
end

-- Tests that path:set_start replaces the start point
function tests.test_path_set_start()
    local p1 = point.new(vector.new(10, 20, 30))
    local p2 = point.new(vector.new(50, 60, 70))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(30, 40, 50)))
    
    local new_start = point.new(vector.new(-10, 0, 10))
    pth:set_start(new_start)
    
    assert(pth.start == new_start, "Start should be new_start")
    assert(new_start.path == pth, "New start should belong to path")
    assert(new_start.next.pos.x == 30, "New start should link to first intermediate")
end

-- Tests that path:set_finish replaces the finish point
function tests.test_path_set_finish()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(20, 30, 40)))
    
    local new_finish = point.new(vector.new(60, 70, 80))
    pth:set_finish(new_finish)
    
    assert(pth.finish == new_finish, "Finish should be new_finish")
    assert(new_finish.path == pth, "New finish should belong to path")
    assert(new_finish.previous.pos.x == 20, "New finish should link from last intermediate")
end

-- Tests that path:get_point returns the correct intermediate point by index
function tests.test_path_get_point()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(10, 5, 8))
    local mid2 = point.new(vector.new(20, 10, 15))
    local mid3 = point.new(vector.new(30, 15, 22))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    assert(pth:get_point(1) == mid1, "get_point(1) should return first intermediate")
    assert(pth:get_point(2) == mid2, "get_point(2) should return second intermediate")
    assert(pth:get_point(3) == mid3, "get_point(3) should return third intermediate")
    assert(pth:get_point(0) == nil, "get_point(0) should return nil")
    assert(pth:get_point(4) == nil, "get_point(4) should return nil (out of range)")
end

-- Tests that path:get_points returns intermediate points in a range
function tests.test_path_get_points()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(10, 5, 8))
    local mid2 = point.new(vector.new(20, 10, 15))
    local mid3 = point.new(vector.new(30, 15, 22))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    local points = pth:get_points(mid1, mid3)
    
    assert(#points == 3, "Should return 3 intermediate points")
    assert(points[1] == mid1, "First should be mid1")
    assert(points[2] == mid2, "Second should be mid2")
    assert(points[3] == mid3, "Third should be mid3")
    
    -- Test from start (exclusive)
    points = pth:get_points(p1, mid2)
    assert(#points == 2, "Should return 2 points when starting from start")
    assert(points[1] == mid1, "First should be mid1")
    assert(points[2] == mid2, "Second should be mid2")
end

-- Tests that path:random_intermediate_point returns a valid intermediate point
function tests.test_path_random_intermediate_point()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(30, 35, 40))
    local pth = path.new(p1, p2)
    
    -- No intermediate points
    assert(pth:random_intermediate_point() == nil, "Should return nil with no intermediates")
    
    local mid1 = point.new(vector.new(10, 15, 20))
    local mid2 = point.new(vector.new(20, 25, 30))
    pth:insert(mid1)
    pth:insert(mid2)
    
    local random_point = pth:random_intermediate_point()
    assert(random_point == mid1 or random_point == mid2, "Should return one of the intermediate points")
    assert(random_point ~= p1 and random_point ~= p2, "Should not return start or finish")
end

-- Tests that path:point_in_path correctly checks if point belongs to path
function tests.test_path_point_in_path()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(20, 30, 40))
    pth:insert(mid)
    
    local outside = point.new(vector.new(100, 200, 300))
    
    assert(pth:point_in_path(p1) == true, "Start should be in path")
    assert(pth:point_in_path(p2) == true, "Finish should be in path")
    assert(pth:point_in_path(mid) == true, "Intermediate should be in path")
    assert(pth:point_in_path(outside) == false, "Outside point should not be in path")
end

-- Tests that path:insert_between inserts a point between two adjacent points
function tests.test_path_insert_between()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(30, 35, 40))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(15, 20, 25))
    pth:insert_between(p1, p2, mid)
    
    assert(pth:count_intermediate() == 1, "Should have 1 intermediate point")
    assert(p1.next == mid, "p1.next should be mid")
    assert(mid.previous == p1, "mid.previous should be p1")
    assert(mid.next == p2, "mid.next should be p2")
    assert(p2.previous == mid, "p2.previous should be mid")
end

-- Tests that path:insert_at inserts a point at a specific ordinal position
function tests.test_path_insert_at()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(12, 6, 9)))
    pth:insert(point.new(vector.new(28, 14, 21)))
    
    local mid = point.new(vector.new(20, 10, 15))
    pth:insert_at(2, mid)
    
    assert(pth:count_intermediate() == 3, "Should have 3 intermediate points")
    assert(pth:get_point(2) == mid, "Point at position 2 should be mid")
end

-- Tests that path:insert_before inserts a point before target
function tests.test_path_insert_before()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(40, 45, 50))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(25, 30, 35))
    pth:insert(mid1)
    
    local mid2 = point.new(vector.new(12, 17, 22))
    pth:insert_before(mid1, mid2)
    
    assert(pth:count_intermediate() == 2, "Should have 2 intermediate points")
    assert(mid2.next == mid1, "mid2.next should be mid1")
    assert(mid1.previous == mid2, "mid1.previous should be mid2")
end

-- Tests that path:insert_after inserts a point after target
function tests.test_path_insert_after()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(15, 25, 35))
    pth:insert(mid1)
    
    local mid2 = point.new(vector.new(28, 38, 48))
    pth:insert_after(mid1, mid2)
    
    assert(pth:count_intermediate() == 2, "Should have 2 intermediate points")
    assert(mid1.next == mid2, "mid1.next should be mid2")
    assert(mid2.previous == mid1, "mid2.previous should be mid1")
end

-- Tests that path:insert appends a point before finish
function tests.test_path_insert()
    local p1 = point.new(vector.new(5, 15, 25))
    local p2 = point.new(vector.new(35, 45, 55))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(20, 30, 40))
    pth:insert(mid)
    
    assert(pth:count_intermediate() == 1, "Should have 1 intermediate point")
    assert(mid.next == p2, "Inserted point should link to finish")
    assert(p2.previous == mid, "Finish should link back to inserted point")
end

-- Tests that path:remove removes an intermediate point
function tests.test_path_remove()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(12, 6, 9))
    local mid2 = point.new(vector.new(20, 10, 15))
    local mid3 = point.new(vector.new(28, 14, 21))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    pth:remove(mid2)
    
    assert(pth:count_intermediate() == 2, "Should have 2 intermediate points")
    assert(mid1.next == mid3, "mid1 should now link to mid3")
    assert(mid3.previous == mid1, "mid3 should link back to mid1")
    assert(pth:point_in_path(mid2) == false, "mid2 should no longer be in path")
end

-- Tests that path:remove_previous removes the point before target
function tests.test_path_remove_previous()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(30, 35, 40))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(10, 15, 20))
    local mid2 = point.new(vector.new(20, 25, 30))
    pth:insert(mid1)
    pth:insert(mid2)
    
    pth:remove_previous(mid2)
    
    assert(pth:count_intermediate() == 1, "Should have 1 intermediate point")
    assert(pth:get_point(1) == mid2, "Only mid2 should remain")
end

-- Tests that path:remove_next removes the point after target
function tests.test_path_remove_next()
    local p1 = point.new(vector.new(5, 10, 15))
    local p2 = point.new(vector.new(35, 40, 45))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(15, 20, 25))
    local mid2 = point.new(vector.new(25, 30, 35))
    pth:insert(mid1)
    pth:insert(mid2)
    
    pth:remove_next(mid1)
    
    assert(pth:count_intermediate() == 1, "Should have 1 intermediate point")
    assert(pth:get_point(1) == mid1, "Only mid1 should remain")
end

-- Tests that path:remove_at removes the point at a specific ordinal position
function tests.test_path_remove_at()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(12, 6, 9))
    local mid2 = point.new(vector.new(20, 10, 15))
    local mid3 = point.new(vector.new(28, 14, 21))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    pth:remove_at(2)
    
    assert(pth:count_intermediate() == 2, "Should have 2 intermediate points")
    assert(pth:get_point(1) == mid1, "First should be mid1")
    assert(pth:get_point(2) == mid3, "Second should be mid3")
end

-- Tests that path:extend adds a new finish point
function tests.test_path_extend()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(30, 40, 50))
    local pth = path.new(p1, p2)
    
    local new_finish = point.new(vector.new(60, 70, 80))
    pth:extend(new_finish)
    
    assert(pth.finish == new_finish, "Finish should be new_finish")
    assert(pth:count_intermediate() == 1, "Old finish should become intermediate")
    assert(pth:get_point(1) == p2, "p2 should now be intermediate")
    assert(p2.next == new_finish, "p2 should link to new finish")
end

-- Tests that path:shorten removes the finish and promotes last intermediate
function tests.test_path_shorten()
    local p1 = point.new(vector.new(5, 15, 25))
    local p2 = point.new(vector.new(35, 45, 55))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(20, 30, 40))
    pth:insert(mid)
    
    local result = pth:shorten()
    
    assert(result == true, "Shorten should return true on success")
    assert(pth.finish == mid, "mid should become new finish")
    assert(pth:count_intermediate() == 0, "Should have no intermediate points")
    
    -- Cannot shorten further
    result = pth:shorten()
    assert(result == false, "Shorten should return false when no intermediates")
end

-- Tests that path:shorten_by shortens by multiple points
function tests.test_path_shorten_by()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(50, 25, 40))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(10, 5, 8)))
    pth:insert(point.new(vector.new(20, 10, 16)))
    pth:insert(point.new(vector.new(30, 15, 24)))
    pth:insert(point.new(vector.new(40, 20, 32)))
    
    pth:shorten_by(2)
    
    assert(pth:count_intermediate() == 2, "Should have 2 intermediate points left")
    assert(pth.finish.pos.x == 30, "Finish should be at x=30")
    assert(pth.finish.pos.y == 15, "Finish should be at y=15")
    assert(pth.finish.pos.z == 24, "Finish should be at z=24")
end

-- Tests that path:cut_off removes all points after stop_point
function tests.test_path_cut_off()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(10, 5, 8))
    local mid2 = point.new(vector.new(20, 10, 15))
    local mid3 = point.new(vector.new(30, 15, 22))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    pth:cut_off(mid2)
    
    assert(pth.finish == mid2, "Finish should be mid2")
    assert(pth:count_intermediate() == 1, "Should have 1 intermediate point")
    assert(pth:get_point(1) == mid1, "Only mid1 should remain as intermediate")
end

-- Tests that path:all_points returns all points in order
function tests.test_path_all_points()
    local p1 = point.new(vector.new(0, 5, 10))
    local p2 = point.new(vector.new(40, 45, 50))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(15, 20, 25))
    local mid2 = point.new(vector.new(28, 33, 38))
    pth:insert(mid1)
    pth:insert(mid2)
    
    local all = pth:all_points()
    
    assert(#all == 4, "Should return 4 points")
    assert(all[1] == p1, "First should be start")
    assert(all[2] == mid1, "Second should be mid1")
    assert(all[3] == mid2, "Third should be mid2")
    assert(all[4] == p2, "Fourth should be finish")
end

-- Tests that path:all_positions returns positions of all points in order
function tests.test_path_all_positions()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    local mid = point.new(vector.new(20, 30, 40))
    pth:insert(mid)
    
    local positions = pth:all_positions()
    
    assert(#positions == 3, "Should return 3 positions")
    assert(positions[1].x == 0 and positions[1].y == 10 and positions[1].z == 20, "First position should match p1")
    assert(positions[2].x == 20 and positions[2].y == 30 and positions[2].z == 40, "Second position should match mid")
    assert(positions[3].x == 40 and positions[3].y == 50 and positions[3].z == 60, "Third position should match p2")
end

-- Tests that path:length returns the total length of the path
function tests.test_path_length()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(30, 40, 0))  -- 3-4-5 triangle scaled by 10
    local pth = path.new(p1, p2)
    
    local length = pth:length()
    assert(length == 50, "Path length should be 50 (hypotenuse of 30-40-50 triangle)")
    
    -- Add collinear intermediate point
    local mid = point.new(vector.new(15, 20, 0))
    pth:insert(mid)
    
    length = pth:length()
    assert(length == 50, "Path length should still be 50 with collinear point")
    
    -- Add non-collinear point creating detour
    local off = point.new(vector.new(15, 20, 10))
    pth:insert_before(mid, off)
    
    length = pth:length()
    assert(length > 50, "Path length should increase with detour")
end

-- Tests that path:subdivide breaks long segments into shorter ones
function tests.test_path_subdivide()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(30, 40, 0))
    local pth = path.new(p1, p2)
    
    pth:subdivide(15)
    
    assert(pth:count_intermediate() >= 2, "Should have at least 2 intermediate points")
    
    -- Verify no segment is longer than 15 units
    local points = pth:all_points()
    for i = 2, #points do
        local dist = vector.distance(points[i-1].pos, points[i].pos)
        assert(dist <= 15.01, "No segment should be longer than 15 units")
    end
end

-- Tests that path:unsubdivide removes nearly-collinear intermediate points
function tests.test_path_unsubdivide()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(40, 20, 30))
    local pth = path.new(p1, p2)
    
    -- Add collinear points (same direction vector)
    pth:insert(point.new(vector.new(10, 5, 7.5)))
    pth:insert(point.new(vector.new(20, 10, 15)))
    pth:insert(point.new(vector.new(30, 15, 22.5)))
    
    assert(pth:count_intermediate() == 3, "Should start with 3 intermediate points")
    
    -- Unsubdivide with small angle threshold (collinear = 0 angle)
    pth:unsubdivide(0.1)
    
    assert(pth:count_intermediate() == 0, "All collinear points should be removed")
end

-- Tests that path:split_at divides a path into two at an intermediate point
function tests.test_path_split_at()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(50, 25, 40))
    local pth = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(12, 6, 10))
    local mid2 = point.new(vector.new(25, 12, 20))
    local mid3 = point.new(vector.new(38, 18, 30))
    pth:insert(mid1)
    pth:insert(mid2)
    pth:insert(mid3)
    
    local new_path = pth:split_at(mid2)
    
    assert(pth.finish == mid2, "Original path finish should be mid2")
    assert(pth:count_intermediate() == 1, "Original path should have 1 intermediate")
    assert(pth:get_point(1) == mid1, "Original path intermediate should be mid1")
    
    assert(new_path.start.pos.x == 25, "New path should start at x=25")
    assert(new_path.start.pos.y == 12, "New path should start at y=12")
    assert(new_path.start.pos.z == 20, "New path should start at z=20")
    assert(new_path.finish.pos.x == 50, "New path finish should be at x=50")
end

-- Tests that path:transfer_points_to moves intermediate points between paths
function tests.test_path_transfer_points_to()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(50, 25, 40))
    local pth1 = path.new(p1, p2)
    
    local mid1 = point.new(vector.new(12, 6, 10))
    local mid2 = point.new(vector.new(25, 12, 20))
    local mid3 = point.new(vector.new(38, 18, 30))
    pth1:insert(mid1)
    pth1:insert(mid2)
    pth1:insert(mid3)
    
    local p3 = point.new(vector.new(100, 50, 80))
    local p4 = point.new(vector.new(200, 100, 160))
    local pth2 = path.new(p3, p4)
    
    pth1:transfer_points_to(pth2, mid1, mid2)
    
    assert(pth1:count_intermediate() == 1, "pth1 should have 1 intermediate left")
    assert(pth2:count_intermediate() == 2, "pth2 should have 2 intermediates")
end

-- Tests that path:clear_intermediate removes all intermediate points
function tests.test_path_clear_intermediate()
    local p1 = point.new(vector.new(0, 10, 20))
    local p2 = point.new(vector.new(40, 50, 60))
    local pth = path.new(p1, p2)
    
    pth:insert(point.new(vector.new(10, 20, 30)))
    pth:insert(point.new(vector.new(20, 30, 40)))
    pth:insert(point.new(vector.new(30, 40, 50)))
    
    pth:clear_intermediate()
    
    assert(pth:count_intermediate() == 0, "Should have no intermediate points")
    assert(pth:has_intermediate() == false, "has_intermediate() should return false")
    assert(pth.start.next == pth.finish, "Start should link directly to finish")
end

-- Tests that path:make_straight subdivides if segment_length is given
function tests.test_path_make_straight()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(30, 40, 0))
    local pth = path.new(p1, p2)
    
    pth:make_straight(15)
    
    assert(pth:count_intermediate() >= 2, "Should have intermediate points after subdivision")
end

-- Tests that path:make_wave creates a wavy path with intermediate points
function tests.test_path_make_wave()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(100, 0, 0))
    local pth = path.new(p1, p2)
    
    pth:make_wave(10, 5, 2)
    
    assert(pth:count_intermediate() == 9, "Should have 9 intermediate points (segment_nr - 1)")
    
    -- Check that some points are offset from the straight line
    -- The wave oscillates perpendicular to the path direction in the xz plane
    -- For a path along x-axis, the perpendicular is along z-axis
    local has_offset = false
    for _, p in ipairs(pth:all_points()) do
        if math.abs(p.pos.z) > 0.01 then
            has_offset = true
            break
        end
    end
    assert(has_offset, "Wave should have points offset from straight line")
end

-- Tests that path:make_slanted creates a path with a 45-degree break point
function tests.test_path_make_slanted()
    local p1 = point.new(vector.new(0, 0, 0))
    local p2 = point.new(vector.new(20, 0, 10))
    local pth = path.new(p1, p2)
    
    pth:make_slanted()
    
    assert(pth:count_intermediate() == 1, "Should have 1 intermediate point for 45-degree break")
    
    -- Verify the midpoint creates a 45-degree slant
    local mid = pth:get_point(1)
    assert(mid.pos.x == 10, "Mid x should be 10 (45-degree slant)")
    assert(mid.pos.z == 10, "Mid z should be 10 (45-degree slant)")
    
    -- Test aligned case (no intermediate needed)
    local p3 = point.new(vector.new(0, 5, 0))
    local p4 = point.new(vector.new(30, 5, 0))
    local pth2 = path.new(p3, p4)
    
    pth2:make_slanted()
    
    assert(pth2:count_intermediate() == 0, "Aligned path should have no intermediate points")
    
    -- Test z-aligned case
    local p5 = point.new(vector.new(0, 10, 0))
    local p6 = point.new(vector.new(0, 10, 40))
    local pth3 = path.new(p5, p6)
    
    pth3:make_slanted()
    
    assert(pth3:count_intermediate() == 0, "Z-aligned path should have no intermediate points")
end

-- Tests that vector.comparator provides correct ordering
function tests.test_vector_comparator()
    local v1 = vector.new(0, 0, 0)
    local v2 = vector.new(10, 0, 0)
    local v3 = vector.new(0, 10, 0)
    local v4 = vector.new(0, 0, 10)
    local v5 = vector.new(0, 0, 0)
    
    -- Compare by x first
    assert(vector.comparator(v1, v2) == true, "v1 < v2 by x")
    assert(vector.comparator(v2, v1) == false, "v2 > v1 by x")
    
    -- Compare by y when x is equal
    assert(vector.comparator(v1, v3) == true, "v1 < v3 by y")
    assert(vector.comparator(v3, v1) == false, "v3 > v1 by y")
    
    -- Compare by z when x and y are equal
    assert(vector.comparator(v1, v4) == true, "v1 < v4 by z")
    assert(vector.comparator(v4, v1) == false, "v4 > v1 by z")
    
    -- Equal vectors return false (strict weak ordering)
    assert(vector.comparator(v1, v5) == false, "Equal vectors return false")
    assert(vector.comparator(v5, v1) == false, "Equal vectors return false (symmetric)")
    
    -- Test with mixed coordinates
    local v6 = vector.new(5, 15, 25)
    local v7 = vector.new(5, 15, 30)
    local v8 = vector.new(5, 20, 10)
    
    assert(vector.comparator(v6, v7) == true, "v6 < v7 by z (same x and y)")
    assert(vector.comparator(v6, v8) == true, "v6 < v8 by y (same x)")
end

function tests.run_all()
    -- Point class tests
    tests.test_point_new()
    tests.test_point_check()
    tests.test_point_copy()
    tests.test_point_same_path()
    tests.test_point_link()
    tests.test_point_unlink_from_previous()
    tests.test_point_unlink_from_next()
    tests.test_point_unlink()
    tests.test_point_attach()
    tests.test_point_detach()
    tests.test_point_detach_all()
    tests.test_point_set_position()
    tests.test_point_equals()
    tests.test_point_comparator()
    tests.test_point_sort()
    tests.test_point_attached_sorted()
    tests.test_point_branches_sorted()
    tests.test_point_iterator()
    tests.test_point_reverse_iterator()
    tests.test_point_set_path()
    tests.test_point_branch()
    tests.test_point_has_branches()
    tests.test_point_unbranch()
    tests.test_point_unbranch_all()
    tests.test_point_clear()
    -- Path class tests
    tests.test_path_new()
    tests.test_path_check()
    tests.test_path_comparator()
    tests.test_path_sort()
    tests.test_path_branching_points_sorted()
    tests.test_path_count_intermediate()
    tests.test_path_has_intermediate()
    tests.test_path_set_start()
    tests.test_path_set_finish()
    tests.test_path_get_point()
    tests.test_path_get_points()
    tests.test_path_random_intermediate_point()
    tests.test_path_point_in_path()
    tests.test_path_insert_between()
    tests.test_path_insert_at()
    tests.test_path_insert_before()
    tests.test_path_insert_after()
    tests.test_path_insert()
    tests.test_path_remove()
    tests.test_path_remove_previous()
    tests.test_path_remove_next()
    tests.test_path_remove_at()
    tests.test_path_extend()
    tests.test_path_shorten()
    tests.test_path_shorten_by()
    tests.test_path_cut_off()
    tests.test_path_all_points()
    tests.test_path_all_positions()
    tests.test_path_length()
    tests.test_path_subdivide()
    tests.test_path_unsubdivide()
    tests.test_path_split_at()
    tests.test_path_transfer_points_to()
    tests.test_path_clear_intermediate()
    tests.test_path_make_straight()
    tests.test_path_make_wave()
    tests.test_path_make_slanted()
    tests.test_vector_comparator()
end

tests.run_all()
