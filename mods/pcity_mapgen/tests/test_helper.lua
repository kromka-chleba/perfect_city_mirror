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
-- This file initializes the test environment using Luanti's built-in modules
-- and loads the modules under test

-- Determine the base path more reliably
local info = debug.getinfo(1, "S")
local script_path = info.source:sub(2) -- Remove '@' prefix

-- Get the directory of this script
local tests_dir
if script_path:match("^/") then
    -- Absolute path
    tests_dir = script_path:match("^(.*/)") or "./"
else
    -- Relative path - make it absolute
    tests_dir = io.popen("cd " .. script_path:match("^(.*/)") .. " && pwd"):read("*l") .. "/"
end

-- Base path is one level up from tests/
local base_path = tests_dir:gsub("tests/$", "")
local luanti_path = tests_dir .. "luanti/"

-- Check if Luanti is available
local luanti_builtin = luanti_path .. "builtin/common/"
local luanti_vector = luanti_builtin .. "vector.lua"
local f = io.open(luanti_vector, "r")
if not f then
    error("Luanti not found. Please run ./install_test_deps.sh to clone Luanti repository.\n" ..
          "Expected location: " .. luanti_vector)
end
f:close()

-- Load Luanti's built-in modules
_G.vector = {}
_G.math = math  -- Luanti's math.lua needs the global math table
dofile(luanti_builtin .. "math.lua")
dofile(luanti_builtin .. "vector.lua")

-- Mock core API for pcity_mapgen modules
_G.core = {
    get_current_modname = function()
        return "pcity_mapgen"
    end,
    
    get_modpath = function(modname)
        return base_path
    end,
    
    settings = {
        get_bool = function(key)
            return true
        end
    }
}

-- Mock shallow_dump function used by point_checks.lua
_G.shallow_dump = function(value)
    if type(value) == "table" then
        local result = "{"
        local first = true
        for k, v in pairs(value) do
            if not first then result = result .. ", " end
            first = false
            result = result .. tostring(k) .. "=" .. tostring(v)
        end
        return result .. "}"
    else
        return tostring(value)
    end
end

-- Initialize pcity_mapgen namespace
_G.pcity_mapgen = {}

-- Load the modules
dofile(base_path .. "point_checks.lua")
dofile(base_path .. "path_utils.lua")
dofile(base_path .. "point.lua")
dofile(base_path .. "path.lua")

-- Export modules for tests
return {
    point = pcity_mapgen.point,
    path = pcity_mapgen.path,
    vector = vector,
}
