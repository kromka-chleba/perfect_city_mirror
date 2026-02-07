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

-- Point class unit tests using busted framework

local helper = require("test_helper")
local point = helper.point
local path = helper.path
local vector = helper.vector

describe("Point class", function()
    describe("point.new", function()
        it("creates a point with correct position and unique ID", function()
            local pos = vector.new(5, 10, 15)
            local p = point.new(pos)
            
            assert.are.equal(5, p.pos.x)
            assert.are.equal(10, p.pos.y)
            assert.are.equal(15, p.pos.z)
            assert.is_not_nil(p.id)
            assert.is_nil(p.path)
            assert.is_nil(p.previous)
            assert.is_nil(p.next)
            
            -- Test that IDs are unique
            local p2 = point.new(vector.new(20, 25, 30))
            assert.are_not.equal(p.id, p2.id)
        end)
    end)
    
    describe("point.check", function()
        it("correctly identifies point objects", function()
            local p = point.new(vector.new(7, 14, 21))
            
            assert.is_true(point.check(p))
            assert.is_false(point.check({}))
            assert.is_false(point.check("string"))
            assert.is_false(point.check(nil))
        end)
    end)
    
    describe("point:copy", function()
        it("creates a new point with same position but no links", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(30, 40, 50))
            local pth = path.new(p1, p2)
            
            local p_mid = point.new(vector.new(15, 25, 35))
            pth:insert(p_mid)
            
            local p_copy = p_mid:copy()
            
            assert.is_true(vector.equals(p_copy.pos, p_mid.pos))
            assert.are_not.equal(p_copy.id, p_mid.id)
            assert.is_nil(p_copy.path)
            assert.is_nil(p_copy.previous)
            assert.is_nil(p_copy.next)
        end)
    end)
    
    describe("point.same_path", function()
        it("correctly identifies points on the same path", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(30, 35, 40))
            local pth = path.new(p1, p2)
            
            local p3 = point.new(vector.new(15, 20, 25))
            pth:insert(p3)
            
            assert.is_true(point.same_path(p1, p2, p3))
            
            -- Create another path
            local p4 = point.new(vector.new(100, 110, 120))
            local p5 = point.new(vector.new(200, 210, 220))
            local pth2 = path.new(p4, p5)
            
            assert.is_false(point.same_path(p1, p4))
        end)
    end)
    
    describe("point.link", function()
        it("correctly links multiple points in order", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(10, 15, 20))
            local p3 = point.new(vector.new(25, 30, 35))
            local pth = path.new(p1, p3)
            p2:set_path(pth)
            
            point.link(p1, p2, p3)
            
            assert.are.equal(p2, p1.next)
            assert.are.equal(p1, p2.previous)
            assert.are.equal(p3, p2.next)
            assert.are.equal(p2, p3.previous)
        end)
    end)
    
    describe("point:unlink_from_previous", function()
        it("correctly severs the previous link", function()
            local p1 = point.new(vector.new(5, 10, 15))
            local p2 = point.new(vector.new(35, 40, 45))
            local pth = path.new(p1, p2)
            
            local p_mid = point.new(vector.new(20, 25, 30))
            pth:insert(p_mid)
            
            p_mid:unlink_from_previous()
            
            assert.is_nil(p_mid.previous)
            assert.is_nil(p1.next)
        end)
    end)
    
    describe("point:unlink_from_next", function()
        it("correctly severs the next link", function()
            local p1 = point.new(vector.new(0, 8, 16))
            local p2 = point.new(vector.new(32, 40, 48))
            local pth = path.new(p1, p2)
            
            local p_mid = point.new(vector.new(16, 24, 32))
            pth:insert(p_mid)
            
            p_mid:unlink_from_next()
            
            assert.is_nil(p_mid.next)
            assert.is_nil(p2.previous)
        end)
    end)
    
    describe("point:unlink", function()
        it("correctly severs both previous and next links", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(30, 35, 40))
            local pth = path.new(p1, p2)
            
            local p_mid = point.new(vector.new(15, 20, 25))
            pth:insert(p_mid)
            
            p_mid:unlink()
            
            assert.is_nil(p_mid.previous)
            assert.is_nil(p_mid.next)
            assert.is_nil(p1.next)
            assert.is_nil(p2.previous)
        end)
    end)
    
    describe("point:attach", function()
        it("shares position between attached points", function()
            local p1 = point.new(vector.new(10, 20, 30))
            local p2 = point.new(vector.new(5, 15, 25))
            local p3 = point.new(vector.new(40, 50, 60))
            
            p1:attach(p2, p3)
            
            -- Attached points should share the same position reference
            assert.are.equal(p1.pos, p2.pos)
            assert.are.equal(p1.pos, p3.pos)
            assert.are.equal(p2, p1.attached[p2])
            assert.are.equal(p3, p1.attached[p3])
            assert.are.equal(p1, p2.attached[p1])
        end)
    end)
    
    describe("point:detach", function()
        it("removes attachment relationship", function()
            local p1 = point.new(vector.new(15, 25, 35))
            local p2 = point.new(vector.new(5, 10, 15))
            local p3 = point.new(vector.new(45, 55, 65))
            
            p1:attach(p2, p3)
            p1:detach(p2)
            
            assert.is_nil(p1.attached[p2])
            assert.is_nil(p2.attached[p1])
            assert.are.equal(p3, p1.attached[p3])
        end)
    end)
    
    describe("point:detach_all", function()
        it("removes all attachments", function()
            local p1 = point.new(vector.new(20, 30, 40))
            local p2 = point.new(vector.new(5, 10, 15))
            local p3 = point.new(vector.new(50, 60, 70))
            
            p1:attach(p2, p3)
            p1:detach_all()
            
            assert.is_nil(next(p1.attached))
            assert.is_nil(p2.attached[p1])
            assert.is_nil(p3.attached[p1])
        end)
    end)
    
    describe("point:set_position", function()
        it("updates position for all attached points", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(50, 60, 70))
            
            p1:attach(p2)
            p1:set_position(vector.new(100, 200, 300))
            
            assert.are.equal(100, p1.pos.x)
            assert.are.equal(200, p1.pos.y)
            assert.are.equal(300, p1.pos.z)
            assert.are.equal(p1.pos, p2.pos)
        end)
    end)
    
    describe("point.equals", function()
        it("correctly compares points by position and ID", function()
            local p1 = point.new(vector.new(10, 20, 30))
            local p2 = point.new(vector.new(10, 20, 30))
            local p3 = point.new(vector.new(15, 25, 35))
            
            -- Same point should equal itself
            assert.is_true(point.equals(p1, p1))
            
            -- Different points with same position should not be equal (different IDs)
            assert.is_false(point.equals(p1, p2))
            
            -- Different positions should not be equal
            assert.is_false(point.equals(p1, p3))
        end)
    end)
    
    describe("point.comparator", function()
        it("provides deterministic ordering", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(5, 0, 0))
            local p3 = point.new(vector.new(0, 5, 0))
            local p4 = point.new(vector.new(0, 0, 5))
            
            -- Compare by x first
            assert.is_true(point.comparator(p1, p2))
            
            -- Compare by y when x is equal
            assert.is_true(point.comparator(p1, p3))
            
            -- Compare by z when x and y are equal
            assert.is_true(point.comparator(p1, p4))
            
            -- Same position, compare by ID
            local p5 = point.new(vector.new(0, 0, 0))
            assert.is_true(point.comparator(p1, p5))
        end)
    end)
    
    describe("point.sort", function()
        it("returns points in deterministic order", function()
            local p3 = point.new(vector.new(30, 15, 10))
            local p1 = point.new(vector.new(5, 25, 20))
            local p2 = point.new(vector.new(20, 10, 30))
            
            local points = {p3, p1, p2}
            local sorted = point.sort(points)
            
            assert.are.equal(p1, sorted[1])
            assert.are.equal(p2, sorted[2])
            assert.are.equal(p3, sorted[3])
        end)
    end)
    
    describe("point:attached_sorted", function()
        it("returns attached points in order", function()
            local p1 = point.new(vector.new(25, 25, 25))
            local p2 = point.new(vector.new(10, 15, 20))
            local p3 = point.new(vector.new(40, 45, 50))
            
            p1:attach(p3, p2)  -- attach in reverse order
            
            local sorted = p1:attached_sorted()
            
            -- Should be sorted by position/ID
            assert.are.equal(2, #sorted)
        end)
    end)
    
    describe("point:branches_sorted", function()
        it("returns branches in deterministic order", function()
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
            
            assert.are.equal(2, #sorted)
        end)
    end)
    
    describe("point:iterator", function()
        it("traverses forward through linked points", function()
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
            
            assert.are.equal(4, count)
            assert.are.equal(10, x_positions[1])
            assert.are.equal(20, x_positions[2])
            assert.are.equal(30, x_positions[3])
            assert.are.equal(40, x_positions[4])
        end)
    end)
    
    describe("point:reverse_iterator", function()
        it("traverses backward through linked points", function()
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
            
            assert.are.equal(4, count)
            assert.are.equal(30, x_positions[1])
            assert.are.equal(20, x_positions[2])
            assert.are.equal(10, x_positions[3])
            assert.are.equal(0, x_positions[4])
        end)
    end)
    
    describe("point:set_path", function()
        it("correctly assigns point to path", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(30, 35, 40))
            local pth = path.new(p1, p2)
            
            local p3 = point.new(vector.new(15, 20, 25))
            p3:set_path(pth)
            
            assert.are.equal(pth, p3.path)
            assert.are.equal(p3, pth.points[p3])
        end)
    end)
    
    describe("point:branch", function()
        it("creates a new path branching from this point", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(30, 40, 50))
            local pth = path.new(p1, p2)
            
            local p_mid = point.new(vector.new(15, 25, 35))
            pth:insert(p_mid)
            
            local branch_end = point.new(vector.new(15, 60, 35))
            local branch = p_mid:branch(branch_end)
            
            assert.is_true(path.check(branch))
            assert.are.equal(branch_end, branch.finish)
            assert.are.equal(branch, p_mid.branches[branch])
            assert.are.equal(p_mid, pth.branching_points[p_mid])
            assert.are.equal(branch.start, p_mid.attached[branch.start])
        end)
    end)
    
    describe("point:has_branches", function()
        it("correctly detects branches", function()
            local p1 = point.new(vector.new(5, 15, 25))
            local p2 = point.new(vector.new(35, 45, 55))
            local pth = path.new(p1, p2)
            
            local p_mid = point.new(vector.new(20, 30, 40))
            pth:insert(p_mid)
            
            assert.is_false(p_mid:has_branches())
            
            local branch_end = point.new(vector.new(20, 60, 40))
            p_mid:branch(branch_end)
            
            assert.is_true(p_mid:has_branches())
        end)
    end)
    
    describe("point:unbranch", function()
        it("removes a specific branch", function()
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
            
            assert.is_nil(p_mid.branches[branch1])
            assert.are.equal(branch2, p_mid.branches[branch2])
            assert.are.equal(p_mid, pth.branching_points[p_mid])
            
            p_mid:unbranch(branch2)
            assert.is_nil(pth.branching_points[p_mid])
        end)
    end)
    
    describe("point:unbranch_all", function()
        it("removes all branches", function()
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
            
            assert.is_nil(next(p_mid.branches))
            assert.is_nil(pth.branching_points[p_mid])
        end)
    end)
    
    describe("point:clear", function()
        it("removes all links, attachments, and branches", function()
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
            
            assert.is_nil(p_mid.previous)
            assert.is_nil(p_mid.next)
            assert.is_nil(next(p_mid.attached))
            assert.is_nil(next(p_mid.branches))
            assert.is_nil(p_mid.path)
        end)
    end)
end)
