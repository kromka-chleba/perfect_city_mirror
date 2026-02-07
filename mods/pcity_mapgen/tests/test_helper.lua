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

-- Test helper to set up the testing environment
-- This file initializes mocks and loads the modules under test

-- Determine the base path
local info = debug.getinfo(1, "S")
local script_path = info.source:sub(2) -- Remove '@' prefix
local tests_dir = script_path:match("(.*/)")
local base_path = tests_dir:gsub("/tests/$", "")

-- Load mocks
local mocks = dofile(tests_dir .. "mocks/minetest_mocks.lua")

-- Set up global environment
_G.core = mocks.core
_G.vector = mocks.vector
_G.pcity_mapgen = {}

-- Load the modules
dofile(base_path .. "/point_checks.lua")
dofile(base_path .. "/path_utils.lua")
dofile(base_path .. "/point.lua")
dofile(base_path .. "/path.lua")

-- Export modules for tests
return {
    point = pcity_mapgen.point,
    path = pcity_mapgen.path,
    vector = vector,
}
