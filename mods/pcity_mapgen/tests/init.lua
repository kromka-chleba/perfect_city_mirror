--[[
    Test infrastructure for "Perfect City" pcity_mapgen mod.
    
    Based on WorldEdit's test system:
    https://github.com/Uberi/Minetest-WorldEdit
    
    Copyright © 2012 sfan5, Anthony Zhang (Uberi/Temperest), and Brett O'Donnell (cornernote)
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
    
    ---
    
    The concept of running tests inside the Luanti engine, the test registration
    pattern, and the overall test runner structure are adapted from WorldEdit's
    approach, specifically from worldedit/test/init.lua. This implementation has
    been significantly modified and extended for Perfect City's needs.
--]]

-- Test runner for pcity_mapgen
-- Runs tests inside the Luanti engine when pcity_run_tests setting is enabled

local mod_name = core.get_current_modname()
local mod_path = core.get_modpath("pcity_mapgen")

-- Only run tests if enabled in settings
if not core.settings:get_bool("pcity_run_tests") then
    return
end

local pcmg = pcity_mapgen

-- Initialize test registry
pcmg.tests = pcmg.tests or {}
pcmg.tests.registered = {}

-- Register a test
pcmg.register_test = function(name, func)
    assert(type(name) == "string", "Test name must be a string")
    assert(func == nil or type(func) == "function", "Test func must be nil or a function")
    
    table.insert(pcmg.tests.registered, {
        name = name,
        func = func
    })
end

-- Load test files
dofile(mod_path.."/tests/tests_point.lua")
dofile(mod_path.."/tests/tests_path.lua")

-- Run all tests
pcmg.run_tests = function()
    local v = core.get_version()
    print("Running " .. #pcmg.tests.registered .. " tests for pcity_mapgen on " .. 
          v.project .. " " .. (v.hash or v.string))
    
    local failed = 0
    local passed = 0
    
    for _, test in ipairs(pcmg.tests.registered) do
        if not test.func then
            -- This is a section header
            local s = "---- " .. test.name .. " "
            print(s .. string.rep("-", 60 - #s))
        else
            -- Run the actual test
            local ok, err = pcall(test.func)
            local status = ok and "pass" or "FAIL"
            print(string.format("%-60s %s", test.name, status))
            
            if not ok then
                print("   " .. tostring(err))
                failed = failed + 1
            else
                passed = passed + 1
            end
        end
    end
    
    print(string.format("\nResults: %d passed, %d failed, %d total",
          passed, failed, passed + failed))
    
    -- Write success marker file
    if failed == 0 then
        local worldpath = core.get_worldpath()
        local file = io.open(worldpath .. "/tests_ok", "w")
        if file then
            file:write("All tests passed\n")
            file:close()
        end
    end
    
    -- Shutdown the server after tests complete
    core.request_shutdown("Tests completed", false, 0)
end

-- Run tests after server starts
core.after(0.1, function()
    pcmg.run_tests()
end)
