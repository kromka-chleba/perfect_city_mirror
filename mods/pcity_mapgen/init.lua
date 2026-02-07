--[[
    This is a part of "Perfect City".
    Copyright (C) 2023-2024 Jan Wielkiewicz <tona_kosmicznego_smiecia@interia.pl>
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

-- This mod name and path
local mod_name = minetest.get_current_modname()
local mod_path = minetest.get_modpath(mod_name)

-- Create global table for mapgen
pcity_mapgen = {}

-- Cirno's Perfect Math Library
local CPML_mod_path = minetest.get_modpath("pcity_cpml")

-- These are necessary so the mapgen works at all lol
minetest.register_alias("mapgen_stone", "pcity_nodes:asphalt")
minetest.register_alias("mapgen_water_source", "pcity_nodes:pavement")
minetest.register_alias("mapgen_river_water_source", "pcity_nodes:pavement")

minetest.set_mapgen_setting("mg_flags", "nocaves, nodungeons, light, decorations, biomes", true)

if minetest.settings:get("pcity_enable_hills") == "true" then
    minetest.set_mapgen_setting("mgflat_spflags", "nolakes, hills, nocaverns", true)
end

dofile(mod_path.."/biomes.lua")
dofile(mod_path.."/tests/init.lua")
minetest.register_mapgen_script(CPML_mod_path.."/init.lua")
minetest.register_mapgen_script(mod_path.."/mapgen.lua")
