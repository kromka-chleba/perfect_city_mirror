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

local pcmg = pcity_mapgen
pcmg.tests = {}
pcmg.tests.path = {}
local tests = pcmg.tests.path

-- run unit tests if enabled in settings
if core.settings:get_bool("pcity_run_tests") then
    dofile(mod_path.."/tests/tests_point.lua")
    dofile(mod_path.."/tests/tests_path.lua")
end
