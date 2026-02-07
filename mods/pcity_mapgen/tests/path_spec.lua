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

-- Path class unit tests using busted framework

local helper = require("test_helper")
local point = helper.point
local path = helper.path
local vector = helper.vector

describe("Path class", function()
    describe("path.new", function()
        it("creates a path with start and finish points", function()
            local p1 = point.new(vector.new(5, 10, 15))
            local p2 = point.new(vector.new(25, 30, 35))
            local pth = path.new(p1, p2)
            
            assert.are.equal(p1, pth.start)
            assert.are.equal(p2, pth.finish)
            assert.are.equal(0, pth:count_intermediate())
            assert.is_false(pth:has_intermediate())
            assert.is_not_nil(pth.id)
            assert.are.equal(pth, p1.path)
            assert.are.equal(pth, p2.path)
            assert.are.equal(p2, p1.next)
            assert.are.equal(p1, p2.previous)
        end)
    end)
    
    describe("path.check", function()
        it("correctly identifies path objects", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(20, 25, 30))
            local pth = path.new(p1, p2)
            
            assert.is_true(path.check(pth))
            assert.is_false(path.check({}))
            assert.is_false(path.check("string"))
            assert.is_false(path.check(nil))
        end)
    end)
    
    describe("path.comparator", function()
        it("provides deterministic ordering", function()
            local pth1 = path.new(point.new(vector.new(0, 5, 10)), point.new(vector.new(30, 35, 40)))
            local pth2 = path.new(point.new(vector.new(15, 20, 25)), point.new(vector.new(45, 50, 55)))
            local pth3 = path.new(point.new(vector.new(0, 5, 10)), point.new(vector.new(60, 65, 70)))
            
            assert.is_true(path.comparator(pth1, pth2))
            assert.is_true(path.comparator(pth1, pth3))
        end)
    end)
    
    describe("path.sort", function()
        it("returns paths in deterministic order", function()
            local pth3 = path.new(point.new(vector.new(30, 35, 40)), point.new(vector.new(60, 65, 70)))
            local pth1 = path.new(point.new(vector.new(0, 5, 10)), point.new(vector.new(30, 35, 40)))
            local pth2 = path.new(point.new(vector.new(15, 20, 25)), point.new(vector.new(45, 50, 55)))
            
            local paths = {pth3, pth1, pth2}
            local sorted = path.sort(paths)
            
            assert.are.equal(pth1, sorted[1])
            assert.are.equal(pth2, sorted[2])
            assert.are.equal(pth3, sorted[3])
        end)
    end)
    
    describe("path:branching_points_sorted", function()
        it("returns branching points in path order", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(40, 20, 30))
            local pth = path.new(p1, p2)
            
            local p_mid1 = point.new(vector.new(12, 6, 9))
            local p_mid2 = point.new(vector.new(28, 14, 21))
            pth:insert(p_mid1)
            pth:insert(p_mid2)
            
            p_mid2:branch(point.new(vector.new(28, 50, 21)))
            p_mid1:branch(point.new(vector.new(12, 40, 9)))
            
            local sorted = pth:branching_points_sorted()
            
            assert.are.equal(2, #sorted)
            assert.are.equal(p_mid1, sorted[1])
            assert.are.equal(p_mid2, sorted[2])
        end)
    end)
    
    describe("path:count_intermediate", function()
        it("correctly counts intermediate points", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(40, 50, 60))
            local pth = path.new(p1, p2)
            
            assert.are.equal(0, pth:count_intermediate())
            
            pth:insert(point.new(vector.new(10, 20, 30)))
            assert.are.equal(1, pth:count_intermediate())
            
            pth:insert(point.new(vector.new(20, 30, 40)))
            assert.are.equal(2, pth:count_intermediate())
            
            pth:insert(point.new(vector.new(30, 40, 50)))
            assert.are.equal(3, pth:count_intermediate())
        end)
    end)
    
    describe("path:has_intermediate", function()
        it("correctly detects intermediate points", function()
            local p1 = point.new(vector.new(5, 15, 25))
            local p2 = point.new(vector.new(35, 45, 55))
            local pth = path.new(p1, p2)
            
            assert.is_false(pth:has_intermediate())
            
            pth:insert(point.new(vector.new(20, 30, 40)))
            assert.is_true(pth:has_intermediate())
        end)
    end)
    
    describe("path:set_start", function()
        it("replaces the start point", function()
            local p1 = point.new(vector.new(10, 20, 30))
            local p2 = point.new(vector.new(50, 60, 70))
            local pth = path.new(p1, p2)
            
            pth:insert(point.new(vector.new(30, 40, 50)))
            
            local new_start = point.new(vector.new(-10, 0, 10))
            pth:set_start(new_start)
            
            assert.are.equal(new_start, pth.start)
            assert.are.equal(pth, new_start.path)
            assert.are.equal(30, new_start.next.pos.x)
        end)
    end)
    
    describe("path:set_finish", function()
        it("replaces the finish point", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(40, 50, 60))
            local pth = path.new(p1, p2)
            
            pth:insert(point.new(vector.new(20, 30, 40)))
            
            local new_finish = point.new(vector.new(60, 70, 80))
            pth:set_finish(new_finish)
            
            assert.are.equal(new_finish, pth.finish)
            assert.are.equal(pth, new_finish.path)
            assert.are.equal(20, new_finish.previous.pos.x)
        end)
    end)
    
    describe("path:get_point", function()
        it("returns the correct intermediate point by index", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(40, 20, 30))
            local pth = path.new(p1, p2)
            
            local mid1 = point.new(vector.new(10, 5, 8))
            local mid2 = point.new(vector.new(20, 10, 15))
            local mid3 = point.new(vector.new(30, 15, 22))
            pth:insert(mid1)
            pth:insert(mid2)
            pth:insert(mid3)
            
            assert.are.equal(mid1, pth:get_point(1))
            assert.are.equal(mid2, pth:get_point(2))
            assert.are.equal(mid3, pth:get_point(3))
            assert.is_nil(pth:get_point(0))
            assert.is_nil(pth:get_point(4))
        end)
    end)
    
    describe("path:get_points", function()
        it("returns intermediate points in a range", function()
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
            
            assert.are.equal(3, #points)
            assert.are.equal(mid1, points[1])
            assert.are.equal(mid2, points[2])
            assert.are.equal(mid3, points[3])
            
            points = pth:get_points(p1, mid2)
            assert.are.equal(2, #points)
            assert.are.equal(mid1, points[1])
            assert.are.equal(mid2, points[2])
        end)
    end)
    
    describe("path:random_intermediate_point", function()
        it("returns a valid intermediate point", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(30, 35, 40))
            local pth = path.new(p1, p2)
            
            assert.is_nil(pth:random_intermediate_point())
            
            local mid1 = point.new(vector.new(10, 15, 20))
            local mid2 = point.new(vector.new(20, 25, 30))
            pth:insert(mid1)
            pth:insert(mid2)
            
            local random_point = pth:random_intermediate_point()
            assert.is_true(random_point == mid1 or random_point == mid2)
            assert.is_true(random_point ~= p1 and random_point ~= p2)
        end)
    end)
    
    describe("path:point_in_path", function()
        it("correctly checks if point belongs to path", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(40, 50, 60))
            local pth = path.new(p1, p2)
            
            local mid = point.new(vector.new(20, 30, 40))
            pth:insert(mid)
            
            local outside = point.new(vector.new(100, 200, 300))
            
            assert.is_true(pth:point_in_path(p1))
            assert.is_true(pth:point_in_path(p2))
            assert.is_true(pth:point_in_path(mid))
            assert.is_false(pth:point_in_path(outside))
        end)
    end)
    
    describe("path:insert_between", function()
        it("inserts a point between two adjacent points", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(30, 35, 40))
            local pth = path.new(p1, p2)
            
            local mid = point.new(vector.new(15, 20, 25))
            pth:insert_between(p1, p2, mid)
            
            assert.are.equal(1, pth:count_intermediate())
            assert.are.equal(mid, p1.next)
            assert.are.equal(p1, mid.previous)
            assert.are.equal(p2, mid.next)
            assert.are.equal(mid, p2.previous)
        end)
    end)
    
    describe("path:insert_at", function()
        it("inserts a point at a specific ordinal position", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(40, 20, 30))
            local pth = path.new(p1, p2)
            
            pth:insert(point.new(vector.new(12, 6, 9)))
            pth:insert(point.new(vector.new(28, 14, 21)))
            
            local mid = point.new(vector.new(20, 10, 15))
            pth:insert_at(2, mid)
            
            assert.are.equal(3, pth:count_intermediate())
            assert.are.equal(mid, pth:get_point(2))
        end)
    end)
    
    describe("path:insert_before", function()
        it("inserts a point before target", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(40, 45, 50))
            local pth = path.new(p1, p2)
            
            local mid1 = point.new(vector.new(25, 30, 35))
            pth:insert(mid1)
            
            local mid2 = point.new(vector.new(12, 17, 22))
            pth:insert_before(mid1, mid2)
            
            assert.are.equal(2, pth:count_intermediate())
            assert.are.equal(mid1, mid2.next)
            assert.are.equal(mid2, mid1.previous)
        end)
    end)
    
    describe("path:insert_after", function()
        it("inserts a point after target", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(40, 50, 60))
            local pth = path.new(p1, p2)
            
            local mid1 = point.new(vector.new(15, 25, 35))
            pth:insert(mid1)
            
            local mid2 = point.new(vector.new(28, 38, 48))
            pth:insert_after(mid1, mid2)
            
            assert.are.equal(2, pth:count_intermediate())
            assert.are.equal(mid2, mid1.next)
            assert.are.equal(mid1, mid2.previous)
        end)
    end)
    
    describe("path:insert", function()
        it("appends a point before finish", function()
            local p1 = point.new(vector.new(5, 15, 25))
            local p2 = point.new(vector.new(35, 45, 55))
            local pth = path.new(p1, p2)
            
            local mid = point.new(vector.new(20, 30, 40))
            pth:insert(mid)
            
            assert.are.equal(1, pth:count_intermediate())
            assert.are.equal(p2, mid.next)
            assert.are.equal(mid, p2.previous)
        end)
    end)
    
    describe("path:remove", function()
        it("removes an intermediate point", function()
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
            
            assert.are.equal(2, pth:count_intermediate())
            assert.are.equal(mid3, mid1.next)
            assert.are.equal(mid1, mid3.previous)
            assert.is_false(pth:point_in_path(mid2))
        end)
    end)
    
    describe("path:remove_previous", function()
        it("removes the point before target", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(30, 35, 40))
            local pth = path.new(p1, p2)
            
            local mid1 = point.new(vector.new(10, 15, 20))
            local mid2 = point.new(vector.new(20, 25, 30))
            pth:insert(mid1)
            pth:insert(mid2)
            
            pth:remove_previous(mid2)
            
            assert.are.equal(1, pth:count_intermediate())
            assert.are.equal(mid2, pth:get_point(1))
        end)
    end)
    
    describe("path:remove_next", function()
        it("removes the point after target", function()
            local p1 = point.new(vector.new(5, 10, 15))
            local p2 = point.new(vector.new(35, 40, 45))
            local pth = path.new(p1, p2)
            
            local mid1 = point.new(vector.new(15, 20, 25))
            local mid2 = point.new(vector.new(25, 30, 35))
            pth:insert(mid1)
            pth:insert(mid2)
            
            pth:remove_next(mid1)
            
            assert.are.equal(1, pth:count_intermediate())
            assert.are.equal(mid1, pth:get_point(1))
        end)
    end)
    
    describe("path:remove_at", function()
        it("removes the point at a specific ordinal position", function()
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
            
            assert.are.equal(2, pth:count_intermediate())
            assert.are.equal(mid1, pth:get_point(1))
            assert.are.equal(mid3, pth:get_point(2))
        end)
    end)
    
    describe("path:extend", function()
        it("adds a new finish point", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(30, 40, 50))
            local pth = path.new(p1, p2)
            
            local new_finish = point.new(vector.new(60, 70, 80))
            pth:extend(new_finish)
            
            assert.are.equal(new_finish, pth.finish)
            assert.are.equal(1, pth:count_intermediate())
            assert.are.equal(p2, pth:get_point(1))
            assert.are.equal(new_finish, p2.next)
        end)
    end)
    
    describe("path:shorten", function()
        it("removes the finish and promotes last intermediate", function()
            local p1 = point.new(vector.new(5, 15, 25))
            local p2 = point.new(vector.new(35, 45, 55))
            local pth = path.new(p1, p2)
            
            local mid = point.new(vector.new(20, 30, 40))
            pth:insert(mid)
            
            local result = pth:shorten()
            
            assert.is_true(result)
            assert.are.equal(mid, pth.finish)
            assert.are.equal(0, pth:count_intermediate())
            
            result = pth:shorten()
            assert.is_false(result)
        end)
    end)
    
    describe("path:shorten_by", function()
        it("shortens by multiple points", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(50, 25, 40))
            local pth = path.new(p1, p2)
            
            pth:insert(point.new(vector.new(10, 5, 8)))
            pth:insert(point.new(vector.new(20, 10, 16)))
            pth:insert(point.new(vector.new(30, 15, 24)))
            pth:insert(point.new(vector.new(40, 20, 32)))
            
            pth:shorten_by(2)
            
            assert.are.equal(2, pth:count_intermediate())
            assert.are.equal(30, pth.finish.pos.x)
            assert.are.equal(15, pth.finish.pos.y)
            assert.are.equal(24, pth.finish.pos.z)
        end)
    end)
    
    describe("path:cut_off", function()
        it("removes all points after stop_point", function()
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
            
            assert.are.equal(mid2, pth.finish)
            assert.are.equal(1, pth:count_intermediate())
            assert.are.equal(mid1, pth:get_point(1))
        end)
    end)
    
    describe("path:all_points", function()
        it("returns all points in order", function()
            local p1 = point.new(vector.new(0, 5, 10))
            local p2 = point.new(vector.new(40, 45, 50))
            local pth = path.new(p1, p2)
            
            local mid1 = point.new(vector.new(15, 20, 25))
            local mid2 = point.new(vector.new(28, 33, 38))
            pth:insert(mid1)
            pth:insert(mid2)
            
            local all = pth:all_points()
            
            assert.are.equal(4, #all)
            assert.are.equal(p1, all[1])
            assert.are.equal(mid1, all[2])
            assert.are.equal(mid2, all[3])
            assert.are.equal(p2, all[4])
        end)
    end)
    
    describe("path:all_positions", function()
        it("returns positions of all points in order", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(40, 50, 60))
            local pth = path.new(p1, p2)
            
            local mid = point.new(vector.new(20, 30, 40))
            pth:insert(mid)
            
            local positions = pth:all_positions()
            
            assert.are.equal(3, #positions)
            assert.is_true(positions[1].x == 0 and positions[1].y == 10 and positions[1].z == 20)
            assert.is_true(positions[2].x == 20 and positions[2].y == 30 and positions[2].z == 40)
            assert.is_true(positions[3].x == 40 and positions[3].y == 50 and positions[3].z == 60)
        end)
    end)
    
    describe("path:length", function()
        it("returns the total length of the path", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(30, 40, 0))
            local pth = path.new(p1, p2)
            
            local length = pth:length()
            assert.are.equal(50, length)
            
            local mid = point.new(vector.new(15, 20, 0))
            pth:insert(mid)
            
            length = pth:length()
            assert.are.equal(50, length)
            
            local off = point.new(vector.new(15, 20, 10))
            pth:insert_before(mid, off)
            
            length = pth:length()
            assert.is_true(length > 50)
        end)
    end)
    
    describe("path:subdivide", function()
        it("breaks long segments into shorter ones", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(30, 40, 0))
            local pth = path.new(p1, p2)
            
            pth:subdivide(15)
            
            assert.is_true(pth:count_intermediate() >= 2)
            
            local points = pth:all_points()
            for i = 2, #points do
                local dist = vector.distance(points[i-1].pos, points[i].pos)
                assert.is_true(dist <= 15.01)
            end
        end)
    end)
    
    describe("path:unsubdivide", function()
        it("removes nearly-collinear intermediate points", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(40, 20, 30))
            local pth = path.new(p1, p2)
            
            pth:insert(point.new(vector.new(10, 5, 7.5)))
            pth:insert(point.new(vector.new(20, 10, 15)))
            pth:insert(point.new(vector.new(30, 15, 22.5)))
            
            assert.are.equal(3, pth:count_intermediate())
            
            pth:unsubdivide(0.1)
            
            assert.are.equal(0, pth:count_intermediate())
        end)
    end)
    
    describe("path:split_at", function()
        it("divides a path into two at an intermediate point", function()
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
            
            assert.are.equal(mid2, pth.finish)
            assert.are.equal(1, pth:count_intermediate())
            assert.are.equal(mid1, pth:get_point(1))
            
            assert.are.equal(25, new_path.start.pos.x)
            assert.are.equal(12, new_path.start.pos.y)
            assert.are.equal(20, new_path.start.pos.z)
            assert.are.equal(50, new_path.finish.pos.x)
        end)
    end)
    
    describe("path:transfer_points_to", function()
        it("moves intermediate points between paths", function()
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
            
            assert.are.equal(1, pth1:count_intermediate())
            assert.are.equal(2, pth2:count_intermediate())
        end)
    end)
    
    describe("path:clear_intermediate", function()
        it("removes all intermediate points", function()
            local p1 = point.new(vector.new(0, 10, 20))
            local p2 = point.new(vector.new(40, 50, 60))
            local pth = path.new(p1, p2)
            
            pth:insert(point.new(vector.new(10, 20, 30)))
            pth:insert(point.new(vector.new(20, 30, 40)))
            pth:insert(point.new(vector.new(30, 40, 50)))
            
            pth:clear_intermediate()
            
            assert.are.equal(0, pth:count_intermediate())
            assert.is_false(pth:has_intermediate())
            assert.are.equal(pth.finish, pth.start.next)
        end)
    end)
    
    describe("path:make_straight", function()
        it("subdivides if segment_length is given", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(30, 40, 0))
            local pth = path.new(p1, p2)
            
            pth:make_straight(15)
            
            assert.is_true(pth:count_intermediate() >= 2)
        end)
    end)
    
    describe("path:make_wave", function()
        it("creates a wavy path with intermediate points", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(100, 0, 0))
            local pth = path.new(p1, p2)
            
            pth:make_wave(10, 5, 2)
            
            assert.are.equal(9, pth:count_intermediate())
            
            local has_offset = false
            for _, p in ipairs(pth:all_points()) do
                if math.abs(p.pos.z) > 0.01 then
                    has_offset = true
                    break
                end
            end
            assert.is_true(has_offset)
        end)
    end)
    
    describe("path:make_slanted", function()
        it("creates a path with a 45-degree break point", function()
            local p1 = point.new(vector.new(0, 0, 0))
            local p2 = point.new(vector.new(20, 0, 10))
            local pth = path.new(p1, p2)
            
            pth:make_slanted()
            
            assert.are.equal(1, pth:count_intermediate())
            
            local mid = pth:get_point(1)
            assert.are.equal(10, mid.pos.x)
            assert.are.equal(10, mid.pos.z)
            
            local p3 = point.new(vector.new(0, 5, 0))
            local p4 = point.new(vector.new(30, 5, 0))
            local pth2 = path.new(p3, p4)
            
            pth2:make_slanted()
            
            assert.are.equal(0, pth2:count_intermediate())
            
            local p5 = point.new(vector.new(0, 10, 0))
            local p6 = point.new(vector.new(0, 10, 40))
            local pth3 = path.new(p5, p6)
            
            pth3:make_slanted()
            
            assert.are.equal(0, pth3:count_intermediate())
        end)
    end)
    
    describe("vector.comparator", function()
        it("provides correct ordering", function()
            local v1 = vector.new(0, 0, 0)
            local v2 = vector.new(10, 0, 0)
            local v3 = vector.new(0, 10, 0)
            local v4 = vector.new(0, 0, 10)
            local v5 = vector.new(0, 0, 0)
            
            assert.is_true(vector.comparator(v1, v2))
            assert.is_false(vector.comparator(v2, v1))
            
            assert.is_true(vector.comparator(v1, v3))
            assert.is_false(vector.comparator(v3, v1))
            
            assert.is_true(vector.comparator(v1, v4))
            assert.is_false(vector.comparator(v4, v1))
            
            assert.is_false(vector.comparator(v1, v5))
            assert.is_false(vector.comparator(v5, v1))
            
            local v6 = vector.new(5, 15, 25)
            local v7 = vector.new(5, 15, 30)
            local v8 = vector.new(5, 20, 10)
            
            assert.is_true(vector.comparator(v6, v7))
            assert.is_true(vector.comparator(v6, v8))
        end)
    end)
end)
